# Gim - Graphs In-Memory

Proof-of-concept In-Memory Graph database.

Needs: tests, documentation, optimization.

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
        field :name, :string
        field :age, :integer, default: 0
        has_many :posts, Post
      end
    end

Use queries:

    a = %Author{name: "William Gibson"} |> Repo.insert()

    Repo.all(Author)

## small test

Get demo data (16.5 MB)

    wget https://github.com/dgraph-io/benchmarks/raw/master/data/1million.rdf.gz

translate to CSV

    gzip -dc 1million.rdf.gz | ./rdf2csv.pl >data.csv

then run the demo import

    iex(1)> Movies.Data.demo_import
    iex(2)> Movies.Repo.get_all!(Movie, :name, "Bugs Bunny") |>edges(:director) |>edges(:director) |>Enum.map(&Map.get(&1, :name))

## Big test (TODO)

or (166 MB)

    wget https://github.com/dgraph-io/benchmarks/raw/master/data/21million.rdf.gz

## Notes

Make Phoenix Even Faster with a GenServer-backed Key Value Store
https://thoughtbot.com/blog/make-phoenix-even-faster-with-a-genserver-backed-key-value-store

An Elixir library for parsing and extracting data from HTML and XML with CSS or XPath selectors.
https://github.com/mischov/meeseeks

Ecto adapter for Mnesia Erlang term database
https://github.com/Nebo15/ecto_mnesia

Import data using GenStage and Flow
https://blog.kloeckner-i.com/building-a-data-import-pipeline-using-genstage-and-flow/

Ecto.Schema
https://hexdocs.pm/ecto/Ecto.Schema.html

Data Division - A library that generates data-holding structures with validation, error maps
https://github.com/pragdave/data_division

(Ab)using Ecto as Elixir data casting and validation library
https://www.amberbit.com/blog/2017/12/27/ecto-as-elixir-data-casting-and-validation-library/

Flake: A decentralized, k-ordered id generation service in Erlang
https://github.com/boundary/flake

Native graph data in Elixir
https://medium.com/@tonyhammond/native-graph-data-in-elixir-8c0bb325d451

Libgraph
https://hexdocs.pm/libgraph/Graph.html

### Unique IDs

The best method I can find for generating a unique id is to use: `{node(), now()}`
- erlang:term_to_binary/1? (taking your tuple as input)
- erlang:md5/1 (taking the result of term_to_binary/1 as an input, returning a binary as the result).
- erlang:phash/2 (with some crazy large number to try to guarantee uniqueness).
- erlang:crc32/1 (taking the result of term_to_binary/2 as input, this returns an int as the result).

Reference is just almost unique value
http://erlang.org/doc/man/erlang.html#make_ref-0

### Optimizing

Best-case: `%{^key => value} = map`
https://medium.com/learn-elixir/speed-up-data-access-in-elixir-842617030514

    map = %{foo: 1, bar: 2}
    %{^:foo => foo_value} = map
