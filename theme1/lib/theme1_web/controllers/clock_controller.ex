defmodule Theme1Web.ClockController do
  use Theme1Web, :controller

  alias Theme1.{Repo, User, TimeTracking}

  @doc """
  Clock-in for a user. Any authenticated user can clock themselves in;
  admins can clock anyone in. Managers can clock their team members.
  """
  def clock_in(conn, %{"userID" => user_id}) do
    with {:ok, target_user} <- fetch_target_user(conn, user_id),
         {:ok, record} <- TimeTracking.clock_in(target_user) do
      json(conn, serialize(record))
    else
      {:error, :forbidden} ->
        conn |> put_status(:forbidden) |> json(%{error: "You cannot clock this user"})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "User not found"})

      {:error, :already_clocked_in} ->
        conn |> put_status(:conflict) |> json(%{error: "Already clocked in"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)})
    end
  end

  @doc """
  Clock-out for a user. Same authorization as clock_in.
  """
  def clock_out(conn, %{"userID" => user_id}) do
    with {:ok, target_user} <- fetch_target_user(conn, user_id),
         {:ok, record} <- TimeTracking.clock_out(target_user) do
      json(conn, serialize(record))
    else
      {:error, :forbidden} ->
        conn |> put_status(:forbidden) |> json(%{error: "You cannot clock this user"})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "User not found"})

      {:error, :not_clocked_in} ->
        conn |> put_status(:conflict) |> json(%{error: "Not currently clocked in"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)})
    end
  end

  @doc """
  Current clock status for a user: `in`, `since`, `duration_minutes`, and
  the effective shift. Same authorization as clock_in.
  """
  def status(conn, %{"userID" => user_id}) do
    with {:ok, target_user} <- fetch_target_user(conn, user_id) do
      json(conn, TimeTracking.current_status(target_user))
    else
      {:error, :forbidden} ->
        conn |> put_status(:forbidden) |> json(%{error: "You cannot view this user's clock"})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "User not found"})
    end
  end

  ## Authorization

  # A user can act on their own clock. Admins can act on anyone's clock.
  # Managers can act on their team members' clocks.
  defp fetch_target_user(conn, user_id_param) do
    current_user = conn.assigns.current_user
    role = current_user.role && current_user.role.name

    with {id, ""} <- Integer.parse(to_string(user_id_param)),
         %User{} = target <- Repo.get(User, id) |> Repo.preload([:role, :teams]) do
      cond do
        target.id == current_user.id -> {:ok, target}
        role == "administrator" -> {:ok, target}
        role == "hr_payroll" -> {:ok, target}
        role == "manager" and Theme1.Scope.manager_covers?(current_user, target.id) -> {:ok, target}
        true -> {:error, :forbidden}
      end
    else
      :error -> {:error, :not_found}
      nil -> {:error, :not_found}
    end
  end

  ## Serialization

  defp serialize(record) do
    %{
      id: record.id,
      user_id: record.user_id,
      start: record.start,
      end: record.end,
      source: record.source,
      overtime_minutes: record.overtime_minutes,
      shift_end_at: record.shift_end_at,
      auto_closed: record.auto_closed,
      needs_review: record.needs_review
    }
  end
end