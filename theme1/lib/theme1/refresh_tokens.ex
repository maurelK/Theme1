defmodule Theme1.RefreshTokens do
  @moduledoc """
  Revocable refresh tokens for the mobile app (see ADR on offline sessions).

  * Random 256-bit value given to the client once; only its SHA-256 is stored.
  * Valid 7 days, which is also the maximum offline period on the phone.
  * Rotated on every use: the old token is revoked and a new one is returned.
  * Reuse of a revoked token means it was copied: every token of that user is
    revoked, forcing a new sign-in on all devices.
  """

  import Ecto.Query

  alias Theme1.{RefreshToken, Repo, User}

  @ttl_seconds 7 * 24 * 3600

  def ttl_seconds, do: @ttl_seconds

  @doc "Create a refresh token for `user`. Returns the raw token to send to the client."
  def issue(%User{id: user_id}) do
    raw = 32 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

    %RefreshToken{}
    |> Ecto.Changeset.change(%{
      user_id: user_id,
      token_digest: digest(raw),
      expires_at: DateTime.add(now(), @ttl_seconds, :second)
    })
    |> Repo.insert!()

    raw
  end

  @doc """
  Exchange a refresh token for a new one.
  Returns `{:ok, user, new_raw_token}` or `{:error, :invalid}`.
  """
  def rotate(raw) when is_binary(raw) do
    Repo.transaction(fn ->
      record =
        Repo.one(
          from t in RefreshToken,
            where: t.token_digest == ^digest(raw),
            lock: "FOR UPDATE",
            preload: [user: :role]
        )

      cond do
        is_nil(record) ->
          Repo.rollback(:invalid)

        not is_nil(record.revoked_at) ->
          # A rotated or revoked token is being replayed: assume it was stolen.
          # Revoked after the rollback, otherwise the rollback would undo it.
          Repo.rollback({:reused, record.user_id})

        DateTime.compare(record.expires_at, now()) != :gt or User.deleted?(record.user) ->
          Repo.rollback(:invalid)

        true ->
          record |> Ecto.Changeset.change(revoked_at: now()) |> Repo.update!()
          {record.user, issue(record.user)}
      end
    end)
    |> case do
      {:ok, {user, new_raw}} ->
        {:ok, user, new_raw}

      {:error, {:reused, user_id}} ->
        revoke_all_for(user_id)
        {:error, :invalid}

      {:error, _reason} ->
        {:error, :invalid}
    end
  end

  def rotate(_raw), do: {:error, :invalid}

  @doc "Revoke one token (sign-out on this device). Unknown tokens are ignored."
  def revoke(raw) when is_binary(raw) do
    from(t in RefreshToken, where: t.token_digest == ^digest(raw) and is_nil(t.revoked_at))
    |> Repo.update_all(set: [revoked_at: now()])

    :ok
  end

  def revoke(_raw), do: :ok

  @doc "Revoke every token of a user: password change, account deletion, suspected theft."
  def revoke_all_for(user_id) do
    from(t in RefreshToken, where: t.user_id == ^user_id and is_nil(t.revoked_at))
    |> Repo.update_all(set: [revoked_at: now()])

    :ok
  end

  defp digest(raw), do: :sha256 |> :crypto.hash(raw) |> Base.encode16(case: :lower)

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
