alias Theme1.{Repo, WorkingTime, Workers}

# 1. Insert a stale open session (13 hours ago, no end)
stale_start =
  DateTime.utc_now()
  |> DateTime.truncate(:second)
  |> DateTime.add(-13 * 3600, :second)

{:ok, stale} =
  %WorkingTime{}
  |> WorkingTime.clock_in_changeset(%{start: stale_start, user_id: 1})
  |> Repo.insert()

IO.inspect({stale.id, stale.start, stale.end}, label: "inserted stale session")

# 2. Run the worker manually
:ok = Workers.AutoCloseClockSessions.perform(%Oban.Job{})
IO.puts("worker perform returned :ok")

# 3. Query auto-closed records
import Ecto.Query

records =
  Repo.all(
    from wt in WorkingTime,
      where: wt.auto_closed == true,
      select: {wt.id, wt.start, wt.end, wt.overtime_minutes, wt.needs_review}
  )

IO.inspect(records, label: "auto-closed records")

# 4. Confirm the session is no longer open
open_count =
  Repo.aggregate(
    from(wt in WorkingTime, where: is_nil(wt.end)),
    :count
  )

IO.inspect(open_count, label: "open sessions remaining")