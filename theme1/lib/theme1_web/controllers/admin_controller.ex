defmodule Theme1Web.AdminController do
  use Theme1Web, :controller

  alias Theme1.{Repo, Role, Team, User}

  # ---------------------------------------------------------------- Roles

  # Administrators alone can promote or demote accounts between predefined roles.
  def update_role(conn, %{"userID" => user_id, "role" => role_name}) do
    with %User{} = user <- Repo.get(User, user_id),
         %Role{} = role <- Repo.get_by(Role, name: role_name),
         {:ok, updated_user} <- user |> Ecto.Changeset.change(role_id: role.id) |> Repo.update() do
      updated_user = Repo.preload(updated_user, :role)
      json(conn, %{user: Theme1.Auth.public_user(updated_user)})
    else
      nil -> conn |> put_status(:not_found) |> json(%{error: "User or role not found"})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)})
    end
  end

  def update_role(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "A predefined role is required"})
  end

  # ---------------------------------------------------------------- User shifts

  # Read the user's stored shift config (not the resolved effective shift).
  def show_user_shift(conn, %{"userID" => user_id}) do
    case Repo.get(User, user_id) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "User not found"})
      %User{} = user -> json(conn, %{data: user_shift_json(user)})
    end
  end

  # Set (or clear) a user's personal shift. Send all three fields to set.
  # Send `null` for shift_start/shift_end to fall back to the team/default.
  def update_user_shift(conn, %{"userID" => user_id} = params) do
    case Repo.get(User, user_id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "User not found"})

      %User{} = user ->
        attrs = shift_attrs(params)

        case user |> User.shift_changeset(attrs) |> Repo.update() do
          {:ok, updated} ->
            json(conn, %{data: user_shift_json(updated)})

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {m, _} -> m end)})
        end
    end
  end

  # ---------------------------------------------------------------- Team shifts

  def show_team_shift(conn, %{"teamID" => team_id}) do
    case Repo.get(Team, team_id) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "Team not found"})
      %Team{} = team -> json(conn, %{data: team_shift_json(team)})
    end
  end

  def update_team_shift(conn, %{"teamID" => team_id} = params) do
    case Repo.get(Team, team_id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Team not found"})

      %Team{} = team ->
        attrs = shift_attrs(params)

        case team |> Team.shift_changeset(attrs) |> Repo.update() do
          {:ok, updated} ->
            json(conn, %{data: team_shift_json(updated)})

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {m, _} -> m end)})
        end
    end
  end

  # ---------------------------------------------------------------- Helpers

  # Accept exactly the three shift fields. Any missing key is treated as nil,
  # which means "clear this field" for the *minutes fields. The offset defaults
  # to 0 if not provided.
  defp shift_attrs(params) do
    %{
      "shift_start_minutes" => coerce_int(params["shift_start_minutes"]),
      "shift_end_minutes" => coerce_int(params["shift_end_minutes"]),
      "timezone_offset_minutes" => coerce_int(params["timezone_offset_minutes"]) || 0
    }
  end

  defp coerce_int(nil), do: nil
  defp coerce_int(""), do: nil
  defp coerce_int(v) when is_integer(v), do: v

  defp coerce_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp coerce_int(_), do: nil

  defp user_shift_json(user) do
    %{
      user_id: user.id,
      shift_start_minutes: user.shift_start_minutes,
      shift_end_minutes: user.shift_end_minutes,
      timezone_offset_minutes: user.timezone_offset_minutes
    }
  end

  defp team_shift_json(team) do
    %{
      team_id: team.id,
      shift_start_minutes: team.shift_start_minutes,
      shift_end_minutes: team.shift_end_minutes,
      timezone_offset_minutes: team.timezone_offset_minutes
    }
  end
end