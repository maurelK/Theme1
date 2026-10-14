defmodule Theme1Web.Cors do
  @allowed_origins [
    "http://localhost",
    "http://localhost:5173",
    "http://127.0.0.1:5173"
  ]

  def init(opts), do: opts

  def call(%Plug.Conn{method: "OPTIONS"} = conn, _opts) do
    conn
    |> put_cors_headers()
    |> Plug.Conn.send_resp(204, "")
    |> Plug.Conn.halt()
  end

  def call(conn, _opts), do: put_cors_headers(conn)

  defp put_cors_headers(conn) do
    case Plug.Conn.get_req_header(conn, "origin") do
      [origin | _] when origin in @allowed_origins ->
        conn
        |> Plug.Conn.put_resp_header("access-control-allow-origin", origin)
        |> Plug.Conn.put_resp_header("access-control-allow-credentials", "true")
        |> Plug.Conn.put_resp_header("access-control-allow-headers", "content-type, x-csrf-token, authorization, idempotency-key")
        |> Plug.Conn.put_resp_header("access-control-allow-methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
        |> Plug.Conn.put_resp_header("vary", "Origin")

      _ ->
        conn
    end
  end
end
