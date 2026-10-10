defmodule Theme1Web.WorkingTimeController do
  use Theme1Web, :controller

  import Ecto.Query
  alias Theme1.{Repo, WorkingTime, Scope}

  def create(conn, %{"userID" => user_id} = params) do
    case Integer.parse(to_string(user_id)) do
      {uid, _} ->
        case authorize_create(conn, uid) do
          :ok ->
            working_time_params =
              params
              |> Map.get("workingtime", %{})
              |> Map.put("user_id", uid)

            changeset = WorkingTime.changeset(%WorkingTime{}, working_time_params)

            case Repo.insert(changeset) do
              {:ok, working_time} ->
                conn
                |> put_status(:created)
                |> json(%{data: working_time})

              {:error, changeset} ->
                conn
                |> put_status(:unprocessable_entity)
                |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, &translate_errors/1)})
            end

          {:error, :forbidden} ->
            conn
            |> put_status(:forbidden)
            |> json(%{error: "You cannot create records for this user"})

          {:error, :role_not_allowed} ->
            conn
            |> put_status(:forbidden)
            |> json(%{error: "Employees cannot modify working times directly"})
        end

      :error ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid user ID"})
    end
  end

  def index(conn, %{"userID" => user_id} = params) do
    case Integer.parse(to_string(user_id)) do
      {uid, _} ->
        start_date = params["start"]
        end_date = params["end"]

        query = from w in WorkingTime, where: w.user_id == ^uid

        query = if start_date && start_date != "" do
          from w in query, where: w.start >= ^start_date
        else
          query
        end

        query = if end_date && end_date != "" do
          from w in query, where: w.end <= ^end_date
        else
          query
        end

        working_times = Repo.all(query)
        json(conn, %{data: working_times})

      :error ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid user ID"})
    end
  end

  def show(conn, %{"userID" => user_id, "id" => id}) do
    case {Integer.parse(to_string(user_id)), Integer.parse(to_string(id))} do
      {{uid, _}, {wt_id, _}} ->
        working_time = Repo.get_by(WorkingTime, id: wt_id, user_id: uid)

        case working_time do
          nil ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "Working time not found"})

          working_time ->
            json(conn, %{data: working_time})
        end

      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid parameters"})
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Integer.parse(to_string(id)) do
      {wt_id, _} ->
        case Repo.get(WorkingTime, wt_id) do
          nil ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "Working time not found"})

          %WorkingTime{user_id: owner_id} = working_time ->
            case authorize_record(conn, owner_id) do
              :ok ->
                working_time_params = Map.get(params, "workingtime", %{})

                changeset = WorkingTime.changeset(working_time, working_time_params)

                case Repo.update(changeset) do
                  {:ok, updated_working_time} ->
                    json(conn, %{data: updated_working_time})

                  {:error, changeset} ->
                    conn
                    |> put_status(:unprocessable_entity)
                    |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, &translate_errors/1)})
                end

              {:error, :forbidden} ->
                # Managers outside scope see a 404 to avoid leaking existence.
                conn
                |> put_status(:not_found)
                |> json(%{error: "Working time not found"})

              {:error, :role_not_allowed} ->
                conn
                |> put_status(:forbidden)
                |> json(%{error: "Employees cannot modify working times directly"})
            end
        end

      :error ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid working time ID"})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Integer.parse(to_string(id)) do
      {wt_id, _} ->
        case Repo.get(WorkingTime, wt_id) do
          nil ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "Working time not found"})

          %WorkingTime{user_id: owner_id} = working_time ->
            case authorize_record(conn, owner_id) do
              :ok ->
                case Repo.delete(working_time) do
                  {:ok, _deleted} ->
                    send_resp(conn, :no_content, "")

                  {:error, _changeset} ->
                    conn
                    |> put_status(:unprocessable_entity)
                    |> json(%{error: "Could not delete working time"})
                end

              {:error, :forbidden} ->
                conn
                |> put_status(:not_found)
                |> json(%{error: "Working time not found"})

              {:error, :role_not_allowed} ->
                conn
                |> put_status(:forbidden)
                |> json(%{error: "Employees cannot modify working times directly"})
            end
        end

      :error ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid working time ID"})
    end
  end

  ## Internals

  # For create: the target user is known from the URL.
  #   - administrator / hr_payroll: unrestricted
  #   - manager: must cover or own the target
  #   - employee / other: forbidden
  defp authorize_create(conn, target_user_id) do
    case role_name(conn) do
      role when role in ["administrator", "hr_payroll"] ->
        :ok

      "manager" ->
        if Scope.manages_or_owns?(conn.assigns.current_user, target_user_id) do
          :ok
        else
          {:error, :forbidden}
        end

      _ ->
        {:error, :role_not_allowed}
    end
  end

  # For update/delete: we look up the record's owner and apply the same rule.
  # For managers out of scope we return :forbidden and the caller translates
  # it into a 404 to avoid leaking record existence.
  defp authorize_record(conn, owner_id) do
    case role_name(conn) do
      role when role in ["administrator", "hr_payroll"] ->
        :ok

      "manager" ->
        if Scope.manages_or_owns?(conn.assigns.current_user, owner_id) do
          :ok
        else
          {:error, :forbidden}
        end

      _ ->
        {:error, :role_not_allowed}
    end
  end

  defp role_name(conn) do
    conn.assigns.current_user.role && conn.assigns.current_user.role.name
  end

    # Handle both Ecto changesets and the bare {message, opts} tuples that
  # validate_* helpers produce when they short-circuit into a list.
  defp translate_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp translate_errors({msg, opts}) when is_binary(msg) and is_list(opts) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  defp translate_errors(other), do: inspect(other)
end