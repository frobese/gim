defmodule Gim do
  @moduledoc """
  #{Gim.MixProject.project()[:description]}

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

  Create schemas:

      defmodule MyApp.Author do
        use Gim.Schema

        schema do
          property(:name, index: :unique)
          property(:age, default: 0, index: true)
          has_edges(:author_of, MyApp.Book, reflect: :authored_by)
        end
      end

      defmodule MyApp.Book do
        use Gim.Schema

        schema do
          property(:title, index: :unique)
          property(:body)
          has_edge(:authored_by, MyApp.Author, reflect: :author_of)
        end
      end

  Create a repo:

      defmodule MyApp.Repo do
        use Gim.Repo,
          types: [
            MyApp.Author,
            MyApp.Book
          ]
      end


  Use queries:

      iex> a = %MyApp.Author{name: "William Gibson"} |> Repo.insert()

      iex> Repo.all(Author)
  """
end
