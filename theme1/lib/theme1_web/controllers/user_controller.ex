defmodule Theme1Web.UserController do
  use Theme1Web, :controller

  import Ecto.Query

  alias Theme1.Repo
  alias Theme1.User

  def index(conn, params) do
    users =
      User
      |> apply_filters(params)
      |> Repo.all()
      |> Enum.filter(&can_access_user?(conn, &1))

    json(conn, Enum.map(users, &user_json/1))
  end

  def create(conn, params) do
    if not administrator?(conn) do
      conn
      |> put_status(:forbidden)
      |> json(%{error: "Only administrators can create users here"})
    else
      create_user(conn, params)
    end
  end

  defp create_user(conn, params) do
    case Theme1.Auth.invite_user(params) do
      {:ok, user} ->
        conn
        |> put_status(:created)
        |> json(user_json(user))

      {:error, :role_missing} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Role does not exist"})

      {:error, :role_not_invitable} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "This role cannot be assigned at invite time"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: errors_from_changeset(changeset)})
    end
  end

  def show(conn, %{"userID" => user_id}) do
    case Repo.get(User, user_id) do
        nil ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "User not found"})

        user ->
            if can_access_user?(conn, user) do
              json(conn, user_json(user))
            else
              conn
              |> put_status(:forbidden)
              |> json(%{error: "You cannot access this user"})
            end
    end
  end

  def update(conn, %{"userID" => user_id} = params) do
    case Repo.get(User, user_id) do
        nil ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "User not found"})

        user ->
            if can_access_user?(conn, user) do
              changeset = User.changeset(user, params)

              case Repo.update(changeset) do
                {:ok, updated_user} -> json(conn, user_json(updated_user))
                {:error, changeset} ->
                  conn
                  |> put_status(:unprocessable_entity)
                  |> json(%{errors: errors_from_changeset(changeset)})
              end
            else
              conn
              |> put_status(:forbidden)
              |> json(%{error: "You cannot update this user"})
            end
        end
  end

  def delete(conn, %{"userID" => user_id}) do
    case Repo.get(User, user_id) do
        nil ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "User not found"})

        user ->
            if can_access_user?(conn, user) do
              case Repo.delete(user) do
                {:ok, _deleted_user} -> send_resp(conn, :no_content, "")
                {:error, _changeset} ->
                  conn
                  |> put_status(:unprocessable_entity)
                  |> json(%{error: "Could not delete user"})
              end
            else
              conn
              |> put_status(:forbidden)
              |> json(%{error: "You cannot delete this user"})
            end
        end
  end

  defp apply_filters(query, params) do
    query
    |> filter_by_email(params["email"])
    |> filter_by_username(params["username"])
  end

  defp filter_by_email(query, nil), do: query

  defp filter_by_email(query, email) do
    where(query, [user], user.email == ^email)
  end

  defp filter_by_username(query, nil), do: query

  defp filter_by_username(query, username) do
    where(query, [user], user.username == ^username)
  end

  defp user_json(user) do
    %{
      id: user.id,
      username: user.username,
      email: user.email,
      role: if(Ecto.assoc_loaded?(user.role) && user.role, do: user.role.name, else: nil)
    }
  end

  # Enforce ownership for employees and team scope for managers.
  defp can_access_user?(conn, user) do
    case role_name(conn) do
      role when role in ["administrator", "hr_payroll"] -> true
      "manager" -> Theme1.Scope.manager_covers?(conn.assigns.current_user, user.id)
      _ -> conn.assigns.current_user.id == user.id
    end
  end

  defp administrator?(conn), do: role_name(conn) == "administrator"

  defp role_name(conn) do
    conn.assigns.current_user.role && conn.assigns.current_user.role.name
  end

  defp errors_from_changeset(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} ->
        message
    end)
  end

end