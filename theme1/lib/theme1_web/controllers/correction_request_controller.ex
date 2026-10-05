defmodule Theme1Web.CorrectionRequestController do
  use Theme1Web, :controller

  import Ecto.Query
  alias Theme1.{CorrectionRequest, Repo, WorkingTime}

  # Employees submit a reason against a working-time record they own.
  def create(conn, %{"id" => working_time_id, "reason" => reason}) do
    user = conn.assigns.current_user

    with {working_time_id, ""} <- Integer.parse(working_time_id),
         %WorkingTime{user_id: user_id} <- Repo.get(WorkingTime, working_time_id),
         true <- user_id == user.id,
         {:ok, request} <- Repo.insert(%CorrectionRequest{
           working_time_id: working_time_id,
           requester_id: user.id,
           reason: reason,
           status: "pending"
         }) do
      conn |> put_status(:created) |> json(%{data: request_json(request)})
    else
      false -> forbidden(conn)
      nil -> conn |> put_status(:not_found) |> json(%{error: "Working time not found"})
      _ -> conn |> put_status(:unprocessable_entity) |> json(%{error: "A correction reason is required"})
    end
  end

  def create(conn, _params), do: conn |> put_status(:unprocessable_entity) |> json(%{error: "A correction reason is required"})

  # Managers, HR/payroll, and administrators can review pending requests.
  def index(conn, _params) do
    requests =
      from(request in CorrectionRequest,
        where: request.status == "pending",
        order_by: [asc: request.inserted_at],
        preload: [:requester, :working_time]
      )
      |> Repo.all()

    json(conn, %{data: Enum.map(requests, &request_json/1)})
  end

  # Record a review decision and its explanation for the audit trail.
  def review(conn, %{"id" => id, "status" => status} = params) when status in ["approved", "rejected"] do
    case Integer.parse(id) do
      {request_id, ""} ->
        case Repo.get(CorrectionRequest, request_id) do
          nil -> conn |> put_status(:not_found) |> json(%{error: "Correction request not found"})
          request ->
            changes = %{status: status, response: params["response"], reviewer_id: conn.assigns.current_user.id}
            {:ok, reviewed} = request |> Ecto.Changeset.change(changes) |> Repo.update()
            json(conn, %{data: request_json(reviewed)})
        end

      _ -> conn |> put_status(:bad_request) |> json(%{error: "Invalid correction request ID"})
    end
  end

  def review(conn, _params), do: conn |> put_status(:unprocessable_entity) |> json(%{error: "A valid review status is required"})

  defp request_json(request) do
    %{id: request.id, working_time_id: request.working_time_id, requester_id: request.requester_id, reason: request.reason, status: request.status, response: request.response}
  end

  defp forbidden(conn), do: conn |> put_status(:forbidden) |> json(%{error: "You can only correct your own working time"})
end
