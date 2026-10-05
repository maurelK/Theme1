defmodule Theme1Web.RolePlug do
  import Plug.Conn

  # Normalize router atoms and database strings to the same role representation.
  def init(roles) when is_list(roles), do: Enum.map(roles, &to_string/1)
  def init(role), do: [to_string(role)]

  def call(%Plug.Conn{assigns: %{current_user: user}} = conn, allowed_roles) do
    role_name = if user.role, do: user.role.name, else: nil

    if role_name in allowed_roles do
      conn
    else
      forbidden(conn)
    end
  end

  def call(conn, _allowed_roles), do: forbidden(conn)

  defp forbidden(conn) do
    conn
    |> put_status(:forbidden)
    |> Phoenix.Controller.json(%{error: "Insufficient permissions"})
    |> halt()
  end
end
