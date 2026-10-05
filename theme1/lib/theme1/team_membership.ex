defmodule Theme1.TeamMembership do
  use Ecto.Schema

  # The join schema gives Ecto an explicit ownership boundary for memberships.
  @primary_key false
  schema "team_memberships" do
    belongs_to :team, Theme1.Team
    belongs_to :user, Theme1.User
    timestamps(updated_at: false)
  end
end