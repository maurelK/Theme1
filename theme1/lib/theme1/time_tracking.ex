defmodule Theme1.TimeTracking do
  @moduledoc """
  Core clock-in/clock-out logic and shift-aware overtime computation.

  Model: a working-time record with `source = "clock"` and `end = nil`
  represents an open session. Clock-in inserts it; clock-out closes it and
  computes overtime relative to the user's effective shift end.

  Overtime rule: overtime is the overlap between [shift_end_at, ∞) and the
  session's [start, end). That is, only time actually worked *after* shift
  end counts. Late clock-ins and early clock-ins are handled correctly.
  """

  import Ecto.Query

  alias Theme1.{Repo, WorkingTime, Shifts}

  @max_session_hours 12
  @max_session_minutes @max_session_hours * 60

  @doc """
  Open a new clock session for the user.

  Rejects if the user already has an open session. The admin/manager can
  fix a stale open session with a manual edit; the auto-close worker will
  also cap orphaned sessions after #{@max_session_hours}h.
  """
  def clock_in(%Theme1.User{id: user_id} = user) do
    case find_open_session(user_id) do
      %WorkingTime{} ->
        {:error, :already_clocked_in}

      nil ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        attrs = %{
          start: now,
          user_id: user_id
        }

        %WorkingTime{}
        |> WorkingTime.clock_in_changeset(attrs)
        |> Repo.insert()
        |> case do
          {:ok, record} -> {:ok, preload_user(record, user)}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @doc """
  Close the user's open session and compute overtime against their shift.

  Uses the clamped overtime formula: only overlap with [shift_end_at, ∞)
  counts, so late clock-ins don't inflate overtime.
  """
  def clock_out(%Theme1.User{id: user_id} = user) do
    case find_open_session(user_id) do
      nil ->
        {:error, :not_clocked_in}

      %WorkingTime{} = record ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        close_and_save(record, user, now, false)
    end
  end

  @doc """
  Whether the user currently has an open session, plus timing details.
  """
  def current_status(%Theme1.User{id: user_id} = user) do
    record = find_open_session(user_id)
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    shift = Shifts.effective_shift(user)

    case record do
      nil ->
        %{
          in: false,
          since: nil,
          duration_minutes: 0,
          shift: shift_summary(shift)
        }

      %WorkingTime{start: start} ->
        %{
          in: true,
          since: start,
          duration_minutes: minutes_between(start, now),
          shift: shift_summary(shift)
        }
    end
  end

  @doc """
  Auto-close a session that has been open longer than the maximum. Marks
  the record as `auto_closed` and `needs_review` so a manager/admin can
  correct it. Called from the Oban worker.
  """
  def auto_close(%WorkingTime{} = record) do
    capped_end = DateTime.add(record.start, @max_session_minutes * 60, :second)
    user = Repo.preload(record, :user).user
    close_and_save(record, user, capped_end, true)
  end

  def max_session_hours, do: @max_session_hours

  ## Internals

  defp find_open_session(user_id) do
    Repo.one(
      from wt in WorkingTime,
        where: wt.user_id == ^user_id and is_nil(wt.end),
        order_by: [desc: wt.start],
        limit: 1
    )
  end

  defp close_and_save(%WorkingTime{} = record, user, end_dt, auto?) do
    shift = Shifts.effective_shift(user)
    shift_end_at = Shifts.shift_end_for(shift, record.start)
    overtime = compute_overtime_minutes(record.start, end_dt, shift_end_at)

    attrs = %{
      end: end_dt,
      overtime_minutes: overtime,
      shift_end_at: shift_end_at
    }

    changeset =
      if auto? do
        WorkingTime.auto_close_changeset(record, attrs)
      else
        WorkingTime.clock_out_changeset(record, attrs)
      end

    case Repo.update(changeset) do
      {:ok, updated} -> {:ok, updated}
      {:error, changeset} -> {:error, changeset}
    end
  end

  # Clamped overtime: overlap of [start, end) with [shift_end_at, ∞).
  defp compute_overtime_minutes(start_dt, end_dt, shift_end_at) do
    overtime_start = max_dt(start_dt, shift_end_at)
    overtime_end = end_dt

    if DateTime.compare(overtime_end, overtime_start) == :gt do
      minutes_between(overtime_start, overtime_end)
    else
      0
    end
  end

  defp max_dt(a, b) do
    case DateTime.compare(a, b) do
      :gt -> a
      _ -> b
    end
  end

  defp minutes_between(a, b) do
    diff = DateTime.diff(b, a, :second)
    max(0, div(diff, 60))
  end

  defp preload_user(record, _user), do: record

  defp shift_summary(shift) do
    %{
      start_minutes: shift.start_minutes,
      end_minutes: shift.end_minutes,
      tz_offset_minutes: shift.tz_offset_minutes,
      source: shift.source
    }
  end
end