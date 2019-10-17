# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :graph_demo, GraphDemoWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "d5KwmEYO5vKulUEYQQfg2AulDe5DmfonPmNaYWcvXXg3ha5Ys+DQQ0HASw7X0z77",
  render_errors: [view: GraphDemoWeb.ErrorView, accepts: ~w(json)],
  pubsub: [name: GraphDemo.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
