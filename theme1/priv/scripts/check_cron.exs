# Ask Oban what jobs are scheduled to run.
import Ecto.Query

jobs =
  Theme1.Repo.all(
    from j in Oban.Job,
      select: {j.id, j.worker, j.queue, j.state, j.scheduled_at},
      order_by: [desc: j.id]
  )

IO.inspect(jobs, label: "oban jobs")

# Also list all running Oban instances' plugin configs
IO.inspect(
  Application.get_env(:theme1, Oban),
  label: "oban config"
)