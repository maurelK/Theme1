defmodule Theme1.Repo.Migrations.CreateTeamsAndMemberships do
  use Ecto.Migration

  def change do
    # Teams are independent groups that can contain many users.
    create table(:teams) do
      add :name, :string, null: false
      timestamps()
    end

    create unique_index(:teams, [:name])

    # The join table allows employees to belong to multiple teams.
    create table(:team_memberships, primary_key: false) do
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      timestamps(updated_at: false)
    end

    create unique_index(:team_memberships, [:team_id, :user_id])
    create index(:team_memberships, [:user_id])

  end
end
