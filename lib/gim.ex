defmodule Gim do
  @moduledoc """
  #{Gim.MixProject.project()[:description]}.

  ## Usage
  Add Gim to your application by adding `{:gim, "~> #{Mix.Project.config()[:version]}"}` to your list of dependencies in `mix.exs`:
  ```elixir
  def deps do
    [
      # ...
      {:gim, "~> #{Mix.Project.config()[:version]}"}
    ]
  end
  ```

  ## Usage

  Create a repo:

      defmodule MyApp.Repo do
        use Gim.Repo, otp_app: :my_app
      end

  And schemas:

      defmodule MyApp.Author do
        use Gim.Schema
        alias MyApp.Post
        schema do
          property :name, index: :unique
          property :age, default: 0
          has_edges :posts, Post
        end
      end

  Use queries:

      a = %Author{name: "William Gibson"} |> Repo.insert()

      Repo.all(Author)
  """
end
