defmodule Theme1Web.AuthPlug do
  import Plug.Conn

  alias Theme1.Auth

  @auth_cookie "theme1_auth"

  # Allow Phoenix to initialize this plug when it builds the router pipeline.
  def init(opts), do: opts

  # Authenticate every protected API request from the HttpOnly JWT cookie (web)
  # or the Authorization bearer header (mobile app, where cross-site cookies are not sent).
  def call(conn, _opts) do
    conn = fetch_cookies(conn)

    case token_with_source(conn) do
      nil -> unauthorized(conn, "Authentication required")
      {token, source} -> authenticate_token(conn, token, source)
    end
  end

  def token_from_conn(conn) do
    case token_with_source(conn) do
      {token, _source} -> token
      nil -> nil
    end
  end

  # The cookie wins when both are present, so the web flow is unchanged.
  defp token_with_source(conn) do
    case conn.cookies[@auth_cookie] do
      token when is_binary(token) -> {token, :cookie}
      _ -> if token = bearer_token(conn), do: {token, :bearer}
    end
  end

  defp bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token | _] when token != "" -> token
      _ -> nil
    end
  end

  # CSRF only threatens credentials the browser sends by itself (the cookie). A
  # bearer header is always added explicitly by the app, so it needs no CSRF check.
  defp authenticate_token(conn, token, source) do
    case Auth.verify_token(token) do
      {:ok, user, _claims} when source == :bearer -> assign(conn, :current_user, user)
      {:ok, user, claims} -> validate_csrf(conn, user, claims)
      {:error, _reason} -> unauthorized(conn, "Invalid or expired authentication")
    end
  end

  # Bind the request header to the CSRF claim carried by the signed JWT.
  defp validate_csrf(conn, user, %{"csrf_token" => expected_token}) do
    [provided_token | _] = get_req_header(conn, "x-csrf-token") ++ [""]

    if secure_equal?(provided_token, expected_token) do
      assign(conn, :current_user, user)
    else
      unauthorized(conn, "Invalid CSRF token")
    end
  end

  defp validate_csrf(conn, _user, _claims), do: unauthorized(conn, "Invalid CSRF token")

  defp secure_equal?(left, right)
       when is_binary(left) and is_binary(right) and byte_size(left) == byte_size(right) do
    Plug.Crypto.secure_compare(left, right)
  end

  defp secure_equal?(_left, _right), do: false

  defp unauthorized(conn, message) do
    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{error: message})
    |> halt()
  end
end
