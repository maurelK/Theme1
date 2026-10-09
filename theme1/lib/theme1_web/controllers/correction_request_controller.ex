defmodule Theme1Web.CorrectionRequestController do
  use Theme1Web, :controller

  import Ecto.Query
  alias Theme1.{CorrectionRequest, Repo, Shifts, WorkingTime}

  @doc """
  Employees submit a reason and optional proposed new times against a
  working-time record they own.
  """
  def create(conn, %{"id" => working_time_id} = params) do
    user = conn.assigns.current_user
    reason = params["reason"]

    with {wt_id, ""} <- Integer.parse(to_string(working_time_id)),
         %WorkingTime{user_id: user_id} = wt <- Repo.get(WorkingTime, wt_id),
         true <- user_id == user.id,
         {:ok, proposed_start} <- parse_datetime(params["proposed_start"]),
         {:ok, proposed_end} <- parse_datetime(params["proposed_end"]),
         {:ok, request} <-
           Repo.insert(
             CorrectionRequest.changeset(%CorrectionRequest{}, %{
               working_time_id: wt_id,
               requester_id: user.id,
               reason: reason,
               status: "pending",
               proposed_start: proposed_start || wt.start,
               proposed_end: proposed_end || wt.end
             })
           ) do
      conn |> put_status(:created) |> json(%{data: request_json(request)})
    else
      :error -> conn |> put_status(:bad_request) |> json(%{error: "Invalid working time ID"})
      {:error, :invalid_datetime} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Invalid proposed time"})
      false -> forbidden(conn)
      nil -> conn |> put_status(:not_found) |> json(%{error: "Working time not found"})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {m, _} -> m end)})
    end
  end

  def create(conn, _params) do
    conn |> put_status(:unprocessable_entity) |> json(%{error: "A correction reason is required"})
  end

  @doc """
  Lists pending correction requests for reviewers.
  """
  def index(conn, _params) do
    role = conn.assigns.current_user.role && conn.assigns.current_user.role.name

    base =
      from(request in CorrectionRequest,
        where: request.status == "pending",
        order_by: [asc: request.inserted_at],
        preload: [:requester, :working_time]
      )

    requests =
      case role do
        r when r in ["administrator", "hr_payroll"] ->
          Repo.all(base)

        "manager" ->
          # Only requests about records belonging to the manager's team members.
          manager = conn.assigns.current_user
          team_ids = manager_team_ids(manager)

          if team_ids == [] do
            []
          else
            from(r in base,
              join: w in Theme1.WorkingTime, on: w.id == r.working_time_id,
              join: m in Theme1.TeamMembership,
                on: m.user_id == w.user_id and m.team_id in ^team_ids,
              distinct: r.id
            )
            |> Repo.all()
          end

        _ ->
          []
      end

    json(conn, %{data: Enum.map(requests, &request_json/1)})
  end

  defp manager_team_ids(manager) do
    import Ecto.Query
    Theme1.Repo.all(
      from m in Theme1.TeamMembership,
        where: m.user_id == ^manager.id,
        select: m.team_id
    )
  end

  @doc """
  Review a pending request. On approval, applies the proposed times to the
  underlying working-time record and recomputes overtime — all in one
  transaction so a partial failure can't leave inconsistent state.
  """
  def review(conn, %{"id" => id, "status" => status} = params)
      when status in ["approved", "rejected"] do
    case Integer.parse(to_string(id)) do
      {request_id, ""} ->
        case Repo.get(CorrectionRequest, request_id) |> Repo.preload(:working_time) do
          nil ->
            conn |> put_status(:not_found) |> json(%{error: "Correction request not found"})

          %CorrectionRequest{status: "pending"} = request ->
            owner_id = request.working_time && request.working_time.user_id

            case authorize_review(conn, owner_id) do
              :ok ->
                apply_review(conn, request, status, params["response"])

              {:error, :forbidden} ->
                conn
                |> put_status(:not_found)
                |> json(%{error: "Correction request not found"})

              {:error, :role_not_allowed} ->
                conn
                |> put_status(:forbidden)
                |> json(%{error: "You cannot review correction requests"})
            end

          %CorrectionRequest{status: existing} ->
            conn
            |> put_status(:conflict)
            |> json(%{error: "Request already #{existing}"})
        end

      _ ->
        conn |> put_status(:bad_request) |> json(%{error: "Invalid correction request ID"})
    end
  end

  def review(conn, _params) do
    conn |> put_status(:unprocessable_entity) |> json(%{error: "A valid review status is required"})
  end

  ## Internals

  defp apply_review(conn, request, status, response) do
    reviewer_id = conn.assigns.current_user.id

    result =
      case status do
        "approved" ->
          apply_approved(request, reviewer_id, response)

        "rejected" ->
          request
          |> CorrectionRequest.review_changeset(%{
            status: "rejected",
            response: response,
            reviewer_id: reviewer_id
          })
          |> Repo.update()
      end

      case result do
      {:ok, reviewed} ->
        json(conn, %{data: request_json(reviewed)})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {m, _} -> m end)})

      {:error, reason} when is_atom(reason) ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: to_string(reason)})
    end
  end

  # Apply the proposed times, recompute overtime, then flip the request status.
  # Wrapped in a Multi so a failure at any step rolls back all changes.
  defp apply_approved(request, reviewer_id, response) do
    wt = request.working_time

    Ecto.Multi.new()
    |> Ecto.Multi.run(:working_time, fn _repo, _changes ->
      update_working_time(wt, request.proposed_start, request.proposed_end)
    end)
    |> Ecto.Multi.update(
      :request,
      CorrectionRequest.review_changeset(request, %{
        status: "approved",
        response: response,
        reviewer_id: reviewer_id
      })
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{request: reviewed}} -> {:ok, reviewed}
      {:error, _step, %Ecto.Changeset{} = changeset, _changes} -> {:error, changeset}
      {:error, _step, reason, _changes} when is_atom(reason) -> {:error, reason}
    end
  end

  # Recompute overtime when either start or end changes. This mirrors the
  # logic used by TimeTracking.clock_out, but works on arbitrary values.
  defp update_working_time(%WorkingTime{} = wt, proposed_start, proposed_end) do
    start_dt = proposed_start || wt.start
    end_dt = proposed_end || wt.end

    cond do
      is_nil(end_dt) ->
        {:error, :cannot_approve_open_session}

      DateTime.compare(end_dt, start_dt) != :gt ->
        {:error, :end_must_be_after_start}

      true ->
        user = Repo.preload(wt, :user).user
        shift = Shifts.effective_shift(user)
        shift_end_at = Shifts.shift_end_for(shift, start_dt)
        overtime = compute_overtime(start_dt, end_dt, shift_end_at)

        wt
        |> Ecto.Changeset.change(%{
          start: start_dt,
          end: end_dt,
          shift_end_at: shift_end_at,
          overtime_minutes: overtime
        })
        |> Repo.update()
    end
  end

  defp compute_overtime(start_dt, end_dt, shift_end_at) do
    overtime_start =
      case DateTime.compare(start_dt, shift_end_at) do
        :gt -> start_dt
        _ -> shift_end_at
      end

    if DateTime.compare(end_dt, overtime_start) == :gt do
      div(DateTime.diff(end_dt, overtime_start, :second), 60)
    else
      0
    end
  end

  defp parse_datetime(nil), do: {:ok, nil}
  defp parse_datetime(""), do: {:ok, nil}

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> {:ok, DateTime.truncate(dt, :second)}
      _ -> {:error, :invalid_datetime}
    end
  end

  defp parse_datetime(_), do: {:error, :invalid_datetime}

  defp request_json(request) do
    %{
      id: request.id,
      working_time_id: request.working_time_id,
      requester_id: request.requester_id,
      reason: request.reason,
      status: request.status,
      response: request.response,
      proposed_start: request.proposed_start,
      proposed_end: request.proposed_end,
      reviewer_id: request.reviewer_id
    }
  end

  # Reviewers can only decide requests about records in their scope.
  # Managers see requests only for their team members; HR and admin see all.
  defp authorize_review(conn, owner_id) do
    role = conn.assigns.current_user.role && conn.assigns.current_user.role.name

    cond do
      role in ["administrator", "hr_payroll"] -> :ok
      role == "manager" and Theme1.Scope.manager_covers?(conn.assigns.current_user, owner_id) -> :ok
      role == "manager" -> {:error, :forbidden}
      true -> {:error, :role_not_allowed}
    end
  end

  defp forbidden(conn) do
    conn |> put_status(:forbidden) |> json(%{error: "You can only correct your own working time"})
  end
end