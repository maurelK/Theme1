defmodule Theme1.Workers.AutoCloseClockSessions do
  @moduledoc """
  Periodically closes clock sessions that have been open longer than the
  maximum session length. Marks them as `auto_closed` and `needs_review`
  so a manager or admin can correct them.
  """

  use Oban.Worker,
    queue: :auto_close,
    max_attempts: 3,
    unique: [period: 60]

  import Ecto.Query

  alias Theme1.{Repo, WorkingTime, TimeTracking}

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    max_minutes = TimeTracking.max_session_hours() * 60

    cutoff =
      DateTime.utc_now()
      |> DateTime.truncate(:second)
      |> DateTime.add(-max_minutes * 60, :second)

    stale_sessions =
      Repo.all(
        from wt in WorkingTime,
          where: is_nil(wt.end) and wt.start < ^cutoff
      )

    Enum.each(stale_sessions, fn session ->
      case TimeTracking.auto_close(session) do
        {:ok, _} -> :ok
        {:error, changeset} ->
          require Logger
          Logger.warning(
            "Failed to auto-close clock session #{session.id}: " <>
              inspect(Ecto.Changeset.traverse_errors(changeset, fn {m, _} -> m end))
          )
      end
    end)

    :ok
  end
end