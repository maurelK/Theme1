alias Theme1.{CorrectionRequest, Repo, Shifts, WorkingTime}

# --- Setup: create a workingtime record with a deliberately wrong end time ---
# Shift is 09:00–17:00 UTC (default). We make a session that ends at 16:00,
# so no overtime initially. The correction will move end to 18:30 → 90min OT.

start_dt = ~U[2026-10-08 09:00:00Z]
wrong_end = ~U[2026-10-08 16:00:00Z]
correct_end = ~U[2026-10-08 18:30:00Z]

{:ok, wt} =
  %WorkingTime{}
  |> Ecto.Changeset.change(%{
    user_id: 1,
    start: start_dt,
    end: wrong_end,
    source: "manual"
  })
  |> Repo.insert()

IO.inspect({wt.id, wt.start, wt.end, wt.overtime_minutes}, label: "created workingtime")

# --- Employee submits a correction request proposing the correct end ---
{:ok, request} =
  CorrectionRequest.changeset(%CorrectionRequest{}, %{
    working_time_id: wt.id,
    requester_id: 1,
    reason: "Forgot to clock out on time",
    status: "pending",
    proposed_start: start_dt,
    proposed_end: correct_end
  })
  |> Repo.insert()

IO.inspect(
  {request.id, request.status, request.proposed_start, request.proposed_end},
  label: "created correction request"
)

# --- Simulate the review action ---
# We call the same helper the controller uses. We replicate the transaction
# here because `apply_approved/3` is private. Instead we build the change
# ourselves to confirm the overtime math.

shift = Shifts.effective_shift(Repo.get!(Theme1.User, 1))
shift_end_at = Shifts.shift_end_for(shift, start_dt)
IO.inspect({shift.source, shift.start_minutes, shift.end_minutes, shift_end_at}, label: "resolved shift")

# Compute overtime the way update_working_time would
overtime_start =
  case DateTime.compare(start_dt, shift_end_at) do
    :gt -> start_dt
    _ -> shift_end_at
  end

overtime =
  if DateTime.compare(correct_end, overtime_start) == :gt do
    div(DateTime.diff(correct_end, overtime_start, :second), 60)
  else
    0
  end

IO.inspect({overtime_start, correct_end, overtime}, label: "expected overtime")

# --- Apply the correction manually (simulating approved review) ---
{:ok, updated_wt} =
  wt
  |> Ecto.Changeset.change(%{
    end: correct_end,
    shift_end_at: shift_end_at,
    overtime_minutes: overtime
  })
  |> Repo.update()

{:ok, reviewed} =
  request
  |> CorrectionRequest.review_changeset(%{
    status: "approved",
    response: "Approved — corrected to actual clock-out time",
    reviewer_id: 1
  })
  |> Repo.update()

IO.inspect(
  {updated_wt.id, updated_wt.start, updated_wt.end, updated_wt.overtime_minutes},
  label: "updated workingtime"
)

IO.inspect(
  {reviewed.id, reviewed.status, reviewed.response},
  label: "reviewed request"
)