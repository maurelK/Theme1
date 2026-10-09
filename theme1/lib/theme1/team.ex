defmodule Theme1.Team do
  use Ecto.Schema
  import Ecto.Changeset

  # Teams group users without limiting a user to a single department.
  # Shift fields mirror the user-level config and act as a fallback when a
  # member has no personal shift assigned.
  schema "teams" do
    field :name, :string

    # Fixed UTC offset in minutes (+60 CET, +120 CEST, 0 UTC).
    field :timezone_offset_minutes, :integer, default: 0
    # Minutes from local midnight (540 = 09:00, 1020 = 17:00).
    field :shift_start_minutes, :integer
    field :shift_end_minutes, :integer

    many_to_many :users, Theme1.User, join_through: "team_memberships"
    timestamps()
  end

  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end

  # Admin-only: configure the default shift for members without a personal shift.
  def shift_changeset(team, attrs) do
    team
    |> cast(attrs, [:timezone_offset_minutes, :shift_start_minutes, :shift_end_minutes])
    |> validate_number(:timezone_offset_minutes, greater_than_or_equal_to: -720, less_than_or_equal_to: 840)
    |> validate_number(:shift_start_minutes, greater_than_or_equal_to: 0, less_than_or_equal_to: 1439)
    |> validate_number(:shift_end_minutes, greater_than_or_equal_to: 0, less_than_or_equal_to: 1439)
    |> validate_shift_order()
  end

  defp validate_shift_order(changeset) do
    start_m = get_field(changeset, :shift_start_minutes)
    end_m = get_field(changeset, :shift_end_minutes)

    if is_integer(start_m) and is_integer(end_m) and end_m <= start_m do
      add_error(changeset, :shift_end_minutes, "must be after the shift start time")
    else
      changeset
    end
  end
end