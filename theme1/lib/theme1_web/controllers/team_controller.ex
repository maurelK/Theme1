defmodule Theme1Web.TeamController do
  use Theme1Web, :controller

  # Query helpers keep membership removal scoped to the requested team and user.
  import Ecto.Query

  alias Theme1.{Repo, Team, TeamMembership, User}

  # Return team membership data without exposing password material.
  #
  # Scoping:
  #   * administrator / hr_payroll  -> all teams
  #   * manager / employee          -> only teams they belong to
  def index(conn, _params) do
    current_user = conn.assigns.current_user
    role = current_user.role && current_user.role.name

    teams =
      case role do
        r when r in ["administrator", "hr_payroll"] ->
          Repo.all(Team)
          |> Repo.preload(users: active_users_query())

        _ ->
          Repo.all(
            from t in Team,
              join: m in TeamMembership,
              on: m.team_id == t.id,
              where: m.user_id == ^current_user.id,
              order_by: [asc: t.name],
              distinct: t.id
          )
          |> Repo.preload(users: active_users_query())
      end

    json(conn, Enum.map(teams, &team_json/1))
  end

  # Managers and administrators can create teams.
  # A manager who creates a team is automatically added as a member so they
  # can immediately manage it. An administrator who creates a team is NOT
  # auto-added — the team is expected to be handed off to a manager.
  def create(conn, %{"name" => name}) do
    role = role_name(conn)
    current_user = conn.assigns.current_user

    cond do
      role not in ["manager", "administrator"] ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Only managers and administrators can create teams"})

      true ->
        create_team(conn, name, role, current_user)
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "Team name is required"})
  end

  defp create_team(conn, name, role, current_user) do
    changeset = Ecto.Changeset.cast(%Team{}, %{name: name}, [:name])

    case Repo.insert(changeset) do
      {:ok, team} ->
        # Auto-join manager creators; admins are not auto-added.
        team =
          if role == "manager" do
            %TeamMembership{}
            |> Ecto.Changeset.change(%{team_id: team.id, user_id: current_user.id})
            |> Repo.insert!()
            team
          else
            team
          end

        # Reload with users so the response shape matches index/2.
        team = Repo.preload(team, users: :role)
        conn |> put_status(:created) |> json(team_json(team))

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)})
    end
  end

  # Administrators assign a user to a team through the join table.
  def add_member(conn, %{"teamID" => team_id, "userID" => user_id}) do
    with {team_id, ""} <- Integer.parse(team_id),
         {user_id, ""} <- Integer.parse(user_id),
         %Team{} = team <- Repo.get(Team, team_id),
         %User{} = _user <- Repo.get(User, user_id),
         :ok <- authorize_team_manage(conn, team),
         {:ok, _membership} <- Repo.insert(%TeamMembership{team_id: team_id, user_id: user_id}) do
      json(conn, %{ok: true})
    else
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Team or user not found"})

      {:error, :forbidden} ->
        conn |> put_status(:forbidden) |> json(%{error: "Insufficient permissions"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)})

      _ ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Valid team and user IDs are required"})
    end
  end

  # Managers and administrators can remove a user from a team.
  def remove_member(conn, %{"teamID" => team_id, "userID" => user_id}) do
    with {team_id, ""} <- Integer.parse(team_id),
         {user_id, ""} <- Integer.parse(user_id),
         %Team{} = team <- Repo.get(Team, team_id),
         :ok <- authorize_team_manage(conn, team) do
      {deleted_count, _} =
        Repo.delete_all(
          from membership in TeamMembership,
            where: membership.team_id == ^team_id and membership.user_id == ^user_id
        )

      if deleted_count == 0 do
        conn |> put_status(:not_found) |> json(%{error: "Membership not found"})
      else
        json(conn, %{ok: true})
      end
    else
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Team not found"})

      {:error, :forbidden} ->
        conn |> put_status(:forbidden) |> json(%{error: "Insufficient permissions"})

      _ ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Valid team and user IDs are required"})
    end
  end

  # Working times of every active member of a team, for team averages.
  # Optional ?start=YYYY-MM-DD&end=YYYY-MM-DD bounds the entry start date (inclusive).
  # Aggregation is left to the client so days and weeks follow the viewer's timezone.
  def working_times(conn, %{"teamID" => team_id} = params) do
    with {id, ""} <- Integer.parse(to_string(team_id)),
         %Team{} = team <- Repo.get(Team, id),
         :ok <- authorize_team_read(conn, team),
         {:ok, range} <- parse_range(params) do
      team = Repo.preload(team, users: active_users_query())
      member_ids = Enum.map(team.users, & &1.id)

      entries =
        from(w in Theme1.WorkingTime, where: w.user_id in ^member_ids, order_by: [asc: w.start])
        |> filter_range(range)
        |> Repo.all()
        |> Enum.group_by(& &1.user_id)

      members =
        Enum.map(team.users, fn user ->
          %{id: user.id, username: user.username, working_times: Map.get(entries, user.id, [])}
        end)

      json(conn, %{data: %{team: %{id: team.id, name: team.name}, members: members}})
    else
      nil -> conn |> put_status(:not_found) |> json(%{error: "Team not found"})
      {:error, :forbidden} -> conn |> put_status(:forbidden) |> json(%{error: "You cannot view this team"})
      {:error, :invalid_date} -> conn |> put_status(:bad_request) |> json(%{error: "Dates must be YYYY-MM-DD"})
      _ -> conn |> put_status(:bad_request) |> json(%{error: "Invalid team ID"})
    end
  end

  # HR can read every team; managing rights imply reading rights.
  defp authorize_team_read(conn, team) do
    if role_name(conn) == "hr_payroll", do: :ok, else: authorize_team_manage(conn, team)
  end

  defp parse_range(params) do
    with {:ok, from_date} <- parse_date(params["start"]),
         {:ok, to_date} <- parse_date(params["end"]) do
      {:ok, {from_date, to_date}}
    end
  end

  defp parse_date(value) when value in [nil, ""], do: {:ok, nil}

  defp parse_date(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      _ -> {:error, :invalid_date}
    end
  end

  # Widen by a day on each side: the client re-filters on its own local dates.
  defp filter_range(query, {from_date, to_date}) do
    query =
      if from_date,
        do: where(query, [w], w.start >= ^DateTime.new!(Date.add(from_date, -1), ~T[00:00:00], "Etc/UTC")),
        else: query

    if to_date,
      do: where(query, [w], w.start < ^DateTime.new!(Date.add(to_date, 2), ~T[00:00:00], "Etc/UTC")),
      else: query
  end

  defp team_json(team) do
    # Newly created teams do not have a preloaded users association yet.
    users = if Ecto.assoc_loaded?(team.users), do: Enum.map(team.users, &Theme1.Auth.public_user/1), else: []
    %{id: team.id, name: team.name, users: users}
  end

  defp role_name(conn) do
    conn.assigns.current_user.role && conn.assigns.current_user.role.name
  end

  # Administrators manage any team. Managers manage only teams they belong to.
  # Everyone else is forbidden.
  defp authorize_team_manage(conn, team) do
    case role_name(conn) do
      "administrator" ->
        :ok

      "manager" ->
        user_id = conn.assigns.current_user.id

        if Repo.exists?(
             from m in TeamMembership,
               where: m.team_id == ^team.id and m.user_id == ^user_id
           ) do
          :ok
        else
          {:error, :forbidden}
        end

      _ ->
        {:error, :forbidden}
    end
  end

  # Only return non-deleted team members in preloads.
  defp active_users_query do
    from u in User, where: is_nil(u.deleted_at), preload: [:role]
  end

end
