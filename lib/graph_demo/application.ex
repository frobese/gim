defmodule GraphDemo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Start the endpoint when the application starts
      GraphDemoWeb.Endpoint,
      GraphDemo.Acl.Repo,
      GraphDemo.Biblio.Repo,
      GraphDemo.Movies.Repo,
      GraphDemo.Untyped.Repo,
      # Starts a worker by calling: GraphDemo.Worker.start_link(arg)
      # {GraphDemo.Worker, arg},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GraphDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    GraphDemoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
