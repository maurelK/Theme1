defmodule Theme1.Clock do 
    use Ecto.Schema
    import Ecto.Changeset
    @derive {Jason.Encoder, only: [:id, :time, :status, :user_id]}
    schema "clocks" do 
        field :time, :utc_datetime 
        field :status, :boolean 
        belongs_to :user, Theme1.User 
        # Champs du mode hors ligne
        field :idempotency_key, :string
        field :received_at, :utc_datetime
        field :device_time, :utc_datetime
        field :time_source, :string, default: "server"
    end


    def changeset(clock, attrs) do
        clock
        |> cast(attrs, [:time, :status, :user_id])
        |> validate_required([:time, :status, :user_id])
    end
      # Changeset utilisé par Theme1.Clocks.record_clock/4 (en ligne comme hors ligne)
    def record_changeset(clock, attrs) do
        clock
        |> cast(attrs, [
          :time, :status, :user_id, :idempotency_key, :received_at,
          :device_time, :time_source
        ])
        |> validate_required([:time, :status, :user_id, :received_at, :time_source])
        |> validate_inclusion(:time_source, ["server", "device"])
        |> unique_constraint([:user_id, :idempotency_key])
    end

end
