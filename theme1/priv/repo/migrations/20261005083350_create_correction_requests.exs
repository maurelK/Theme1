defmodule Theme1.Repo.Migrations.CreateCorrectionRequests do
  use Ecto.Migration

  def change do
    # Keep correction discussions separate from immutable recorded time entries.
    create table(:correction_requests) do
      add :working_time_id, references(:workingtimes, on_delete: :delete_all), null: false
      add :requester_id, references(:users, on_delete: :delete_all), null: false
      add :reviewer_id, references(:users, on_delete: :nilify_all)
      add :reason, :text, null: false
      add :status, :string, null: false, default: "pending"
      add :response, :text
      timestamps()
    end

    create index(:correction_requests, [:requester_id])
    create index(:correction_requests, [:reviewer_id])
    create index(:correction_requests, [:status])

  end
end
