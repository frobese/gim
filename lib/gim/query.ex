defmodule Gim.Query do
  @moduledoc """
  Defines queries on schemas.

  """

  defstruct type: nil,
            filter: {:and, []},
            expand: []

  @doc """
  Returns the target nodes following the edges of given label for the given node.
  """
  def edges(nodes, assoc) when is_list(nodes) do
    Enum.map(nodes, &edges(&1, assoc))
    |> List.flatten()
    |> Enum.uniq() # TODO: could use dedup if sorted
  end
  def edges(%{__struct__: struct, __repo__: repo} = node, assoc) do
    ids = Map.fetch!(node, assoc)
    type = struct.__schema__(:type, assoc)
    repo.fetch!(type, ids)
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
    lonely = all_nodes
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

  # JSON dump

  def repo_to_jsonfile(repo, filename) do
    {:ok, file} = File.open(filename, [:write])
    IO.binwrite(file, repo_to_json(repo))
    File.close(file)
  end

  def repo_to_json(repo) do
    types = repo.type_aliases()
    nodes = repo.dump()
    [
      "{\n",
      Enum.map(nodes, &json_node(&1, types))
      |> Enum.intersperse(",\n"),
      "\n}\n",
    ]
  end

  defp json_node(%{__struct__: struct, __id__: id} = node, types) do
    props = struct.__schema__(:properties)
    assocs = struct.__schema__(:associations)
    [
      "\"#{types[struct]}.#{id}\" : { \"_type\" : \"#{types[struct]}\"",
      Enum.map(props, &json_property(node, &1)),
      Enum.map(assocs, &json_edges(node, &1, types)),
      "}",
    ]
  end

  defp json_property(node, property_name) do
    %{^property_name => value} = node
    ", \"#{property_name}\" : \"#{value}\""
  end

  defp json_edges(%{__struct__: struct} = node, assoc, types) do
    type = struct.__schema__(:type, assoc)
    edges = Map.fetch!(node, assoc)
    [
      ", \"#{assoc}\" : ",
      json_edge(edges, type, types),
    ]
  end

  defp json_edge(edges, type, types) when is_list(edges) do
    [
      "[",
      Enum.map(edges, fn edge ->
        "\"#{types[type]}.#{edge}\""
      end) |> Enum.join(","),
      "]",
    ]
  end
  defp json_edge(edge, type, types) do
    "\"#{types[type]}.#{edge}\""
  end

  # CSV dump

  def repo_to_csvfile(repo, filename) do
    {:ok, file} = File.open(filename, [:write])
    IO.binwrite(file, repo_to_csv(repo))
    File.close(file)
  end

  def repo_to_csv(repo) do
    types = repo.type_aliases()
    nodes = repo.dump()
    Enum.map(nodes, &csv_node(&1, types))
  end

  defp csv_node(%{__struct__: struct, __id__: id} = node, types) do
    props = struct.__schema__(:properties)
    assocs = struct.__schema__(:associations)
    [
      "#{types[struct]}.#{id};#{types[struct]}",
      Enum.map(props, &csv_property(node, &1)),
      Enum.map(assocs, &csv_edges(node, &1, types)),
      "\n",
    ]
  end

  defp csv_property(node, property_name) do
    %{^property_name => value} = node
    ";#{property_name}:#{value}"
  end

  defp csv_edges(%{__struct__: struct} = node, assoc, types) do
    type = struct.__schema__(:type, assoc)
    edges = Map.fetch!(node, assoc)
    [
      ";#{assoc}:",
      csv_edge(edges, type, types) |> Enum.join(","),
    ]
  end

  defp csv_edge(edges, type, types) when is_list(edges) do
    Enum.map(edges, fn edge -> "#{types[type]}.#{edge}" end)
  end
  defp csv_edge(edge, type, types) do
    ["#{types[type]}.#{edge}"]
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
        dot_node_properties(node),
        "\"];\n",
      ]
    end)
  end

  defp dot_node_properties(%{__struct__: struct} = node) do
    props = struct.__schema__(:properties)
    Enum.map(props, fn property_name ->
      value = Map.fetch!(node, property_name)
      "#{property_name}: #{value}\\l"
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

  # GraphViz Meta Dot

  # repo |> repo_meta_to_dot() |> Enum.into(File.stream!("meta.dot"))
  # dot -Tpng -ometa.png meta.dot
  def repo_meta_to_dot(repo) do
    [
      "digraph #{dot_id(repo)} {\n",
      "  node [shape=record fontname=Arial];\n",

      meta_dot_types(repo),
      meta_dot_edges(repo),

      "  label=\"#{repo}\";\n",
      "}\n",
    ]
  end

  defp meta_dot_types(repo) do
    aliases = repo.type_aliases()
    types = repo.types()
    Enum.map(types, fn type ->
      [
        "  #{dot_id(aliases[type])}  [label=\"#{aliases[type]}\\l\\l",
        meta_dot_properties(type),
        "\"];\n",
      ]
    end)
  end

  defp meta_dot_properties(type) do
    props = type.__schema__(:properties)
    Enum.map(props, fn property_name ->
      index = case type.__schema__(:index, property_name) do
        :primary -> "(primary)"
        :unique -> "(unique)"
        true -> "(index)"
        false -> ""
      end
      "#{property_name} #{index}\\l"
    end)
  end

  defp meta_dot_edges(repo) do
    types = repo.types()
    Enum.map(types, &meta_dot_edges(repo, &1))
  end

  defp meta_dot_edges(repo, type) do
    aliases = repo.type_aliases()
    assocs = type.__schema__(:associations)
    Enum.map(assocs, fn assoc ->
      target = type.__schema__(:type, assoc)
      "  #{dot_id(aliases[type])} -> #{dot_id(aliases[target])} [label=\"#{assoc}\"];\n"
    end)
  end

  # helper

  defp dot_id(name) do
    name |> to_string |> String.replace(".", "_")
  end

  defp dot_id(name, id) do
    "#{name}.#{id}" |> dot_id
  end
end
