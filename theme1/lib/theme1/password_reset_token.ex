defmodule Theme1.PasswordResetToken do
  use Ecto.Schema

  # Reset tokens are short-lived credentials and are invalid after first use.
  schema "password_reset_tokens" do
    field :token_digest, :string
    field :expires_at, :utc_datetime
    field :used_at, :utc_datetime
    belongs_to :user, Theme1.User
    timestamps(updated_at: false)
  end
end