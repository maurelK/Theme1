defmodule Theme1.Scope do
  @moduledoc """
  Central authorization helpers shared across controllers.

  Two concepts:
    * `manager_covers?/2` — does this manager share a team with this user?
    * `manages_or_owns?/2` — same as above, or the manager is the user (managers
      can also log/manage their own time).

  Only callers with the `manager` role use these. `administrator` and
  `hr_payroll` bypass scope checks by design — they operate org-wide.
  """

  import Ecto.Query
  alias Theme1.{Repo, TeamMembership}

  @doc """
  Returns true if the given manager shares at least one team with the target
  user. Returns false if the manager has no teams.
  """
  def manager_covers?(manager, target_user_id) do
    manager_team_ids = team_ids_for(manager.id)

    manager_team_ids != [] and
      Repo.exists?(
        from m in TeamMembership,
          where: m.user_id == ^target_user_id and m.team_id in ^manager_team_ids
      )
  end

  @doc """
  True if the manager covers the target OR is the target themselves.
  """
  def manages_or_owns?(%{id: manager_id} = manager, target_user_id) do
    manager_id == target_user_id or manager_covers?(manager, target_user_id)
  end

  defp team_ids_for(user_id) do
    Repo.all(
      from m in TeamMembership,
        where: m.user_id == ^user_id,
        select: m.team_id
    )
  end
end