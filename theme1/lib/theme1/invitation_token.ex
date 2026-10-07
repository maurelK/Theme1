defmodule Theme1.InvitationToken do
  use Ecto.Schema

  # Invitation tokens are single-use credentials that let an invited user set
  # their initial password. They expire and are invalidated after first use.
  schema "invitation_tokens" do
    field :token_digest, :string
    field :expires_at, :utc_datetime
    field :used_at, :utc_datetime
    belongs_to :user, Theme1.User
    timestamps(updated_at: false)
  end
end