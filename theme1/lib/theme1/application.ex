defmodule Theme1.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Theme1Web.Telemetry,
      Theme1.Repo,
      {Oban, Application.fetch_env!(:theme1, Oban)},
      {DNSCluster, query: Application.get_env(:theme1, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Theme1.PubSub},
      # Start a worker by calling: Theme1.Worker.start_link(arg)
      # {Theme1.Worker, arg},
      # Start to serve requests, typically the last entry
      Theme1Web.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Theme1.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    Theme1Web.Endpoint.config_change(changed, removed)
    :ok
  end
end
