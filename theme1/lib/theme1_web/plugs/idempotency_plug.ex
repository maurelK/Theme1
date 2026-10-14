defmodule Theme1Web.IdempotencyPlug do
  @moduledoc """
  Makes write requests safe to replay. When a POST/PUT/PATCH/DELETE carries an
  `Idempotency-Key` header, the first response (below 500) is stored for that
  user and key; a later request with the same key gets the stored response
  without running the action again.

  The mobile app sends one key per offline action, so an action whose response
  was lost, or that is replayed by the sync, never creates a second team or a
  second correction request. Runs after AuthPlug: keys are scoped per user.
  """

  import Ecto.Query
  import Plug.Conn

  alias Theme1.Repo

  @methods ~w(POST PUT PATCH DELETE)
  @max_key_length 100

  def init(opts), do: opts

  def call(%Plug.Conn{method: method} = conn, _opts) when method in @methods do
    with %{id: user_id} <- conn.assigns[:current_user],
         [key | _] when key != "" <- get_req_header(conn, "idempotency-key") do
      key = String.slice(key, 0, @max_key_length)

      case find(user_id, key) do
        nil -> store_on_send(conn, user_id, key)
        record -> replay(conn, record)
      end
    else
      _ -> conn
    end
  end

  def call(conn, _opts), do: conn

  defp find(user_id, key) do
    Repo.one(
      from r in "idempotency_records",
        where: r.user_id == ^user_id and r.key == ^key,
        select: %{method: r.method, path: r.path, status: r.status, response_body: r.response_body}
    )
  end

  # Same key reused for another request: refuse rather than return an unrelated response.
  defp replay(conn, %{method: method, path: path} = record) do
    if method == conn.method and path == conn.request_path do
      conn
      |> put_resp_content_type("application/json")
      |> put_resp_header("idempotent-replay", "true")
      |> send_resp(record.status, record.response_body || "")
      |> halt()
    else
      conn
      |> put_status(:unprocessable_entity)
      |> Phoenix.Controller.json(%{error: "Idempotency key already used for another request"})
      |> halt()
    end
  end

  defp store_on_send(conn, user_id, key) do
    register_before_send(conn, fn conn ->
      # Server errors are not stored, so the client can retry them.
      if conn.status < 500 do
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        Repo.insert_all(
          "idempotency_records",
          [
            %{
              user_id: user_id,
              key: key,
              method: conn.method,
              path: conn.request_path,
              status: conn.status,
              response_body: IO.iodata_to_binary(conn.resp_body || ""),
              inserted_at: now
            }
          ],
          # Two concurrent requests with the same key: the first one stored wins.
          on_conflict: :nothing,
          conflict_target: [:user_id, :key]
        )
      end

      conn
    end)
  end
end
