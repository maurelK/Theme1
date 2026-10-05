# This script is intentionally driven by runtime variables so admin credentials never enter Git.
alias Theme1.{Repo, Role, User}

admin_email = System.get_env("ADMIN_EMAIL")
admin_password = System.get_env("ADMIN_PASSWORD")

if is_binary(admin_email) and is_binary(admin_password) do
	# Provision one administrator idempotently when deployment supplies bootstrap credentials.
	administrator = Repo.get_by!(Role, name: "administrator")

	case Repo.get_by(User, email: admin_email) do
		nil ->
			%User{}
			|> User.registration_changeset(%{
				username: "Administrator",
				email: admin_email,
				password: admin_password
			})
			|> Ecto.Changeset.put_change(:role_id, administrator.id)
			|> Repo.insert!()

		user ->
			# Preserve an existing account while ensuring the bootstrap account keeps admin access.
			user
			|> Ecto.Changeset.change(role_id: administrator.id)
			|> Repo.update!()
	end

	IO.puts("Administrator bootstrap account is ready.")
else
	IO.puts("ADMIN_EMAIL and ADMIN_PASSWORD are not set; administrator bootstrap was skipped.")
end
