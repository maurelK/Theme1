defmodule Theme1.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :username, :string
    field :email, :string
    field :password_hash, :string
    field :password, :string, virtual: true, redact: true

    # Shift configuration. timezone_offset_minutes is a fixed UTC offset
    # (e.g. +60 for CET, +120 for CEST). shift_*_minutes are minutes from
    # local midnight (e.g. 540 = 09:00, 1020 = 17:00).
    field :timezone_offset_minutes, :integer, default: 0
    field :shift_start_minutes, :integer
    field :shift_end_minutes, :integer

    has_many :clocks, Theme1.Clock
    has_many :workingtimes, Theme1.WorkingTime
    belongs_to :role, Theme1.Role
    many_to_many :teams, Theme1.Team, join_through: "team_memberships"
  end

  # Rule set enforced on every path that creates or changes a password:
  # registration, password reset, password change, and invitation acceptance.
  @password_min_length 10
  @password_max_length 72

  # Small list of the most common passwords. Blocklist is case-insensitive.
  @password_blocklist ~w(
    password password1 password123 passw0rd 12345678 123456789 1234567890
    qwerty qwerty123 abc123 letmein welcome admin administrator
    iloveyou monkey dragon sunshine princess football baseball
    changeme changeme123 passw0rd! p@ssw0rd p@ssword
  )

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email])
    |> validate_required([:username, :email])
    |> validate_format(:email, ~r/^[^@\s]+@[^@\s]+\.[^@\s]+$/)
    |> unique_constraint(:email)
  end

  # Admin-only: assign timezone and personal shift for a user.
  def shift_changeset(user, attrs) do
    user
    |> cast(attrs, [:timezone_offset_minutes, :shift_start_minutes, :shift_end_minutes])
    |> validate_number(:timezone_offset_minutes, greater_than_or_equal_to: -720, less_than_or_equal_to: 840)
    |> validate_number(:shift_start_minutes, greater_than_or_equal_to: 0, less_than_or_equal_to: 1439)
    |> validate_number(:shift_end_minutes, greater_than_or_equal_to: 0, less_than_or_equal_to: 1439)
    |> validate_shift_order()
  end

  defp validate_shift_order(changeset) do
    start_m = get_field(changeset, :shift_start_minutes)
    end_m = get_field(changeset, :shift_end_minutes)

    if is_integer(start_m) and is_integer(end_m) and end_m <= start_m do
      add_error(changeset, :shift_end_minutes, "must be after the shift start time")
    else
      changeset
    end
  end

  # Password changes reuse the same rules without allowing profile fields through.
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_password_strength()
    |> put_password_hash()
  end

  # Login verifies the supplied password against the stored PBKDF2 hash.
  def valid_password?(%__MODULE__{password_hash: password_hash}, password)
      when is_binary(password_hash) and is_binary(password) do
    Pbkdf2.verify_pass(password, password_hash)
  end

  def valid_password?(_, _password), do: false

  # Expose rules so the frontend can mirror them in the checklist UI.
  def password_rules do
    %{
      min_length: @password_min_length,
      max_length: @password_max_length,
      requires_lowercase: true,
      requires_uppercase: true,
      requires_digit: true,
      requires_symbol: true,
      blocklist_size: length(@password_blocklist)
    }
  end

  defp validate_password_strength(changeset) do
    case get_change(changeset, :password) do
      password when is_binary(password) ->
        changeset
        |> validate_required([:password])
        |> validate_length(:password,
          min: @password_min_length,
          max: @password_max_length,
          message: "must be at least #{@password_min_length} characters"
        )
        |> validate_format(:password, ~r/[a-z]/,
          message: "must include a lowercase letter"
        )
        |> validate_format(:password, ~r/[A-Z]/,
          message: "must include an uppercase letter"
        )
        |> validate_format(:password, ~r/[0-9]/,
          message: "must include a number"
        )
        |> validate_format(:password, ~r/[^A-Za-z0-9]/,
          message: "must include a symbol"
        )
        |> validate_not_blocklisted()

      _ ->
        changeset
        |> add_error(:password, "can't be blank")
    end
  end

  defp validate_not_blocklisted(changeset) do
    case get_change(changeset, :password) do
      password when is_binary(password) ->
        normalized = String.downcase(password)

        if normalized in @password_blocklist do
          add_error(changeset, :password, "is too common, choose a different password")
        else
          changeset
        end

      _ ->
        changeset
    end
  end

  defp put_password_hash(changeset) do
    case get_change(changeset, :password) do
      password when is_binary(password) ->
        changeset
        |> put_change(:password_hash, Pbkdf2.hash_pwd_salt(password))
        |> delete_change(:password)

      _ ->
        changeset
    end
  end
end