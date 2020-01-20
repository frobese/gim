defmodule Gael do
  @moduledoc """
  Graphs as edge lists. Simple indexed Edge lists (RDF-like) in-memory graph pseudo-db.
  """

  # The Gael struct holds a map of edges by predicate and an index of nodes by predicate
  defstruct ebyp: %{}, ibyp: %{}

  # "1million.rdf.gz" |> File.stream!([:compressed]) |> Gim.Rdf.stream_rdf() |> Gael.create()
  def create(rdfs) do
    ebyp = rdfs |> Enum.reduce(%{}, &collect/2)
    %Gael{ebyp: ebyp}
  end

  def index_all(%Gael{} = gael) do
    gael.ebyp |> Map.keys()
    |> Enum.reduce(gael, &add_index(&2, &1))
  end

  def add_index(%Gael{ebyp: ebyp, ibyp: ibyp} = gael, predicate) do
    i = Map.fetch!(ebyp, predicate) |> Enum.reduce(%{}, fn {key, vals}, acc ->
      Enum.reduce(vals, acc, fn val, acc ->
        Map.update(acc, val, [key], fn other ->
          [key | other]
        end)
      end)
    end)
    ibyp = Map.put(ibyp, predicate, i)
    %Gael{gael | ibyp: ibyp}
  end

  # Query API

  def all_predicates(%Gael{ebyp: ebyp}) do
    ebyp |> Map.keys()
  end

  ## searching for a node on ebyp finds all edges outgoing from the node
  ## expand the nodes
  def expand(nodes, %Gael{} = gael) when is_list(nodes) do
    nodes |> Enum.map(&expand(&1, gael))
  end
  def expand(node, %Gael{ebyp: ebyp}) do
    Enum.map(ebyp, fn {p, edges} ->
      {p, Map.get(edges, node)}
    end)
    |> Enum.reject(&empty_kv?/1)
  end

  ## get forward edges to nodes for a given predicate
  def follow(nodes, pred, %Gael{} = gael) when is_list(nodes) do
    nodes
    |> Enum.map(&follow(&1, pred, gael))
    |> List.flatten()
  end
  def follow(node, pred, %Gael{ebyp: ebyp}) do
    ebyp[pred]
    |> Map.get(node)
  end

  ## searching for a node on ibyp finds all edges incoming to the node
  ## get reverse edges to nodes
  def reverse(nodes, %Gael{} = gael) when is_list(nodes) do
    nodes
    |> Enum.map(&reverse(&1, gael))
  end
  def reverse(node, %Gael{ibyp: ibyp}) do
    Enum.map(ibyp, fn {p, nodes} ->
      {p, Map.get(nodes, node)}
    end)
    |> Enum.reject(&empty_kv?/1)
  end

  ## get nodes by a property
  ## get reverse edges to nodes for a given predicate
  def reverse(nodes, pred, %Gael{} = gael) when is_list(nodes) do
    nodes
    |> Enum.map(&reverse(&1, pred, gael))
    |> List.flatten()
  end
  def reverse(node, pred, %Gael{ibyp: ibyp}) do
    ibyp[pred]
    |> Map.get(node)
  end

  # Demo

  def demo_load() do
    {usecs, data} = :timer.tc(fn ->
      "1million.rdf.gz" |> File.stream!([:compressed]) |> Gim.Rdf.stream_rdf() |> Enum.to_list()
    end)
    count = data |> Enum.count()
    IO.puts("Disk load: #{Float.round(usecs / 1_000_000, 1)} s, #{Float.round(usecs / count, 1)} us/op")

    empty = :erlang.memory(:total)
    {usecs, gael} = :timer.tc(fn ->
      data
      |> Gael.create()
    end)
    IO.puts("Import: #{Float.round(usecs / 1_000_000, 1)} s, #{Float.round(usecs / count, 1)} us/op")
    {usecs, gael} = :timer.tc(fn ->
      gael
      |> Gael.index_all()
    end)
    IO.puts("Index: #{Float.round(usecs / 1_000_000, 1)} s, #{Float.round(usecs / count, 1)} us/op")
    loaded = :erlang.memory(:total)
    memory = (loaded - empty) / 1024 / 1024
    IO.puts("Memory usage: #{Float.round(memory, 1)} MB")
    # Disk load: 5.4 s
    # Time: 3.4 s, Memory usage: 79.9 MB, 3.2 us/op
    gael
  end

  # private

  def empty_kv?({_k, nil}), do: true
  def empty_kv?({_k, []}), do: true
  def empty_kv?({_k, _v}), do: false

  # :"actor.film", :"dgraph.type", :"director.film", :genre, :initial_release_date,
  # :name, :"performance.actor", :"performance.character", :"performance.film",
  # :starring

  defp collect(:blank, edges), do: edges
  defp collect({:comment, _}, edges), do: edges
  defp collect({subject, predicate, object}, edges) do
    Map.update(edges, predicate, %{subject => [object]}, fn map ->
      Map.update(map, subject, [object], fn other ->
        [object | other]
      end)
    end)
  end
end

# g = "1million.rdf.gz" |> File.stream!([:compressed]) |> Gim.Rdf.stream_rdf() |> Gael.create()
# g = g |> Gael.index_all()

## get nodes by a property
# {:en, "Bugs Bunny"} |> Gael.reverse(:name, g)

## expand the nodes, nothing much to see
# {:en, "Bugs Bunny"} |> Gael.reverse(:name, g) |> Gael.expand(g)

## get reverse edges to these nodes
# {:en, "Bugs Bunny"} |> Gael.reverse(:name, g) |> Gael.reverse(g)

## ok, lot's of performance.character edges, lets follow those
# {:en, "Bugs Bunny"} |> Gael.reverse(:name, g) |> Gael.reverse(:"performance.character", g)
# {:en, "Bugs Bunny"} |> Gael.reverse(:name, g) |> Gael.reverse(:"performance.character", g) |> Gael.expand(g)

## grab all the referenced movies
# {:en, "Bugs Bunny"} |> Gael.reverse(:name, g) |> Gael.reverse(:"performance.character", g) |> Gael.follow(:"performance.film", g)
# {:en, "Bugs Bunny"} |> Gael.reverse(:name, g) |> Gael.reverse(:"performance.character", g) |> Gael.follow(:"performance.film", g) |> Gael.expand(g)
