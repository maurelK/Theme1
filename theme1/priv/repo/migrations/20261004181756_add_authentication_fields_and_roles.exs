defmodule Theme1.Repo.Migrations.AddAuthenticationFieldsAndRoles do
  use Ecto.Migration

  def change do
    # Store predefined roles separately so permissions are data-driven and auditable.
    create table(:roles) do
      add :name, :string, null: false
      timestamps()
    end

    create unique_index(:roles, [:name])

    # Keep password storage nullable during rollout so existing users remain migratable.
    alter table(:users) do
      add :password_hash, :string
      add :role_id, references(:roles, on_delete: :restrict)
    end

    # Seed the fixed role catalog required by the authentication and authorization layers.
    execute """
    INSERT INTO roles (name, inserted_at, updated_at)
    VALUES
      ('employee', NOW(), NOW()),
      ('manager', NOW(), NOW()),
      ('hr_payroll', NOW(), NOW()),
      ('administrator', NOW(), NOW())
    """

    # Preserve current users by assigning them the least-privileged default role.
    execute """
    UPDATE users
    SET role_id = (SELECT id FROM roles WHERE name = 'employee')
    WHERE role_id IS NULL
    """

  end
end
