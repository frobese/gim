defmodule GraphDemo.Movies.Data do
  alias GraphDemo.Movies.{Repo, Person, Genre, Movie}
  alias __MODULE__

  # Import whole database

  def demo_import() do
    empty = :erlang.memory(:total)
    {usecs, :ok} = :timer.tc(fn ->
      Data.import("data.csv")
      |> Enum.into(%{})
      |> Repo.import(errors: :ignore)
      :ok
    end)
    loaded = :erlang.memory(:total)
    secs = usecs / 1_000_000
    memory = (loaded - empty) / 1024 / 1024
    IO.puts("Time: #{Float.round(secs, 1)} s, Memory usage: #{Float.round(memory, 1)} MB")
    # Time: 0.9 s, Memory usage: 105.2 MB
  end

  def import(filename) do
    File.stream!(filename)
      |> Enum.map(&import_line/1)
  end

  def import_line(line) do
    line
      |> String.trim()
      |> String.split(";")
      |> import_record()
  end

  def import_record([nickname, type | fields]) do
    import_struct(nickname, type, fields |> Enum.map(&parse_kv/1))
  end

  def parse_kv(field) do
    [k, v] = field |> String.split(":", parts: 2)
    {k |> String.to_existing_atom(), v} |> parse_field()
  end

  def parse_field({:genre, value}) do
    {:genre, value |> String.split(",")}
  end
  def parse_field({:director, value}) do
    {:director, value |> String.split(",")}
  end
  def parse_field(kv) do
    kv
  end

  def import_struct(nickname, "Person", fields) do
    {nickname, struct(Person, fields)}
  end
  def import_struct(nickname, "Genre", fields) do
    {nickname, struct(Genre, fields)}
  end
  def import_struct(nickname, "Movie", fields) do
    {nickname, struct(Movie, fields)}
  end

  # Load database on record at a time

  def demo_load() do
    empty = :erlang.memory(:total)
    {usecs, :ok} = :timer.tc(fn ->
      Data.import("data.csv")
      |> Enum.into(%{})
      |> Data.resolve_nodes()
      |> Enum.each(&Repo.load/1)
      :ok
    end)
    loaded = :erlang.memory(:total)
    secs = usecs / 1_000_000
    memory = (loaded - empty) / 1024 / 1024
    IO.puts("Time: #{Float.round(secs, 1)} s, Memory usage: #{Float.round(memory, 1)} MB")
    # Time: 77.2 s, Memory usage: 124.1 MB (without dup check)
    # Time: 857.3 s, Memory usage: 124.1 MB (external dup check)
    # Time: 309.0 s, Memory usage: 70.0 MB (internal dup check)
    # Time: 1.5 s, Memory usage: 57.7 MB (with index on :name)
  end

  # resolve all nodes by resolving edges
  def resolve_nodes(map) do
    map
    |> Map.values()
    |> Enum.map(&resolve_node(&1, map))
  end

  # resolve a node by resolving edges
  def resolve_node(%{__struct__: Movie} = node, map) do
    %{node |
      genre: node.genre |> resolve_edges(map),
      director: node.director |> resolve_edges(map),
      starring: node.starring |> resolve_edges(map),
    }
  end
  def resolve_node(node, _map) do
    node
  end

  # resolve all edge alias-names, removes invalid edges
  def resolve_edges(edges, map) do
    edges
    |> Enum.map(fn edge -> Map.get(map, edge) end)
    |> Enum.reject(&is_nil/1)
  end
end
