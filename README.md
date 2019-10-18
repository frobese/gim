# Gim - Graphs In-Memory

Proof-of-concept In-Memory Graph database.

Needs: tests, documentation, optimization.

## Running

To start this Demo server:

  * Install dependencies with `mix deps.get`
  * Start Phoenix endpoint with `iex -S mix`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Rebuild the documentation:

  * Prepare NPM dependencies with `yarn install`
  * Run Vuepress build with `yarn docs:build`

## Example

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

## Small test

Get demo data (16.5 MB)

    wget https://github.com/dgraph-io/benchmarks/raw/master/data/1million.rdf.gz

then run the demo import

    iex(1)> Movies.Data.demo_import()
    iex(2)> Movies.Repo.get_all!(Movie, :name, "Bugs Bunny") |>edges(:director) |>edges(:director) |>Enum.map(&Map.get(&1, :name))
