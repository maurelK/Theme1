defmodule Theme1Web.AuthController do
  use Theme1Web, :controller

  alias Theme1.Auth

  # Issue an HttpOnly JWT cookie and return only the CSRF token to the browser.
  def login(conn, %{"email" => email, "password" => password}) do
    case Auth.authenticate(email, password) do
      {:ok, %{user: user, jwt: jwt, csrf_token: csrf_token}} ->
        conn
        |> put_auth_cookie(jwt)
        |> json(%{user: user, csrf_token: csrf_token})

      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid email or password"})
    end
  end

  def login(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "Email and password are required"})
  end

  # Always return the same response so callers cannot enumerate registered emails.
  def request_password_reset(conn, %{"email" => email}) do
    {:ok, token} = Auth.request_password_reset(email)

    response = %{message: "If the account exists, reset instructions will be sent."}

    response =
      if System.get_env("MIX_ENV") != "prod" do
        Map.put(response, :development_reset_token, token)
      else
        response
      end

    json(conn, response)
  end

  def request_password_reset(conn, _params) do
    json(conn, %{message: "If the account exists, reset instructions will be sent."})
  end

  # Consume a reset token and never return the new password or its hash.
  def reset_password(conn, %{"token" => token, "new_password" => new_password}) do
    case Auth.reset_password(token, new_password) do
      :ok -> json(conn, %{ok: true})
      {:error, :invalid_or_expired_token} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Invalid or expired reset token"})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)})
    end
  end

  def reset_password(conn, _params), do: conn |> put_status(:unprocessable_entity) |> json(%{error: "Reset token and new password are required"})

  # Consume an invitation token and set the initial password for an invited user.
  def accept_invitation(conn, %{"token" => token, "new_password" => new_password}) do
    case Auth.accept_invitation(token, new_password) do
      :ok ->
        json(conn, %{ok: true})

      {:error, :invalid_or_expired_token} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Invalid or expired invitation token"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)})
    end
  end

  def accept_invitation(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "Invitation token and new password are required"})
  end
  
  # Remove the browser authentication cookie without returning token material.
  def logout(conn, _params) do
    conn
    |> delete_resp_cookie("theme1_auth", cookie_options())
    |> json(%{ok: true})
  end

    # Report the caller's CSRF state. Anonymous visitors receive a null token
  # instead of a 401 so the frontend can bootstrap without treating this as an error.
  def csrf(conn, _params) do
    conn = fetch_cookies(conn)

    case conn.cookies["theme1_auth"] && Auth.csrf_token_from_jwt(conn.cookies["theme1_auth"]) do
      {:ok, csrf_token} -> json(conn, %{csrf_token: csrf_token})
      _ -> json(conn, %{csrf_token: nil})
    end
  end

  # Return the authenticated session so the Vue app can restore state after refresh.
  def session(conn, _params) do
    json(conn, %{user: Auth.public_user(conn.assigns.current_user)})
  end

  # Change the authenticated user password without exposing password material in responses.
  def change_password(conn, %{"current_password" => current_password, "new_password" => new_password}) do
    case Auth.change_password(conn.assigns.current_user, current_password, new_password) do
      {:ok, _user} -> json(conn, %{ok: true})
      {:error, :invalid_credentials} -> conn |> put_status(:unauthorized) |> json(%{error: "Current password is invalid"})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)})
    end
  end

  def change_password(conn, _params) do
    conn |> put_status(:unprocessable_entity) |> json(%{error: "Current and new passwords are required"})
  end

  defp put_auth_cookie(conn, jwt) do
    put_resp_cookie(conn, "theme1_auth", jwt, cookie_options())
  end

    defp cookie_options do
    [
      http_only: true,
      # TEMPORARY: secure is env-gated so the app works over plain HTTP on the
      # current IP-only Oracle deployment. Set COOKIE_SECURE=true once HTTPS is live.
      secure: System.get_env("COOKIE_SECURE") == "true",
      same_site: "Lax",
      max_age: 86_400,
      path: "/"
    ]
  end
end
