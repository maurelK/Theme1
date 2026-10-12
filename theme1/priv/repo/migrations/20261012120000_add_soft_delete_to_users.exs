defmodule Theme1.Repo.Migrations.AddSoftDeleteToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :deleted_at, :utc_datetime
    end

    # Support efficient filtering.
    create index(:users, [:deleted_at])

    # Replace the plain unique email index with a partial unique index that
    # only enforces uniqueness for non-deleted users. This frees up the email
    # for reuse after someone deletes their account.
    drop_if_exists unique_index(:users, [:email], name: :users_email_index)

    create unique_index(:users, [:email],
             where: "deleted_at IS NULL",
             name: :users_email_active_index
           )
  end
end