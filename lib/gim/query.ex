defmodule Gim.Query do
  @moduledoc """
  Defines queries on schemas.

  """

  # Node operations

  def edges(nodes, assoc) when is_list(nodes) do
    Enum.flat_map(nodes, &edges(&1, assoc))
    |> Enum.uniq() # TODO: could use dedup if sorted
  end
  def edges(%{__struct__: struct, __repo__: repo} = node, assoc) do
    ids = Map.fetch!(node, assoc)
    type = struct.__schema__(:type, assoc)
    repo.fetch!(type, ids)
  end

  def has_edges?(%{__struct__: struct} = node) do
    assocs = struct.__schema__(:associations)
    Enum.any?(assocs, &has_edge?(node, &1))
  end

  def has_edge?(node, assoc) do
    case Map.fetch!(node, assoc) do
      [] -> false
      nil -> false
      _ -> true
    end
  end

  def node_empty?(node) do
    not has_edges?(node)
  end

  def add_edge(node, assoc, targets) when is_list(targets) do
    ids = targets |> Enum.map(fn %{__id__: id} -> id end)
    Map.update!(node, assoc, fn x -> ids ++ x end)
  end
  def add_edge(node, assoc, %{__id__: id} = _target) do
    Map.update!(node, assoc, fn x -> [id | x] end)
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
        node # TODO: maybe raise error?
    end
  end

  def clear_edges(nodes, assoc) when is_list(nodes) do
    Enum.map(nodes, &clear_edges(&1, assoc))
  end
  def clear_edges(node, assoc) do
    case Map.fetch!(node, assoc) do
      nil ->
        node
      [] ->
        node
      x when is_list(x) ->
        Map.put(node, assoc, [])
      _ ->
        Map.put(node, assoc, nil)
    end
  end

  def edge(nodes, assoc) when is_list(nodes) do
    Enum.map(nodes, &edge(&1, assoc))
    |> Enum.uniq() # TODO: could use dedup if sorted
  end
  def edge(%{__struct__: struct, __repo__: repo} = node, assoc) do
    id = Map.fetch!(node, assoc)
    type = struct.__schema__(:type, assoc)
    repo.fetch!(type, id)
  end

  def set_edge(node, assoc, %{__id__: id} = _target) do
    Map.put(node, assoc, id)
  end

  def field(nodes, fieldname) when is_list(nodes) do
    Enum.map(nodes, &Map.get(&1, fieldname))
  end
  def field(node, fieldname) do
    Map.get(node, fieldname)
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
    lonely = all_nodes
      |> Enum.filter(&node_empty?/1)
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

  # GraphViz Dot

  # dot -Tpng -otest.png test.dot
  def repo_to_dotfile(repo, filename, opts) do
    {:ok, file} = File.open(filename, [:write])
    IO.binwrite(file, repo_to_dot(repo, opts))
    File.close(file)
  end

  def repo_to_dot(repo, opts) do
    [
      "digraph #{dot_id(repo)} {\n",
      "  node [shape=record fontname=Arial];\n",

      dot_graph(repo, opts),
      dot_edges(repo),

      "  label=\"#{repo}\";\n",
      "}\n",
    ]
  end

  defp dot_graph(repo, :cluster) do
    types = repo.types()
    Enum.map(types, fn type ->
      nodes = repo.all!(type)
      [
        "  subgraph cluster_#{dot_id(type)} {\n",

        dot_nodes(nodes),

        "    color=lightgrey;\n",
        "    label=\"#{type}\";\n",
        "  }\n",
      ]
    end)
  end
  defp dot_graph(repo, _) do
    nodes = repo.dump()
    dot_nodes(nodes)
  end

  defp dot_nodes(nodes) do
    Enum.map(nodes, fn %{__struct__: struct, __id__: id} = node ->
      [
        "    #{dot_id(struct, id)}  [label=\"",
        dot_node_fields(node),
        "\"];\n",
      ]
    end)
  end

  defp dot_node_fields(%{__struct__: struct} = node) do
    fields = struct.__schema__(:fields)
    Enum.map(fields, fn field ->
      value = Map.fetch!(node, field)
      "#{field}: #{value}\\l"
    end)
  end

  defp dot_edges(repo) do
    nodes = repo.dump()
    Enum.map(nodes, fn %{__struct__: struct, __id__: id} = node ->
      assocs = struct.__schema__(:associations)
      Enum.map(assocs, fn assoc ->
        type = struct.__schema__(:type, assoc)
        edges = Map.fetch!(node, assoc)
        dot_edge(edges, struct, id, assoc, type)
      end)
    end)
  end

  defp dot_edge(edge, struct, id, assoc, type) when is_list(edge) do
    Enum.map(edge, fn e ->
      dot_edge(e, struct, id, assoc, type)
    end)
  end
  defp dot_edge(edge, struct, id, assoc, type) do
    "  #{dot_id(struct, id)} -> #{dot_id(type, edge)} [label=\"#{assoc}\"];\n"
  end

  # helper

  defp dot_id(name) do
    name |> to_string |> String.replace(".", "_")
  end

  defp dot_id(name, id) do
    "#{name}.#{id}" |> dot_id
  end
end