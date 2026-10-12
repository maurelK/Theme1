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
          Repo.all(Team) |> Repo.preload(users: :role)

        _ ->
          # Only teams the user is a member of.
          Repo.all(
            from t in Team,
              join: m in TeamMembership,
              on: m.team_id == t.id,
              where: m.user_id == ^current_user.id,
              order_by: [asc: t.name],
              distinct: t.id
          )
          |> Repo.preload(users: :role)
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
end
