defmodule Theme1.Repo.Migrations.CreateIdempotencyRecords do
  use Ecto.Migration

  # Responses to write requests sent with an Idempotency-Key header, so that an
  # action replayed by the mobile outbox (create a team, request a correction...)
  # is applied once and the replay receives the original response.
  def change do
    create table(:idempotency_records) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :key, :string, null: false
      add :method, :string, null: false
      add :path, :string, null: false
      add :status, :integer, null: false
      add :response_body, :text

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:idempotency_records, [:user_id, :key])
  end
end
