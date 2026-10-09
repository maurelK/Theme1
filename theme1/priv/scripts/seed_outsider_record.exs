alias Theme1.{Repo, WorkingTime}

{:ok, wt} =
  %WorkingTime{}
  |> Ecto.Changeset.change(%{
    user_id: 8,
    start: ~U[2026-10-12 09:00:00Z],
    end: ~U[2026-10-12 17:00:00Z],
    source: "manual"
  })
  |> Repo.insert()

IO.puts("outsider record id = #{wt.id}")