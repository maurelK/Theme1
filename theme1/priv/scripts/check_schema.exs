import Ecto.Query

{:ok, %{rows: rows}} = Theme1.Repo.query(
  "SELECT column_name, is_nullable FROM information_schema.columns WHERE table_name = 'workingtimes' ORDER BY ordinal_position"
)

IO.inspect(Enum.map(rows, fn [c, n] -> {c, n} end), label: "workingtimes columns")

{:ok, %{rows: user_rows}} = Theme1.Repo.query(
  "SELECT column_name FROM information_schema.columns WHERE table_name = 'users' AND column_name LIKE 'shift%' OR column_name = 'timezone_offset_minutes' ORDER BY ordinal_position"
)

IO.inspect(Enum.map(user_rows, fn [c] -> c end), label: "users shift-related columns")