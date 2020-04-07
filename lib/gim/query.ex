defmodule Gim.Query do
  @moduledoc """
  Defines queries on schemas.

  """

  defstruct type: nil,
            filter: {:and, []},
            expand: []

  import Gim.Queryable

  alias Gim.Repo.Index

  # defmacro query(expr) do
  #   quote do
  #     Gim.Query.__query__(unquote(expr))
  #   end
  # end

  def query(queryable) do
    to_query(queryable)
  end

  # defmacro expand(queryable, fields) do
  #   quote do
  #     Gim.Query.__expand__(unquote(queryable), unquote(fields))
  #   end
  # end

  # def expand(%__MODULE__{} = query, fields) do
  #   %__MODULE__{query | expand: List.wrap(fields) ++ query.expand}
  # end

  # def expand(query, fields) do
  #   query
  #   |> to_query()
  #   |> expand(fields)
  # end

  # defmacro filter(queryable, op, filter) do
  #   filter
  #   |> Macro.expand(__CALLER__)
  #   |> check_filter()

  #   quote do
  #     Gim.Query.__filter__(unquote(queryable), unquote(op), unquote(filter))
  #   end
  # end

  def filter(queryable, op \\ nil, filter)

  def filter(%__MODULE__{} = query, nil, {op, _} = filter) when op in [:and, :or] do
    %__MODULE__{query | filter: join_filter(query.filter, filter)}
  end

  def filter(%__MODULE__{} = query, op, {op, _} = filter) when op in [:and, :or] do
    %__MODULE__{query | filter: join_filter(query.filter, filter)}
  end

  def filter(%__MODULE__{} = query, opx, {op, _} = filter) when op in [:and, :or] do
    %__MODULE__{query | filter: join_filter(query.filter, {opx, [filter]})}
  end

  def filter(%__MODULE__{} = query, op, filter) when is_list(filter) do
    %__MODULE__{query | filter: join_filter(query.filter, {op || :and, filter})}
  end

  # def filter(query, filter, opts) do
  #   query
  #   |> to_query()
  #   |> filter(filter, opts)
  # end

  defp join_filter({_, []}, filter) do
    filter
  end

  defp join_filter(filter, {_, []}) do
    filter
  end

  defp join_filter({op, filter_left}, {op, filter_right}) do
    {op, filter_left ++ filter_right}
  end

  defp join_filter(left_filter, {op, filter_right}) do
    {op, [left_filter | filter_right]}
  end

  # defp check_filter(filter) do
  #   IO.inspect(filter)
  # end

  @doc """
  Returns the target nodes following the edges of given label for the given node.
  """
  def edges(nodes, assoc) when is_list(nodes) do
    Enum.map(nodes, &edges(&1, assoc))
    |> List.flatten()
    # TODO: could use dedup if sorted
    |> Enum.uniq()
  end

  def edges(%{__struct__: struct, __repo__: repo} = node, assoc) do
    ids = Map.fetch!(node, assoc)
    type = struct.__schema__(:type, assoc)
    Enum.map(ids, &repo.fetch!(type, &1))
  end

  @doc """
  Returns wether the given node has any outgoing edges.
  """
  def has_edges?(%{__struct__: struct} = node) do
    assocs = struct.__schema__(:associations)
    Enum.any?(assocs, &has_edge?(node, &1))
  end

  @doc """
  Returns wether the given node has any outgoing edges for the given label.
  """
  def has_edge?(node, assoc) do
    case Map.fetch!(node, assoc) do
      [] -> false
      nil -> false
      _ -> true
    end
  end

  @doc """
  Returns wether the given node has no outgoing edges.
  """
  def has_no_edges?(node) do
    not has_edges?(node)
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

  def delete_edge(node, assoc, targets) when is_list(targets) do
    Enum.reduce(targets, node, fn target, node ->
      delete_edge(node, assoc, target)
    end)
  end

  def delete_edge(node, assoc, %{__id__: id} = _target) do
    case Map.fetch!(node, assoc) do
      nil ->
        node

      [] ->
        node

      x when is_list(x) ->
        Map.put(node, assoc, List.delete(x, id))

      ^id ->
        Map.put(node, assoc, nil)

      _ ->
        # TODO: maybe raise error?
        node
    end
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

  def edge(nodes, assoc) when is_list(nodes) do
    Enum.map(nodes, &edge(&1, assoc))
    # TODO: could use dedup if sorted
    |> Enum.uniq()
  end

  def edge(%{__struct__: struct, __repo__: repo} = node, assoc) do
    id = Map.fetch!(node, assoc)
    type = struct.__schema__(:type, assoc)
    repo.fetch!(type, id)
  end

  def set_edge(node, assoc, %{__id__: id} = _target) do
    Map.put(node, assoc, id)
  end

  def property(nodes, property_name) when is_list(nodes) do
    Enum.map(nodes, &Map.get(&1, property_name))
  end

  def property(node, property_name) do
    Map.get(node, property_name)
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
      |> Enum.filter(&has_no_edges?/1)
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
