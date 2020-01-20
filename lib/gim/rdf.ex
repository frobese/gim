defmodule Gim.Rdf do
  @moduledoc """
  Terse RDF Triple Language (Turtle) import and export for Gim.
  """

  # Import Terse RDF Triple Language (Turtle)

  # "1million.rdf.gz" |> File.stream!([:compressed]) |> Gim.Rdf.read_rdf()
  @doc """
  Read Terse RDF Triple Language (Turtle) format from a stream.
  `pfun` is an optional predicate mapping function.
  """
  def read_rdf(stream, pfun \\ &String.to_atom/1) do
    stream
    |> Stream.map(&tokenize(pfun, &1))
    |> Enum.reduce(%{}, &rdf_to_map/2)
  end

  @doc """
  Stream raw Terse RDF Triple Language (Turtle) format from a stream.
  `pfun` is an optional predicate mapping function.
  """
  def stream_rdf(stream, pfun \\ &String.to_atom/1) do
    stream
    |> Stream.map(&tokenize(pfun, &1))
  end

  # Raw RDF token to RDF map

  defp rdf_to_map(:blank, acc), do: acc
  defp rdf_to_map({:comment, _}, acc), do: acc
  defp rdf_to_map({subject, predicate, object}, acc) do
    Map.update(acc, subject, [{predicate, object}], fn x ->
      [{predicate, object} | x]
    end)
  end

  # Tokenize RDF string data

  defp tokenize(_pfun, <<>>), do: :blank
  defp tokenize(_pfun, <<"\n">>), do: :blank
  defp tokenize(_pfun, <<"\r\n">>), do: :blank
  defp tokenize(pfun, <<" ", rest::binary>>), do: tokenize(pfun, rest)
  defp tokenize(pfun, <<"\t", rest::binary>>), do: tokenize(pfun, rest)
  defp tokenize(_pfun, <<"#", rest::binary>>), do: tokenize_comment(rest)
  defp tokenize(pfun, <<"<", rest::binary>>), do: tokenize_tag1(pfun, rest)

  defp tokenize_comment(<<>>), do: {:comment, nil}
  defp tokenize_comment(<<"\n">>), do: {:comment, nil}
  defp tokenize_comment(<<"\r\n">>), do: {:comment, nil}
  defp tokenize_comment(<<" ", rest::binary>>), do: tokenize_comment(rest)
  defp tokenize_comment(<<"\t", rest::binary>>), do: tokenize_comment(rest)
  defp tokenize_comment(<<"-", rest::binary>>), do: tokenize_comment(rest)
  defp tokenize_comment(rest) do
    [comment, _rest] = :binary.split(rest, " --")
    {:comment, comment}
  end

  # subject, predicate, object
  defp tokenize_tag1(pfun, rest) do
    [subject, rest] = :binary.split(rest, ">")
    tokenize_predicate(pfun, subject, rest)
  end

  #defp tokenize_predicate(pfun, _subject, <<>>), do: :error
  #defp tokenize_predicate(pfun, _subject, <<"\n">>), do: :error
  #defp tokenize_predicate(pfun, _subject, <<"\r\n">>), do: :error
  defp tokenize_predicate(pfun, subject, <<" ", rest::binary>>), do: tokenize_predicate(pfun, subject, rest)
  defp tokenize_predicate(pfun, subject, <<"\t", rest::binary>>), do: tokenize_predicate(pfun, subject, rest)
  defp tokenize_predicate(pfun, subject, <<"<", rest::binary>>), do: tokenize_tag2(pfun, subject, rest)

  defp tokenize_tag2(pfun, subject, rest) do
    [predicate, rest] = :binary.split(rest, ">")
    tokenize_object(subject, pfun.(predicate), rest)
  end

  #defp tokenize_object(_subject, _predicate, <<>>), do: :error
  #defp tokenize_object(_subject, _predicate, <<"\n">>), do: :error
  #defp tokenize_object(_subject, _predicate, <<"\r\n">>), do: :error
  defp tokenize_object(subject, predicate, <<" ", rest::binary>>), do: tokenize_object(subject, predicate, rest)
  defp tokenize_object(subject, predicate, <<"\t", rest::binary>>), do: tokenize_object(subject, predicate, rest)
  defp tokenize_object(subject, predicate, <<"<", rest::binary>>), do: tokenize_tag3(subject, predicate, rest)
  defp tokenize_object(subject, predicate, <<"\"", rest::binary>>), do: tokenize_text3(subject, predicate, rest)

  defp tokenize_tag3(subject, predicate, rest) do
    [object, _rest] = :binary.split(rest, ">")
    # just discard what's left of the line (the end dot)
    {subject, predicate, object}
  end

  defp tokenize_text3(subject, predicate, rest) do
    [object, rest] = :binary.split(rest, "\"")
    tokenize_text3(subject, predicate, object, rest)
  end
  # just discard what's left of the line (end dot) and assume @en if missing
  defp tokenize_text3(subject, predicate, object, <<"@en", _::binary>>),
    do: {subject, predicate, {:en, object}}
  defp tokenize_text3(subject, predicate, object, <<"@de", _::binary>>),
    do: {subject, predicate, {:de, object}}
  defp tokenize_text3(subject, predicate, object, <<"@it", _::binary>>),
    do: {subject, predicate, {:it, object}}
  defp tokenize_text3(subject, predicate, object, _),
    do: {subject, predicate, {:en, object}}

  # Export Terse RDF Triple Language (Turtle)

  # repo |> Gim.Rdf.write_rdf() |> Enum.into(File.stream!("dump.rdf.gz", [:compressed]))
  def write_rdf(repo) do
    aliases = repo.type_aliases()
    types = repo.types()
    [
      "# -- Gim RDF export of #{repo} --\n",
      Enum.map(types, &rdf_nodes(repo, &1, aliases)),
    ]
  end

  defp rdf_nodes(repo, type, aliases) do
    nodes = repo.all!(type)
    [
      "\n# -- #{aliases[type]} --\n\n",
      Enum.map(nodes, &rdf_node(&1, aliases)),
    ]
  end

  defp rdf_node(%{__struct__: struct, __id__: id} = node, aliases) do
    props = struct.__schema__(:properties)
    assocs = struct.__schema__(:associations)
    subject = "<#{aliases[struct]}.#{id}>"
    [
      "#{subject} <gim.type> \"#{aliases[struct]}\" .\n",
      Enum.map(props, &rdf_property(subject, node, &1)),
      Enum.map(assocs, &rdf_edges(subject, node, &1, aliases)),
    ]
  end

  defp rdf_property(subject, node, property_name) do
    %{^property_name => value} = node
    "#{subject} <#{property_name}> #{inspect value} .\n"
  end

  defp rdf_edges(subject, %{__struct__: struct} = node, assoc, aliases) do
    type = struct.__schema__(:type, assoc)
    type_alias = aliases[type]
    edges = Map.fetch!(node, assoc)
    predicate = "<#{assoc}>"
    rdf_edge(subject, predicate, type_alias, edges)
  end

  defp rdf_edge(subject, predicate, type_alias, edges) when is_list(edges) do
    Enum.map(edges, &rdf_edge(subject, predicate, type_alias, &1))
  end
  defp rdf_edge(subject, predicate, type_alias, edge) do
    "#{subject} #{predicate} <#{type_alias}.#{edge}> .\n"
  end
end
