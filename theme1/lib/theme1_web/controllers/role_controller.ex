defmodule Theme1Web.RoleController do
  use Theme1Web, :controller

  alias Theme1.Repo
  alias Theme1.Role

  # Roles are predefined and can only be read by authenticated users.
  def index(conn, _params) do
    roles = Repo.all(Role)
    json(conn, Enum.map(roles, &%{id: &1.id, name: &1.name}))
  end
end
