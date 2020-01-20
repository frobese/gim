defmodule GraphDemo.Movies.Data do
  alias GraphDemo.Movies.{Repo, Person, Genre, Movie, Performance, Character}
  alias __MODULE__

  # "1million.rdf.gz" |> File.stream!([:compressed]) |> Gim.Rdf.read_rdf() |> Movies.Data.map_movies() |> Movies.Repo.import(errors: :ignore)

  def map_movies(rdf) do
    Enum.map(rdf, &build_node/1)
    |> Enum.into(%{})
  end

  # "dgraph.type": {:en, "Movie"} AND "initial_release_date" -> Movie, ELSE -> Character
  # "dgraph.type": {:en, "Person"} -> Person ( also "actor.film" )
  # "dgraph.type": {:en, "Person"} -> Person ( also "director.film" )
  # "dgraph.type": {:en, "Genre"} -> Genre
  # "performance.character" -> Performance
  # "performance.actor" -> Performance
  # "performance.film" -> Performance
  def build_node({key, props}) do
    dgraph_type = List.keyfind(props, :"dgraph.type", 0)
    initial_release_date = List.keyfind(props, :initial_release_date, 0)
    director = List.keyfind(props, :director, 0)
    character = List.keyfind(props, :character, 0)
    node = cond do
      character != nil -> build(%Performance{}, props)
      initial_release_date != nil -> build(%Movie{}, props)
      director != nil -> build(%Person{}, props)
      dgraph_type == {:"dgraph.type", {:en, "Person"}} -> build(%Person{}, props)
      dgraph_type == {:"dgraph.type", {:en, "Genre"}} -> build(%Genre{}, props)
      dgraph_type == {:"dgraph.type", {:en, "Movie"}} -> build(%Character{}, props)
      true -> raise "Can't type node #{inspect props}"
    end
    {key, node}
  end

  def predicate_fun("performance.character"), do: :character
  def predicate_fun("performance.actor"), do: :actor
  def predicate_fun("performance.film"), do: :film
  def predicate_fun("actor.film"), do: :actor
  def predicate_fun("director.film"), do: :director
  def predicate_fun(string), do: String.to_atom(string)

  defp build(node, []),
    do: node
  defp build(node, [{:name, {:en, name}} | props]),
    do: build(%{node | name: name}, props)

  defp build(node, [{:character, edge} | props]),
    do: build(%{node | character: edge}, props)
  defp build(node, [{:actor, edge} | props]),
    do: build(%{node | actor: edge}, props)
  defp build(node, [{:film, edge} | props]),
    do: build(%{node | film: edge}, props)

  defp build(node, [{:initial_release_date, value} | props]),
    do: build(%{node | initial_release_date: value}, props)
  defp build(%{director: director} = node, [{:director, edge} | props]),
    do: build(%{node | director: [edge | director]}, props)
  defp build(%{starring: starring} = node, [{:starring, edge} | props]),
    do: build(%{node | starring: [edge | starring]}, props)
  defp build(%{genre: genre} = node, [{:genre, edge} | props]),
    do: build(%{node | genre: [edge | genre]}, props)

  defp build(node, [{:name, {:de, _name}} | props]),
    do: build(node, props)
  defp build(node, [{:name, {:it, _name}} | props]),
    do: build(node, props)
  defp build(node, [{:"dgraph.type", _} | props]),
    do: build(node, props)

  #defp build(node, [_ | props]),
  #  do: build(node, props)

  # Load whole database at a time using temporary aliases

  def demo_import() do
    empty = :erlang.memory(:total)

    {usecs, data} = :timer.tc(fn ->
      "1million.rdf.gz" |> File.stream!([:compressed]) |> Gim.Rdf.read_rdf(&Data.predicate_fun/1)
    end)
    count = data |> Enum.count()
    secs = usecs / 1_000_000
    IO.puts("Disk load: #{Float.round(secs, 1)} s, lines: #{count}")

    {usecs, data} = :timer.tc(fn ->
      data |> Data.map_movies()
    end)
    count = data |> Enum.count()
    secs = usecs / 1_000
    IO.puts("Into Map: #{Float.round(secs, 1)} ms, entries: #{count}")

    loaded1 = :erlang.memory(:total)
    :erlang.garbage_collect()
    loaded2 = :erlang.memory(:total)
    memory = (loaded1 - loaded2) / 1024 / 1024
    IO.puts("GC freed: #{Float.round(memory, 1)} MB")
    memory = (loaded2 - empty) / 1024 / 1024
    IO.puts("Load mem: #{Float.round(memory, 1)} MB")

    {usecs, :ok} = :timer.tc(fn ->
      data
      |> Repo.import(errors: :ignore)
      :ok
    end)
    loaded3 = :erlang.memory(:total)
    ops = usecs / count
    secs = usecs / 1_000_000
    memory = (loaded3 - loaded2) / 1024 / 1024
    IO.puts("Time: #{Float.round(secs, 1)} s, Memory usage: #{Float.round(memory, 1)} MB, #{Float.round(ops, 1)} us/op")
    # Time: 0.9 s, Memory usage: 105.2 MB
    # 197408 records: Time: 4.4 s, Memory usage: 180.2 MB, 22.3 us/op
    # 316886 records: Time: 8.4 s, Memory usage: 219.1 MB, 26.4 us/op

    data = nil
    :erlang.garbage_collect()
    loaded4 = :erlang.memory(:total)
    memory = (loaded3 - loaded4) / 1024 / 1024
    IO.puts("GC freed: #{Float.round(memory, 1)} MB")
    memory = (loaded4 - empty) / 1024 / 1024
    IO.puts("Repo mem: #{Float.round(memory, 1)} MB")
  end

  # CSV import with external keys

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

  def import_record([nickname, type | properties]) do
    import_struct(nickname, type, properties |> Enum.map(&parse_kv/1))
  end

  def parse_kv(property) do
    [k, v] = property |> String.split(":", parts: 2)
    {k |> String.to_existing_atom(), v} |> parse_property()
  end

  def parse_property({key, <<"[", value :: binary>>}) do
    {key, value |> String.trim_trailing("]") |> String.split(",")}
  end
  def parse_property(kv) do
    kv
  end

  def import_struct(nickname, "Person", properties) do
    {nickname, struct(Person, properties)}
  end
  def import_struct(nickname, "Genre", properties) do
    {nickname, struct(Genre, properties)}
  end
  def import_struct(nickname, "Movie", properties) do
    {nickname, struct(Movie, properties)}
  end
  def import_struct(nickname, "Performance", properties) do
    {nickname, struct(Performance, properties)}
  end
  def import_struct(nickname, "Character", properties) do
    {nickname, struct(Character, properties)}
  end

  # Import database on record at a time

  def demo_load() do
    {usecs, data} = :timer.tc(fn ->
      "1million.rdf.gz" |> File.stream!([:compressed]) |> Gim.Rdf.read_rdf(&Data.predicate_fun/1)
      |> Data.map_movies()
    end)
    secs = usecs / 1_000_000
    IO.puts("Disk load: #{Float.round(secs, 1)} s")

    data = data |> Data.resolve_nodes() # not needed with proper data

    empty = :erlang.memory(:total)
    {usecs, :ok} = :timer.tc(fn ->
      data
      |> Enum.each(&Repo.load/1)
      :ok
    end)
    loaded = :erlang.memory(:total)
    count = data |> Enum.count()
    ops = usecs / count
    secs = usecs / 1_000_000
    memory = (loaded - empty) / 1024 / 1024
    IO.puts("Time: #{Float.round(secs, 1)} s, Memory usage: #{Float.round(memory, 1)} MB, #{Float.round(ops, 1)} us/op")
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
  def resolve_node(%{__struct__:  Person} = node, map) do
    %{node |
      director: node.director |> resolve_edges(map),
      actor: node.actor |> resolve_edges(map),
    }
  end
  def resolve_node(%{__struct__:  Performance} = node, map) do
    %{node |
      film: node.film |> resolve_edges(map),
      actor: node.actor |> resolve_edges(map),
      character: node.character |> resolve_edges(map),
    }
  end
  def resolve_node(%{__struct__:  Genre} = node, map) do
    %{node |
      movies: node.movies |> resolve_edges(map),
    }
  end
  def resolve_node(%{__struct__:  Character} = node, map) do
    %{node |
      performances: node.performances |> resolve_edges(map),
    }
  end
#  def resolve_node(node, _map) do
#    node
#  end

  # resolve all edge alias-names, removes invalid edges
  def resolve_edges(edges, map) when is_list(edges) do
    edges
    |> Enum.map(fn edge -> Map.get(map, edge) end)
    |> Enum.reject(&is_nil/1)
  end
  def resolve_edges(edge, map) do
    Map.get(map, edge)
  end
end
