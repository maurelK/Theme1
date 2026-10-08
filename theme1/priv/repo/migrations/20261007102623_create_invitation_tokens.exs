defmodule Theme1.Repo.Migrations.CreateInvitationTokens do
  use Ecto.Migration

  def change do
    create table(:invitation_tokens) do
      add :token_digest, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :used_at, :utc_datetime
      add :user_id, references(:users, on_delete: :delete_all), null: false
      timestamps(updated_at: false)
    end

    create index(:invitation_tokens, [:token_digest])
    create index(:invitation_tokens, [:user_id])
  end
end