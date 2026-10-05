defmodule Theme1.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :username, :string
    field :email, :string
    field :password_hash, :string
    field :password, :string, virtual: true, redact: true

    has_many :clocks, Theme1.Clock
    has_many :workingtimes, Theme1.WorkingTime
    belongs_to :role, Theme1.Role
    many_to_many :teams, Theme1.Team, join_through: "team_memberships"
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email])
    |> validate_required([:username, :email])
    |> validate_format(:email, ~r/^[^@\s]+@[^@\s]+\.[^@\s]+$/)
    |> unique_constraint(:email)
  end

  # Registration hashes passwords before persistence and never stores plaintext credentials.
  def registration_changeset(user, attrs) do
    user
    |> changeset(attrs)
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 8)
    |> put_password_hash()
  end

  # Password changes reuse the same hashing path without allowing profile fields through.
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 8)
    |> put_password_hash()
  end

  # Login verifies the supplied password against the stored PBKDF2 hash.
  def valid_password?(%__MODULE__{password_hash: password_hash}, password)
      when is_binary(password_hash) and is_binary(password) do
    Pbkdf2.verify_pass(password, password_hash)
  end

  def valid_password?(_, _password), do: false

  defp put_password_hash(changeset) do
    case get_change(changeset, :password) do
      password when is_binary(password) ->
        changeset
        |> put_change(:password_hash, Pbkdf2.hash_pwd_salt(password))
        |> delete_change(:password)
      _ -> changeset
    end
  end
end