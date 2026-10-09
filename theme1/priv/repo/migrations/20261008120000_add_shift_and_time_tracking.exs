defmodule Theme1.Repo.Migrations.AddShiftAndTimeTracking do
  use Ecto.Migration

  def change do
    # Users: timezone offset and personal shift (highest priority).
    # timezone_offset_minutes is a fixed UTC offset in minutes: +60 for CET, +120 for CEST, 0 for UTC.
    # Must be adjusted manually if DST rules change.
    alter table(:users) do
      add :timezone_offset_minutes, :integer, null: false, default: 0
      add :shift_start_minutes, :integer
      add :shift_end_minutes, :integer
    end

    # Teams: timezone offset and team shift (fallback when user has no personal shift).
    alter table(:teams) do
      add :timezone_offset_minutes, :integer, null: false, default: 0
      add :shift_start_minutes, :integer
      add :shift_end_minutes, :integer
    end

    # Working times: support open clock sessions, manual vs clock source,
    # computed overtime, and the shift-end snapshot used to compute it.
    alter table(:workingtimes) do
      modify :end, :utc_datetime, null: true

      add :source, :string, null: false, default: "manual"
      add :overtime_minutes, :integer, null: false, default: 0
      add :shift_end_at, :utc_datetime
      add :auto_closed, :boolean, null: false, default: false
      add :needs_review, :boolean, null: false, default: false
    end

    create index(:workingtimes, [:user_id, :end])
    create index(:workingtimes, [:needs_review])
    create index(:workingtimes, [:source])

    # Correction requests: proposed new values to apply on approval.
    alter table(:correction_requests) do
      add :proposed_start, :utc_datetime
      add :proposed_end, :utc_datetime
    end
  end
end