defmodule Theme1.WorkingTime do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :id,
             :start,
             :end,
             :user_id,
             :source,
             :overtime_minutes,
             :shift_end_at,
             :auto_closed,
             :needs_review
           ]}

  schema "workingtimes" do
    field :start, :utc_datetime
    # Nullable: an open clock session has no end until the user clocks out.
    field :end, :utc_datetime
    # "clock" for clock-in/out sessions, "manual" for admin/manager entries.
    field :source, :string, default: "manual"
    # Computed on clock-out or manual save.
    field :overtime_minutes, :integer, default: 0
    # Snapshot of the resolved shift-end datetime at the time this record closed.
    field :shift_end_at, :utc_datetime
    # True when the auto-close worker capped a forgotten clock-out.
    field :auto_closed, :boolean, default: false
    # True when the record needs manager/admin review (auto-closed, etc.).
    field :needs_review, :boolean, default: false

    belongs_to :user, Theme1.User, foreign_key: :user_id
  end

  @doc """
  Manual entry or admin/manager record creation. Requires both start and end.
  """
  def changeset(workingtime, attrs) do
    workingtime
    |> cast(attrs, [:start, :end, :user_id, :source])
    |> validate_required([:start, :end, :user_id])
    |> validate_inclusion(:source, ["clock", "manual"])
    |> validate_end_after_start()
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Opens a clock-in session. Only `start` is set; `end` stays nil until clock-out.
  """
  def clock_in_changeset(workingtime, attrs) do
    workingtime
    |> cast(attrs, [:start, :user_id])
    |> put_change(:source, "clock")
    |> validate_required([:start, :user_id])
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Closes a clock-out session with computed overtime and shift snapshot.
  """
  def clock_out_changeset(workingtime, attrs) do
    workingtime
    |> cast(attrs, [:end, :overtime_minutes, :shift_end_at])
    |> validate_required([:end])
    |> validate_end_after_start()
  end

  @doc """
  Marks a record as auto-closed and needing review.
  """
  def auto_close_changeset(workingtime, attrs) do
    workingtime
    |> cast(attrs, [:end, :overtime_minutes, :shift_end_at])
    |> put_change(:auto_closed, true)
    |> put_change(:needs_review, true)
    |> validate_required([:end])
  end

  def open?(%__MODULE__{end: nil}), do: true
  def open?(%__MODULE__{}), do: false

  defp validate_end_after_start(changeset) do
    start_dt = get_field(changeset, :start)
    end_dt = get_field(changeset, :end)

    cond do
      is_nil(start_dt) or is_nil(end_dt) -> changeset
      DateTime.compare(end_dt, start_dt) == :gt -> changeset
      true -> add_error(changeset, :end, "must be after the start time")
    end
  end
end