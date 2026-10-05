defmodule Theme1.Auth do
  import Ecto.Query

  alias Theme1.{Repo, Role, User}
  alias Theme1.PasswordResetToken

  # Authenticate credentials and return only a safe user projection plus JWT data.
  def authenticate(email, password) when is_binary(email) and is_binary(password) do
    case Repo.get_by(User, email: email) |> Repo.preload(:role) do
      %User{} = user ->
        if User.valid_password?(user, password) do
          csrf_token = random_token()

          with {:ok, jwt, _claims} <- sign_token(user, csrf_token) do
            {:ok, %{user: public_user(user), jwt: jwt, csrf_token: csrf_token}}
          end
        else
          {:error, :invalid_credentials}
        end

      nil ->
        {:error, :invalid_credentials}
    end
  end

  def authenticate(_email, _password), do: {:error, :invalid_credentials}

  # Register new users as employees until an administrator changes their role.
  def register_user(attrs) when is_map(attrs) do
    with %Role{id: role_id} <- Repo.get_by(Role, name: "employee"),
         changeset <- User.registration_changeset(%User{}, attrs) |> Ecto.Changeset.put_change(:role_id, role_id),
         {:ok, user} <- Repo.insert(changeset) do
      {:ok, Repo.preload(user, :role)}
    else
      nil -> {:error, :employee_role_missing}
      {:error, changeset} -> {:error, changeset}
    end
  end

  # Require the existing password before replacing the stored password hash.
  def change_password(%User{} = user, current_password, new_password)
      when is_binary(current_password) and is_binary(new_password) do
    if User.valid_password?(user, current_password) do
      user
      |> User.password_changeset(%{password: new_password})
      |> Repo.update()
    else
      {:error, :invalid_credentials}
    end
  end

  def change_password(_user, _current_password, _new_password), do: {:error, :invalid_credentials}

  # Create a short-lived reset credential without revealing whether the email exists.
  def request_password_reset(email) when is_binary(email) do
    case Repo.get_by(User, email: email) do
      %User{} = user ->
        token = random_token()
        expires_at = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(3_600, :second)

        %PasswordResetToken{}
        |> Ecto.Changeset.change(%{
          user_id: user.id,
          token_digest: digest_token(token),
          expires_at: expires_at
        })
        |> Repo.insert()
        |> case do
          {:ok, _reset} ->
            deliver_reset_email(user.email, token)
            {:ok, token}
          error -> error
        end

      nil -> {:ok, nil}
    end
  end

  def request_password_reset(_email), do: {:ok, nil}

  # Consume a valid reset credential exactly once and replace the password hash.
  def reset_password(token, new_password) when is_binary(token) and is_binary(new_password) do
    # Match the database precision so tokens remain valid and single-use.
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    query =
      from reset in PasswordResetToken,
        where: reset.token_digest == ^digest_token(token),
        where: is_nil(reset.used_at) and reset.expires_at > ^now,
        preload: [:user]

    case Repo.one(query) do
      %PasswordResetToken{} = reset ->
        Ecto.Multi.new()
        |> Ecto.Multi.update(:user, User.password_changeset(reset.user, %{password: new_password}))
        |> Ecto.Multi.update(:token, Ecto.Changeset.change(reset, used_at: now))
        |> Repo.transaction()
        |> case do
          {:ok, _changes} -> :ok
          {:error, _step, changeset, _changes} -> {:error, changeset}
        end

      nil -> {:error, :invalid_or_expired_token}
    end
  end

  def reset_password(_token, _new_password), do: {:error, :invalid_or_expired_token}

  # Verify the signed cookie token before any protected route uses its claims.
  def verify_token(token) when is_binary(token) do
    signer = Joken.Signer.create("HS256", jwt_secret())

    with {:ok, claims} <- Joken.verify(token, signer),
         true <- valid_expiration?(claims),
          %User{} = user <- Repo.get(User, claims["user_id"]) |> Repo.preload(:role) do
      {:ok, user, claims}
    else
      _ -> {:error, :invalid_token}
    end
  end

  def verify_token(_token), do: {:error, :invalid_token}

  # Recover the non-secret CSRF value after a page refresh without exposing the JWT.
  def csrf_token_from_jwt(token) when is_binary(token) do
    signer = Joken.Signer.create("HS256", jwt_secret())

    with {:ok, claims} <- Joken.verify(token, signer),
         true <- valid_expiration?(claims),
         csrf_token when is_binary(csrf_token) <- claims["csrf_token"] do
      {:ok, csrf_token}
    else
      _ -> {:error, :invalid_token}
    end
  end

  def csrf_token_from_jwt(_token), do: {:error, :invalid_token}

  def public_user(%User{} = user) do
    %{
      id: user.id,
      username: user.username,
      email: user.email,
      role: if(user.role, do: user.role.name, else: nil)
    }
  end

  defp sign_token(%User{id: user_id, role: role}, csrf_token) do
    claims = %{
      "user_id" => user_id,
      "role" => role.name,
      "csrf_token" => csrf_token,
      "exp" => DateTime.to_unix(DateTime.utc_now()) + 86_400
    }

    Joken.encode_and_sign(claims, Joken.Signer.create("HS256", jwt_secret()))
  end

  defp valid_expiration?(%{"exp" => expiration}) when is_integer(expiration) do
    expiration > DateTime.to_unix(DateTime.utc_now())
  end

  defp valid_expiration?(_claims), do: false

  defp jwt_secret do
    Application.get_env(:theme1, :auth_jwt_secret) ||
      System.get_env("AUTH_JWT_SECRET") ||
      raise "AUTH_JWT_SECRET is not configured"
  end

  defp random_token do
    32
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp digest_token(token) do
    :sha256
    |> :crypto.hash(token)
    |> Base.encode16(case: :lower)
  end

  # Deliver the reset link through the configured mail adapter without exposing the token in production.
  defp deliver_reset_email(email, token) do
    reset_base_url = Application.get_env(:theme1, :public_app_url) || System.get_env("PUBLIC_APP_URL", "http://localhost:5173")
    reset_url = "#{reset_base_url}/reset-password?token=#{URI.encode_www_form(token)}"

    Swoosh.Email.new()
    |> Swoosh.Email.to(email)
    |> Swoosh.Email.from(System.get_env("MAILER_FROM", "no-reply@timemanager.local"))
    |> Swoosh.Email.subject("Reset your Time Manager password")
    |> Swoosh.Email.text_body("Use this link within one hour to reset your password: #{reset_url}")
    |> Theme1.Mailer.deliver()
  rescue
    error ->
      require Logger
      Logger.error("Password reset email delivery failed: #{Exception.message(error)}")
      :ok
  end
end
