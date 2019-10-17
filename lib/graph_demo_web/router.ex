defmodule GraphDemoWeb.Router do
  use GraphDemoWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", GraphDemoWeb do
    pipe_through :api
  end
end
