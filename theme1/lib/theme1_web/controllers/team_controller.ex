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

  # Administrators create the teams that managers later use for scoping.
  def create(conn, %{"name" => name}) do
    changeset = Ecto.Changeset.cast(%Team{}, %{name: name}, [:name])

    case Repo.insert(changeset) do
      {:ok, team} -> conn |> put_status(:created) |> json(team_json(team))
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)})
    end
  end

  def create(conn, _params), do: conn |> put_status(:unprocessable_entity) |> json(%{error: "Team name is required"})

  # Administrators assign a user to a team through the join table.
  def add_member(conn, %{"teamID" => team_id, "userID" => user_id}) do
      with {team_id, ""} <- Integer.parse(team_id),
        {user_id, ""} <- Integer.parse(user_id),
        %Team{} <- Repo.get(Team, team_id),
        %User{} <- Repo.get(User, user_id),
        {:ok, _membership} <- Repo.insert(%TeamMembership{team_id: team_id, user_id: user_id}) do
      json(conn, %{ok: true})
    else
      nil -> conn |> put_status(:not_found) |> json(%{error: "Team or user not found"})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)})
      _ -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Valid team and user IDs are required"})
    end
  end

  # Administrators remove a user from a team without deleting either record.
  def remove_member(conn, %{"teamID" => team_id, "userID" => user_id}) do
    with {team_id, ""} <- Integer.parse(team_id),
         {user_id, ""} <- Integer.parse(user_id) do
      {deleted_count, _} = Repo.delete_all(from membership in TeamMembership,
        where: membership.team_id == ^team_id and membership.user_id == ^user_id)

      if deleted_count == 0 do
        conn |> put_status(:not_found) |> json(%{error: "Membership not found"})
      else
        json(conn, %{ok: true})
      end
    else
      _ -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Valid team and user IDs are required"})
    end
  end

  defp team_json(team) do
    # Newly created teams do not have a preloaded users association yet.
    users = if Ecto.assoc_loaded?(team.users), do: Enum.map(team.users, &Theme1.Auth.public_user/1), else: []
    %{id: team.id, name: team.name, users: users}
  end
end
