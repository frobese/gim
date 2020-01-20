defmodule Goe do
  @moduledoc """
  Graphs on ETS. Simple indexed Edge lists (RDF-like) in-memory graph pseudo-db.
  """

  # "1million.rdf.gz" |> File.stream!([:compressed]) |> Gim.Rdf.stream_rdf() |> Goe.create()
  def create(rdfs) do
    predicates = rdfs |> Enum.reduce(%{}, &collect/2) |> Map.keys()

    tab_name = Module.concat(:config, :all)
    tab = :ets.new(tab_name, [:named_table, :duplicate_bag])
    predicates |> Enum.each(fn pred ->
      :ets.insert(tab, {:predicates, pred})
    end)

    :ok
  end

  def index_all(_ \\ nil) do
    tab_name = Module.concat(:config, :all)
    predicates = lookup_element(tab_name, :predicates)

    predicates |> Enum.each(&add_index/1)
  end

  def add_index(predicate) do
    # source
    etab_name = Module.concat(:ebyp, predicate)
    etab = case :ets.whereis(etab_name) do
      :undefined  -> :ets.new(etab_name, [:named_table, :duplicate_bag])
      tab -> tab
    end
    # target
    itab_name = Module.concat(:ibyp, predicate)
    itab = case :ets.whereis(itab_name) do
      :undefined  -> :ets.new(itab_name, [:named_table, :duplicate_bag])
      tab -> tab
    end

    :ets.foldl(fn {subject, object}, _acc ->
      :ets.insert(itab, {object, subject})
      nil
    end, nil, etab)
  end

  # Query API

  def all_predicates() do
    tab_name = Module.concat(:config, :all)
    # :ets.match(tab_name, :"$1")
    lookup_element(tab_name, :predicates)
  end

  ## searching for a node on ebyp finds all edges outgoing from the node
  ## expand the nodes
  def expand(nodes) when is_list(nodes) do
    nodes |> Enum.map(&expand(&1))
  end
  def expand(node) do
    tab_name = Module.concat(:config, :all)
    predicates = lookup_element(tab_name, :predicates)

    Enum.map(predicates, fn pred ->
      tab_name = Module.concat(:ebyp, pred)
      {pred, lookup_element(tab_name, node)}
    end)
    |> Enum.reject(&empty_kv?/1)
  end

  ## get forward edges to nodes for a given predicate
  def follow(nodes, pred) when is_list(nodes) do
    nodes
    |> Enum.map(&follow(&1, pred))
    |> List.flatten()
  end
  def follow(node, pred) do
    tab_name = Module.concat(:ebyp, pred)
    lookup_element(tab_name, node)
  end

  ## searching for a node on ibyp finds all edges incoming to the node
  ## get reverse edges to nodes
  def reverse(nodes) when is_list(nodes) do
    nodes
    |> Enum.map(&reverse(&1))
  end
  def reverse(node) do
    tab_name = Module.concat(:config, :all)
    predicates = lookup_element(tab_name, :predicates)

    Enum.map(predicates, fn pred ->
      tab_name = Module.concat(:ibyp, pred)
      {pred, lookup_element(tab_name, node)}
    end)
    |> Enum.reject(&empty_kv?/1)
  end

  ## get nodes by a property
  ## get reverse edges to nodes for a given predicate
  def reverse(nodes, pred) when is_list(nodes) do
    nodes
    |> Enum.map(&reverse(&1, pred))
    |> List.flatten()
  end
  def reverse(node, pred) do
    tab_name = Module.concat(:ibyp, pred)
    lookup_element(tab_name, node)
  end

  # Demo

  def demo_load() do
    {usecs, data} = :timer.tc(fn ->
      "1million.rdf.gz" |> File.stream!([:compressed]) |> Gim.Rdf.stream_rdf() |> Enum.to_list()
    end)
    count = data |> Enum.count()
    IO.puts("Disk load: #{Float.round(usecs / 1_000_000, 1)} s, #{Float.round(usecs / count, 1)} us/op")

    empty = :erlang.memory(:total)
    {usecs, goe} = :timer.tc(fn ->
      data
      |> Goe.create()
    end)
    IO.puts("Import: #{Float.round(usecs / 1_000_000, 1)} s, #{Float.round(usecs / count, 1)} us/op")
    {usecs, goe} = :timer.tc(fn ->
      goe
      |> Goe.index_all()
    end)
    IO.puts("Index: #{Float.round(usecs / 1_000_000, 1)} s, #{Float.round(usecs / count, 1)} us/op")
    loaded = :erlang.memory(:total)
    memory = (loaded - empty) / 1024 / 1024
    IO.puts("Memory usage: #{Float.round(memory, 1)} MB")
    # Disk load: 5.4 s
    # Time: 2.6 s, Memory usage: 336.8 MB, 2.4 us/op
    goe
  end

  # private

  def lookup_element(tab, key) do
    try do
      :ets.lookup_element(tab, key, 2)
    rescue
      ArgumentError -> []
    end
  end

  def empty_kv?({_k, nil}), do: true
  def empty_kv?({_k, []}), do: true
  def empty_kv?({_k, _v}), do: false

  # :"actor.film", :"dgraph.type", :"director.film", :genre, :initial_release_date,
  # :name, :"performance.actor", :"performance.character", :"performance.film",
  # :starring

  defp collect(:blank, tabs), do: tabs
  defp collect({:comment, _}, tabs), do: tabs
  defp collect({subject, predicate, object}, tabs) do
    {tabs, tab} = case Map.get(tabs, predicate) do
      nil ->
        tab = :ets.new(Module.concat(:ebyp, predicate), [:named_table, :duplicate_bag])
        tabs = Map.put(tabs, predicate, tab)
        {tabs, tab}
      tab -> {tabs, tab}
    end
    :ets.insert(tab, {subject, object})
    tabs
  end
end

# "1million.rdf.gz" |> File.stream!([:compressed]) |> Gim.Rdf.stream_rdf() |> Goe.create() |> Goe.index_all()

## get nodes by a property
# {:en, "Bugs Bunny"} |> Goe.reverse(:name)

## expand the nodes, nothing much to see
# {:en, "Bugs Bunny"} |> Goe.reverse(:name) |> Goe.expand()

## get reverse edges to these nodes
# {:en, "Bugs Bunny"} |> Goe.reverse(:name) |> Goe.reverse()

## ok, lot's of performance.character edges, lets follow those
# {:en, "Bugs Bunny"} |> Goe.reverse(:name) |> Goe.reverse(:"performance.character")
# {:en, "Bugs Bunny"} |> Goe.reverse(:name) |> Goe.reverse(:"performance.character") |> Goe.expand()

## grab all the referenced movies
# {:en, "Bugs Bunny"} |> Goe.reverse(:name) |> Goe.reverse(:"performance.character") |> Goe.follow(:"performance.film")
# {:en, "Bugs Bunny"} |> Goe.reverse(:name) |> Goe.reverse(:"performance.character") |> Goe.follow(:"performance.film") |> Goe.expand()

## -or-
# import Goe
# {:en, "Bugs Bunny"} |> reverse(:name) |> reverse(:"performance.character") |> follow(:"performance.film") |> expand()
