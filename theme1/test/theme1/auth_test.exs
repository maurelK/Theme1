defmodule Theme1.AuthTest do
  use ExUnit.Case, async: false

  alias Theme1.{Auth, Repo, Role, User}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  # Test-only helper: create a confirmed user with a password directly.
  # Production code no longer exposes public registration; users are created
  # via the admin-only invitation flow and accept their invite to set a password.
  defp create_user_with_password(attrs) do
    role = Repo.get_by!(Role, name: "employee")

    %User{}
    |> User.changeset(%{
      "username" => attrs["username"],
      "email" => attrs["email"]
    })
    |> Ecto.Changeset.put_change(:role_id, role.id)
    |> Repo.insert!()
    |> then(fn user ->
      user
      |> User.password_changeset(%{"password" => attrs["password"]})
      |> Repo.update!()
    end)
  end

  test "authenticates a user without exposing the password" do
    email = "auth-test-#{System.unique_integer([:positive])}@example.com"

    user = create_user_with_password(%{
      "username" => "Auth Test",
      "email" => email,
      "password" => "Correct-Password-123!"
    })

    assert is_binary(user.password_hash)
    assert user.password == nil
    assert {:ok, session} = Auth.authenticate(email, "Correct-Password-123!")
    assert session.user.email == email
    assert is_binary(session.jwt)
    assert is_binary(session.csrf_token)
    assert {:error, :invalid_credentials} = Auth.authenticate(email, "Wrong-Password-456!")
  end

  test "password reset tokens are single-use" do
    email = "reset-test-#{System.unique_integer([:positive])}@example.com"

    assert %Role{} = Repo.get_by!(Role, name: "employee")
    _user = create_user_with_password(%{
      "username" => "Reset Test",
      "email" => email,
      "password" => "Old-Password-123!"
    })

    assert {:ok, token} = Auth.request_password_reset(email)
    assert :ok = Auth.reset_password(token, "New-Password-456!")
    assert {:error, :invalid_or_expired_token} = Auth.reset_password(token, "Another-Password-789!")
    assert {:ok, _session} = Auth.authenticate(email, "New-Password-456!")
  end
end