defmodule Theme1.CorrectionRequest do
  use Ecto.Schema
  import Ecto.Changeset

  # A request records the employee explanation, the proposed new values, and
  # the reviewer decision. On approval the proposed values are applied to the
  # underlying working_time record.
  schema "correction_requests" do
    field :reason, :string
    field :status, :string, default: "pending"
    field :response, :string
    field :proposed_start, :utc_datetime
    field :proposed_end, :utc_datetime

    belongs_to :working_time, Theme1.WorkingTime
    belongs_to :requester, Theme1.User
    belongs_to :reviewer, Theme1.User
    timestamps()
  end

  def changeset(request, attrs) do
    request
    |> cast(attrs, [
      :working_time_id,
      :requester_id,
      :reason,
      :status,
      :response,
      :reviewer_id,
      :proposed_start,
      :proposed_end
    ])
    |> validate_required([:working_time_id, :requester_id, :reason])
    |> validate_inclusion(:status, ["pending", "approved", "rejected"])
    |> foreign_key_constraint(:working_time_id)
    |> foreign_key_constraint(:requester_id)
    |> foreign_key_constraint(:reviewer_id)
  end

  def review_changeset(request, attrs) do
    request
    |> cast(attrs, [:status, :response, :reviewer_id])
    |> validate_required([:status, :reviewer_id])
    |> validate_inclusion(:status, ["approved", "rejected"])
  end
end