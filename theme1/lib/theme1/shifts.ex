defmodule Theme1.Shifts do
  @moduledoc """
  Resolves the effective shift for a user and computes shift-related times.

  Resolution priority (highest to lowest):
    1. The user's personal shift (both start and end minutes set)
    2. The first team the user belongs to that has both minutes set
    3. The global default from `config :theme1, :default_shift`

  Shift times are expressed as minutes from local midnight (540 = 09:00,
  1020 = 17:00) with a fixed UTC offset (`timezone_offset_minutes`).
  """

  alias Theme1.Repo
  alias Theme1.User

  @default_shift %{start_minutes: 540, end_minutes: 1020, tz_offset_minutes: 0}

  @doc """
  Returns `%{start_minutes: int, end_minutes: int, tz_offset_minutes: int, source: atom}`
  describing the effective shift for `user`.

  `source` is `:user`, `:team`, or `:default`.
  """
  def effective_shift(%User{} = user) do
    user = Repo.preload(user, :teams)

    cond do
      user_shift?(user) ->
        %{
          start_minutes: user.shift_start_minutes,
          end_minutes: user.shift_end_minutes,
          tz_offset_minutes: user.timezone_offset_minutes || 0,
          source: :user
        }

      team_shift = find_team_shift(user.teams) ->
        team_shift

      true ->
        config_default()
    end
  end

  @doc """
  Given a session start datetime and the effective shift, returns the
  UTC datetime at which the shift ends on the same local day as `start_dt`.

  If the session starts *after* shift end (e.g. someone clocks in at 19:00
  with a 09:00-17:00 shift), the shift-end is treated as belonging to the
  *next* local day boundary — the caller decides how to handle it.
  """
  def shift_end_for(%{start_minutes: _s, end_minutes: end_m, tz_offset_minutes: tz}, %DateTime{} = start_dt) do
    # Convert the start datetime to the user's local time to determine the
    # local day, then compute midnight-local, add end_minutes, convert back to UTC.
    local_dt = DateTime.add(start_dt, tz * 60, :second)
    {:ok, midnight_local} = DateTime.new(Date.from_iso8601!(Date.to_iso8601(DateTime.to_date(local_dt))), ~T[00:00:00], "Etc/UTC")

    # midnight_local is a UTC datetime representing local midnight (because
    # DateTime.new with "Etc/UTC" strips the offset). Add the shift end minutes,
    # then subtract the tz offset to convert back to real UTC.
    shift_end_local = DateTime.add(midnight_local, end_m * 60, :second)
    shift_end_utc = DateTime.add(shift_end_local, -tz * 60, :second)

    # Overnight shifts are not supported. If the computed shift end is before
    # the session start, the caller will treat the record as fully overtime.
    shift_end_utc
  end

  @doc """
  Returns the default global shift as configured.
  """
  def default_shift, do: config_default()

  ## Internals

  defp user_shift?(%User{} = user) do
    is_integer(user.shift_start_minutes) and is_integer(user.shift_end_minutes)
  end

  defp find_team_shift(teams) when is_list(teams) do
    teams
    |> Enum.filter(fn t ->
      is_integer(t.shift_start_minutes) and is_integer(t.shift_end_minutes)
    end)
    |> Enum.sort_by(& &1.shift_start_minutes)
    |> case do
      [] ->
        nil

      [team | _] ->
        %{
          start_minutes: team.shift_start_minutes,
          end_minutes: team.shift_end_minutes,
          tz_offset_minutes: team.timezone_offset_minutes || 0,
          source: :team
        }
    end
  end

  defp find_team_shift(_), do: nil

  defp config_default do
    case Application.get_env(:theme1, :default_shift) do
      %{start_minutes: s, end_minutes: e} = cfg ->
        %{
          start_minutes: s,
          end_minutes: e,
          tz_offset_minutes: Map.get(cfg, :tz_offset_minutes, 0),
          source: :default
        }

      _ ->
        Map.put(@default_shift, :source, :default)
    end
  end
end