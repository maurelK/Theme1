defmodule Theme1Web.AuthPlug do
  import Plug.Conn

  alias Theme1.Auth

  @auth_cookie "theme1_auth"

  # Allow Phoenix to initialize this plug when it builds the router pipeline.
  def init(opts), do: opts

  # Authenticate every protected API request from the HttpOnly JWT cookie.
  def call(conn, _opts) do
    conn
    |> fetch_cookies()
    |> authenticate_cookie()
  end

  defp authenticate_cookie(%Plug.Conn{cookies: %{@auth_cookie => token}} = conn) do
    case Auth.verify_token(token) do
      {:ok, user, claims} -> validate_csrf(conn, user, claims)
      {:error, _reason} -> unauthorized(conn, "Invalid or expired authentication")
    end
  end

  defp authenticate_cookie(conn), do: unauthorized(conn, "Authentication required")

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
