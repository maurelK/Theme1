defmodule Theme1.Repo.Migrations.CreatePasswordResetTokens do
  use Ecto.Migration

  def change do
    # Store only a digest so a database read cannot be used to reset accounts directly.
    create table(:password_reset_tokens) do
      add :token_digest, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :expires_at, :utc_datetime, null: false
      add :used_at, :utc_datetime
      timestamps(updated_at: false)
    end

    create unique_index(:password_reset_tokens, [:token_digest])
    create index(:password_reset_tokens, [:user_id])

  end
end
