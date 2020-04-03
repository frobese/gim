defmodule Gim.Repo.Export do
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
