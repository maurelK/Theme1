defmodule Theme1Web.AdminController do
  use Theme1Web, :controller

  alias Theme1.{Repo, Role, User}

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
end
