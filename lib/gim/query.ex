defmodule Gim.Query do
  @moduledoc """
  Defines queries on schemas.
  """

  defstruct type: nil,
            filter: {:and, []},
            expand: []

  import Gim.Queryable

  alias Gim.Index

  def query(%__MODULE__{} = query) do
    query
  end

  def query(node) when is_map(node) do
    query([node])
  end

  def query([%type{} | _rest] = nodes) do
    type
    |> to_query()
    |> __query__(nodes)
  end

  def query(queryable) do
    to_query(queryable)
  end

  def query(node, edge) when is_map(node) do
    query([node], edge)
  end

  def query([%type{} | _rest] = nodes, edge) do
    case type.__schema__(:association, edge) do
      {_, _, type, _} ->
        __query__(to_query(type), edge, nodes)

      _ ->
        raise Gim.QueryError, "No edge #{inspect(edge)} in #{type}"
    end
  end

  def __query__(query, []) do
    query
  end

  def __query__(%__MODULE__{type: type} = query, [%type{__id__: id} | nodes])
      when not is_nil(id) do
    query
    |> filter(:or, __id__: id)
    |> __query__(nodes)
  end

  def __query__(query, _edge, []) do
    query
  end

  def __query__(%__MODULE__{} = query, edge, [%{} = node | nodes]) do
    edge = Map.fetch!(node, edge)

    edge
    |> List.wrap()
    |> Enum.reduce(query, fn node_or_id, query ->
      if is_integer(node_or_id) do
        filter(query, :or, __id__: node_or_id)
      else
        __query__(query, node_or_id)
      end
    end)
    |> __query__(nodes)
  end

  @doc """
  Adds a new filter to the query.
  """
  def filter(queryable, op \\ nil, filter)

  def filter(%__MODULE__{} = query, nil, {op, _} = filter) when op in [:and, :or] do
    %__MODULE__{query | filter: __join_filter__(query.filter, filter)}
  end

  def filter(%__MODULE__{} = query, op, {op, _} = filter) when op in [:and, :or] do
    %__MODULE__{query | filter: __join_filter__(query.filter, filter)}
  end

  def filter(%__MODULE__{} = query, opx, {op, _} = filter) when op in [:and, :or] do
    %__MODULE__{query | filter: __join_filter__(query.filter, {opx, [filter]})}
  end

  def filter(%__MODULE__{} = query, op, filter) when is_list(filter) do
    %__MODULE__{query | filter: __join_filter__(query.filter, {op || :and, filter})}
  end

  @doc false
  def __join_filter__({_, []}, filter) do
    filter
  end

  def __join_filter__(filter, {_, []}) do
    filter
  end

  def __join_filter__({op, filter_left}, {op, filter_right}) do
    {op, filter_left ++ filter_right}
  end

  def __join_filter__(left_filter, {op, filter_right}) do
    {op, [left_filter | filter_right]}
  end

  def expand(queryable, edge_or_path)

  def expand(%__MODULE__{type: type, expand: expand} = query, path) do
    %__MODULE__{query | expand: __join_expand__(type, expand, path)}
  end

  @doc false
  def __join_expand__(type, expand, edge) when not is_list(edge) do
    __join_expand__(type, expand, [edge])
  end

  def __join_expand__(type, expand, [{edge, nested} | path]) do
    case type.__schema__(:association, edge) do
      {_name, _cardinality, nested_type, _} ->
        nested_expand = Keyword.get(expand, edge, [])
        expand = Keyword.put(expand, edge, __join_expand__(nested_type, nested_expand, nested))

        __join_expand__(type, expand, path)

      nil ->
        raise Gim.QueryError, "No edge #{inspect(edge)} in #{type}"
    end
  end

  def __join_expand__(type, expand, [edge | path]) do
    __join_expand__(type, expand, [{edge, []} | path])
  end

  def __join_expand__(_type, expand, []) do
    expand
  end

  @doc """
  Returns the target nodes following the edges of given label for the given node.
  """
  def edges([%{__repo__: repo} | _] = nodes, assoc) do
    nodes
    |> query(assoc)
    |> repo.resolve!()
  end

  def edges(node, assoc) when is_map(node) do
    edges([node], assoc)
  end

  @doc """
  Returns wether the given node has any outgoing edges.
  """
  def has_edges?(%type{} = node) do
    assocs = type.__schema__(:associations)
    Enum.any?(assocs, &has_edge?(node, &1))
  end

  @doc """
  Returns wether the given node has any outgoing edges for the given label.
  """
  def has_edge?(%type{} = node, assoc) do
    edge = Map.get(node, assoc)

    case type.__schema__(:association, assoc) do
      {_, :one, _, _} ->
        !is_nil(edge)

      {_, :many, _, _} ->
        length(edge) > 0

      _ ->
        raise Gim.UnknownEdgeError, "No edge #{inspect(assoc)} in #{inspect(type)}"
    end
  end

  def add_edge(%struct{} = node, assoc, targets) when is_list(targets) do
    assoc = struct.__schema__(:association, assoc)
    Enum.reduce(targets, node, &__add_edge__(&2, assoc, &1))
  end

  def add_edge(%struct{} = node, assoc, target) do
    assoc = struct.__schema__(:association, assoc)
    __add_edge__(node, assoc, target)
  end

  def __add_edge__(node, {assoc, :one, type, _}, %type{__id__: id}) do
    %{node | assoc => id}
  end

  def __add_edge__(node, {assoc, :many, type, _}, %type{__id__: id}) do
    ids = Index.add(Map.fetch!(node, assoc), id)
    %{node | assoc => ids}
  end

  def delete_edge(%struct{} = node, assoc, targets) when is_list(targets) do
    assoc = struct.__schema__(:association, assoc)
    Enum.reduce(targets, node, &__delete_edge__(&2, assoc, &1))
  end

  def delete_edge(%struct{} = node, assoc, target) do
    assoc = struct.__schema__(:association, assoc)
    __delete_edge__(node, assoc, target)
  end

  @doc false
  def __delete_edge__(node, {assoc, :one, type, _}, %type{}) do
    %{node | assoc => nil}
  end

  def __delete_edge__(node, {assoc, :many, type, _}, %type{__id__: id}) do
    ids = Index.remove(Map.fetch!(node, assoc), id)
    %{node | assoc => ids}
  end

  def clear_edges(%struct{} = node) do
    assocs = struct.__schema__(:associations)

    Enum.reduce(assocs, node, fn assoc, node ->
      clear_edge(node, assoc)
    end)
  end

  def clear_edge(%struct{} = node, assoc) do
    case struct.__schema__(:association, assoc) do
      {_, :one, _, _} ->
        Map.put(node, assoc, nil)

      {_, :many, _, _} ->
        Map.put(node, assoc, [])

      _ ->
        node
    end
  end

  # Node set operations
  def intersection(nodes1, nodes2) when is_list(nodes1) and is_list(nodes2) do
    # TODO: check node type
    Enum.filter(nodes1, fn %{__id__: a} ->
      Enum.any?(nodes2, fn %{__id__: b} ->
        a == b
      end)
    end)
  end

  def reachable(nodes, edge, target) when is_list(nodes) do
    Enum.filter(nodes, fn node ->
      reachable(node, edge, target)
    end)
  end

  def reachable(node, edge, target) do
    # TODO: check node type
    edges = Map.fetch!(node, edge)
    reachable(edges, target)
  end

  defp reachable(edges, target) when is_list(edges) do
    Enum.any?(edges, fn e ->
      reachable(e, target)
    end)
  end

  defp reachable(edge, %{__id__: id}) do
    edge == id
  end

  # Repo operations

  @doc """
  Computes all isolated nodes from a repo.
  """
  def isolated(repo) do
    all_nodes = repo.dump()

    lonely =
      all_nodes
      |> Enum.reject(&has_edges?/1)
      |> Enum.map(fn %{__struct__: struct, __id__: id} -> {struct, id} end)
      |> Enum.into(MapSet.new())

    Enum.reduce(all_nodes, lonely, fn %{__struct__: struct} = node, lonely ->
      assocs = struct.__schema__(:associations)

      Enum.reduce(assocs, lonely, fn assoc, lonely ->
        type = struct.__schema__(:type, assoc)
        edges = Map.fetch!(node, assoc)

        set_delete(lonely, type, edges)
      end)
    end)

    all_nodes
    |> Enum.filter(fn %{__struct__: struct, __id__: id} ->
      MapSet.member?(lonely, {struct, id})
    end)
  end

  defp set_delete(set, type, edges) when is_list(edges) do
    Enum.reduce(edges, set, fn edge, set ->
      set_delete(set, type, edge)
    end)
  end

  defp set_delete(set, type, edge) do
    MapSet.delete(set, {type, edge})
  end
end
