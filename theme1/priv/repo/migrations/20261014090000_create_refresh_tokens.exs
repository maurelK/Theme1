defmodule Theme1.Repo.Migrations.CreateRefreshTokens do
  use Ecto.Migration

  # Long-lived, revocable credentials for the mobile app. The JWT is stateless
  # and cannot be revoked; these rows can (logout, password change, deletion).
  def change do
    create table(:refresh_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      # SHA-256 of the token: a database leak does not expose usable tokens.
      add :token_digest, :string, null: false
      add :expires_at, :utc_datetime, null: false
      # Set on rotation, logout or forced revocation.
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:refresh_tokens, [:token_digest])
    create index(:refresh_tokens, [:user_id])
  end
end
