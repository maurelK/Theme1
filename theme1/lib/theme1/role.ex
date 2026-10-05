defmodule Theme1.Role do
  use Ecto.Schema

  # Roles are predefined records used by authorization checks.
  schema "roles" do
    field :name, :string

    has_many :users, Theme1.User
    timestamps()
  end
end
