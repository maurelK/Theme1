alias Theme1.{CorrectionRequest, Repo, WorkingTime}

start_dt = ~U[2026-10-09 09:00:00Z]
wrong_end = ~U[2026-10-09 16:00:00Z]
correct_end = ~U[2026-10-09 19:00:00Z]

{:ok, wt} =
  %WorkingTime{}
  |> Ecto.Changeset.change(%{
    user_id: 1,
    start: start_dt,
    end: wrong_end,
    source: "manual"
  })
  |> Repo.insert()

{:ok, request} =
  CorrectionRequest.changeset(%CorrectionRequest{}, %{
    working_time_id: wt.id,
    requester_id: 1,
    reason: "Clocked out early, actual end was 19:00",
    status: "pending",
    proposed_start: start_dt,
    proposed_end: correct_end
  })
  |> Repo.insert()

IO.inspect(%{working_time_id: wt.id, correction_request_id: request.id})