# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :theme1,
  ecto_repos: [Theme1.Repo],
  generators: [timestamp_type: :utc_datetime]

# Development and test use a local JWT secret; production overrides it at runtime.
config :theme1, :auth_jwt_secret, System.get_env("AUTH_JWT_SECRET", "dev-auth-secret-change-me")

# Configure the endpoint
config :theme1, Theme1Web.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: Theme1Web.ErrorJSON],
    layout: false
  ],
  pubsub_server: Theme1.PubSub,
  live_view: [signing_salt: "OSCJ8USH"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :theme1, Theme1.Mailer, adapter: Swoosh.Adapters.Local

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Oban runs background jobs (auto-close of forgotten clock sessions).
config :theme1, Oban,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  queues: [default: 10, auto_close: 5],
  repo: Theme1.Repo,
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)},
    {Oban.Plugins.Cron,
     crontab: [
       {"*/15 * * * *", Theme1.Workers.AutoCloseClockSessions}
     ]}
  ]

# Global fallback shift used when neither the user nor their team has one configured.
# 540 = 09:00, 1020 = 17:00, tz_offset_minutes = 0 means UTC.
config :theme1, :default_shift, %{
  start_minutes: 540,
  end_minutes: 1020,
  tz_offset_minutes: 0
}

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
