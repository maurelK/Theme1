defmodule Theme1.RefreshToken do
  use Ecto.Schema

  schema "refresh_tokens" do
    field :token_digest, :string
    field :expires_at, :utc_datetime
    field :revoked_at, :utc_datetime
    belongs_to :user, Theme1.User

    timestamps(type: :utc_datetime)
  end
end
