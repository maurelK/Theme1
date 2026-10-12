defmodule Theme1Web.UserController do
  use Theme1Web, :controller

  import Ecto.Query

  alias Theme1.{Repo, Role, User}

  def index(conn, params) do
    role = role_name(conn)

    users =
      User
      |> where([u], is_nil(u.deleted_at))
      |> apply_filters(params)
      |> Repo.all()
      |> Repo.preload(:role)

    cond do
      role == "manager" ->
        # Managers can discover the whole org to add members to their teams,
        # but they see reduced information (no email) — see public_user/1.
        # Employees in their own teams still get the full record so the
        # directory flows continue to work.
        json(conn, Enum.map(users, &manager_view_json(conn, &1)))

      true ->
        filtered = Enum.filter(users, &can_access_user?(conn, &1))
        json(conn, Enum.map(filtered, &user_json/1))
    end
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

  # Soft-delete a user account. The row is preserved (working times, clocks,
  # correction requests stay intact for reporting) but the account can no
  # longer log in and is hidden from user lists.
  #
  # Self-delete is allowed for everyone. Administrators are subject to the
  # last-admin guard: they cannot delete themselves if they are the only
  # remaining non-deleted administrator.
  def delete(conn, %{"userID" => user_id}) do
    caller = conn.assigns.current_user

    case Repo.get(User, user_id) |> Repo.preload(:role) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "User not found"})

      %User{deleted_at: dt} when not is_nil(dt) ->
        conn |> put_status(:gone) |> json(%{error: "User is already deleted"})

      user ->
        cond do
          not can_access_user?(conn, user) ->
            conn |> put_status(:forbidden) |> json(%{error: "You cannot delete this user"})

          last_admin_deleting_self?(caller, user) ->
            conn
            |> put_status(:forbidden)
            |> json(%{error: "You are the only administrator. Promote another user before deleting your account."})

          true ->
            case user |> User.soft_delete_changeset() |> Repo.update() do
              {:ok, _user} -> send_resp(conn, :no_content, "")
              {:error, changeset} ->
                conn
                |> put_status(:unprocessable_entity)
                |> json(%{errors: errors_from_changeset(changeset)})
            end
        end
    end
  end

  # True if the caller is the target AND the target is the last active administrator.
  defp last_admin_deleting_self?(caller, target) do
    caller.id == target.id and
      target.role &&
      target.role.name == "administrator" and
      active_admin_count() <= 1
  end

  defp active_admin_count do
    admin_role_id =
      case Repo.get_by(Role, name: "administrator") do
        %Role{id: id} -> id
        _ -> nil
      end

    if admin_role_id do
      Repo.aggregate(
        from(u in User,
          where: u.role_id == ^admin_role_id and is_nil(u.deleted_at)
        ),
        :count
      )
    else
      0
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


  # Managers get a reduced view of users they don't cover: name and role only,
  # no email. Users within the manager's own teams get the full record so
  # existing directory flows still work.
  defp manager_view_json(conn, user) do
    full_access? = can_access_user?(conn, user)

    if full_access? do
      user_json(user)
    else
      %{
        id: user.id,
        username: user.username,
        email: nil,
        role: if(Ecto.assoc_loaded?(user.role) && user.role, do: user.role.name, else: nil)
      }
    end
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