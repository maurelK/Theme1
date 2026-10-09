alias Theme1.{Repo, Role, Team, TeamMembership, User}

# Helper: create a user with a password and a role.
defmodule ScopeSeed do
  def create_user(username, email, password, role_name) do
    role = Theme1.Repo.get_by!(Theme1.Role, name: role_name)

    user =
      %Theme1.User{}
      |> Theme1.User.changeset(%{username: username, email: email})
      |> Ecto.Changeset.put_change(:role_id, role.id)
      |> Theme1.Repo.insert!()

    user
    |> Theme1.User.password_changeset(%{password: password})
    |> Theme1.Repo.update!()
  end
end

suffix = System.unique_integer([:positive])

manager =
  ScopeSeed.create_user(
    "Scope Manager #{suffix}",
    "scope-manager-#{suffix}@example.com",
    "Manager-Pass-123!",
    "manager"
  )

team_member =
  ScopeSeed.create_user(
    "Scope TeamMember #{suffix}",
    "scope-member-#{suffix}@example.com",
    "Member-Pass-123!",
    "employee"
  )

outsider =
  ScopeSeed.create_user(
    "Scope Outsider #{suffix}",
    "scope-outsider-#{suffix}@example.com",
    "Outsider-Pass-123!",
    "employee"
  )

team =
  %Team{}
  |> Team.changeset(%{name: "Scope Team #{suffix}"})
  |> Repo.insert!()

# Add manager and team_member to the team; leave outsider OUT.
for user <- [manager, team_member] do
  %TeamMembership{}
  |> Ecto.Changeset.change(%{team_id: team.id, user_id: user.id})
  |> Repo.insert!()
end

IO.puts("===== SCOPE TEST SEED =====")
IO.puts("manager_email=scope-manager-#{suffix}@example.com")
IO.puts("manager_password=Manager-Pass-123!")
IO.puts("manager_id=#{manager.id}")
IO.puts("team_member_email=scope-member-#{suffix}@example.com")
IO.puts("team_member_id=#{team_member.id}")
IO.puts("outsider_email=scope-outsider-#{suffix}@example.com")
IO.puts("outsider_id=#{outsider.id}")
IO.puts("team_id=#{team.id}")
IO.puts("===========================")