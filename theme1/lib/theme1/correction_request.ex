defmodule Theme1.CorrectionRequest do
  use Ecto.Schema

  # A request records the employee explanation and the reviewer decision.
  schema "correction_requests" do
    field :reason, :string
    field :status, :string, default: "pending"
    field :response, :string

    belongs_to :working_time, Theme1.WorkingTime
    belongs_to :requester, Theme1.User
    belongs_to :reviewer, Theme1.User
    timestamps()
  end
end