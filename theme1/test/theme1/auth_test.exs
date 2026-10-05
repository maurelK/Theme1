defmodule Theme1.AuthTest do
  use ExUnit.Case, async: false

  alias Theme1.{Auth, Repo, Role}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "registers and authenticates a user without exposing the password" do
    email = "auth-test-#{System.unique_integer([:positive])}@example.com"

    assert {:ok, user} = Auth.register_user(%{
             "username" => "Auth Test",
             "email" => email,
             "password" => "correct-password-123"
           })

    assert is_binary(user.password_hash)
    assert user.password == nil
    assert {:ok, session} = Auth.authenticate(email, "correct-password-123")
    assert session.user.email == email
    assert is_binary(session.jwt)
    assert is_binary(session.csrf_token)
    assert {:error, :invalid_credentials} = Auth.authenticate(email, "wrong-password")
  end

  test "password reset tokens are single-use" do
    email = "reset-test-#{System.unique_integer([:positive])}@example.com"

    assert %Role{} = Repo.get_by!(Role, name: "employee")
    assert {:ok, _user} = Auth.register_user(%{
             "username" => "Reset Test",
             "email" => email,
             "password" => "old-password-123"
           })

    assert {:ok, token} = Auth.request_password_reset(email)
    assert :ok = Auth.reset_password(token, "new-password-123")
    assert {:error, :invalid_or_expired_token} = Auth.reset_password(token, "another-password-123")
    assert {:ok, _session} = Auth.authenticate(email, "new-password-123")
  end
end
