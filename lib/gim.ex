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

      defmodule MyApp.Publisher do
        use Gim.Schema

        alias MyApp.Book

        schema do
          property(:name, index: :unique)
          has_edges(:publisher_of, Book, reflect: :published_by)
        end
      end


  Create a repo:

      defmodule MyApp.Repo do
        use Gim.Repo,
          types: [
            MyApp.Author,
            MyApp.Book,
            MyApp.Publisher
          ]
      end


  Use queries:

      iex> MyApp.Repo.fetch!(MyApp.Author, :name, "Terry Pratchett")
      %MyApp.Author{__id__: 2, __repo__: MyApp.Repo, age: 0, author_of: [4, 3], name: "Terry Pratchett"}

      iex> terry = MyApp.Repo.fetch!(MyApp.Author, :name, "Terry Pratchett")
      iex> {:ok, [cs]} = MyApp.Publisher
      ...> |> Gim.Query.query()
      ...> |> Gim.Query.filter(name: &String.starts_with?(&1, "Colin"))
      ...> |> MyApp.Repo.resolve()
      iex> %MyApp.Book{title: "The Colour of Magic"}
      ...> |> Gim.Query.add_edge(:authored_by, terry)
      ...> |> Gim.Query.add_edge(:published_by, cs)
      ...> |> MyApp.Repo.insert!()
      %MyApp.Book{__id__: 5, __repo__: MyApp.Repo, authored_by: 2, body: nil, published_by: [3], title: "The Colour of Magic"}
  """
end
