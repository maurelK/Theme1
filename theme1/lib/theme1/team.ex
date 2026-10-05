defmodule Theme1.Team do
  use Ecto.Schema

  # Teams group users without limiting a user to a single department.
  schema "teams" do
    field :name, :string

    many_to_many :users, Theme1.User, join_through: "team_memberships"
    timestamps()
  end
end