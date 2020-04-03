defmodule Gim.Repo.Table.Ets do
  use Gim.Repo.Table
  # defstruct [
  #   :ref,
  #   :uindexes,
  #   :nindexes,
  #   :table
  # ]
  import Gim.Repo.Index

  def new(reference, type) do
    uindexes = type.__schema__(:indexes_unique)
    nindexes = type.__schema__(:indexes_non_unique)

    table = %{
      __type__: type,
      __uindexes__: uindexes,
      __nindexes__: nindexes,
      __meta__: nil
    }

    # table =
    Enum.reduce([:__meta__, :nodes] ++ uindexes ++ nindexes, table, fn index, table ->
      itab_name = Module.concat(reference, index)

      itab =
        case :ets.whereis(itab_name) do
          :undefined ->
            itab_name
            |> :ets.new([:public, :named_table, :set])
            |> :ets.whereis()

          ref ->
            ref
        end

      Map.put(table, index, itab)
    end)

    # tab_name = Module.concat(__MODULE__, :nodes)

    # tab =
    #   case :ets.whereis(tab_name) do
    #     :undefined ->
    #       tab_name
    #       |> :ets.new([:public, :named_table, :set])
    #       |> :ets.whereis()

    #     ref ->
    #       ref
    #   end

    # Map.put(table, :nodes, tab)
  end

  def insert(%{nodes: tab, __meta__: meta} = table, node) do
    # assign automatic id
    id = :ets.update_counter(meta, :__autoid__, 1, {nil, 0})
    node = Map.put(node, :__id__, id)

    # update the indexes
    index_add(table, node)

    # actually insert the node
    :ets.insert(tab, {id, node})
    node
  end

  def update(%{nodes: nodes} = table, %{__id__: id} = node) do
    # fetch the stored node to get the currently indexed attributes
    oldnode = :ets.lookup_element(nodes, id, 2)

    # update the indexes
    index_remove(table, oldnode)
    index_add(table, node)

    # actually update the node
    # replace node
    :ets.insert(nodes, {id, node})

    node
  end

  def delete(%{nodes: nodes} = table, %{__id__: id} = node) do
    index_remove(table, node)
    :ets.delete(nodes, id)
    :ok
  end

  def query(table, ids, filter)

  def query(%{nodes: nodes}, nil, []) do
    {:ok, :ets.foldl(fn {_id, value}, acc -> [value | acc] end, [], nodes)}
  end

  def query(_, [], _) do
    {:ok, []}
  end

  def query(%{nodes: nodes}, ids, []) when is_list(ids) do
    nodes =
      Enum.reduce(ids, [], fn id, acc ->
        case :ets.lookup(nodes, id) do
          [{_, elem}] -> [elem | acc]
          [] -> acc
        end
      end)

    {:ok, nodes}
  end

  def query(table, nil, filter) do
    case filter(table, filter) do
      {:ok, ids} ->
        query(table, ids, [])

      err ->
        err
    end
  end

  def query(table, ids, filter) when is_list(ids) or is_nil(ids) do
    case filter(table, filter) do
      {:ok, filter_ids} ->
        query(table, intersect(new(ids), filter_ids), [])

      err ->
        err
    end
  end

  ### Helper
  defp index_add(%{__uindexes__: uidx, __nindexes__: nidx} = table, %{__id__: id} = node) do
    Enum.each(uidx, fn index ->
      %{^index => attr} = node
      %{^index => itab} = table
      :ets.insert(itab, {attr, [id]})
    end)

    Enum.each(nidx, fn index ->
      %{^index => attr} = node
      %{^index => itab} = table

      index =
        case :ets.lookup(itab, attr) do
          [] -> [id]
          [{_, ids}] -> add(ids, id)
        end

      :ets.insert(itab, {attr, index})
    end)
  end

  defp index_remove(%{__uindexes__: uidx, __nindexes__: nidx} = table, %{__id__: id} = node) do
    Enum.each(uidx, fn index ->
      %{^index => attr} = node
      %{^index => itab} = table
      :ets.delete(itab, attr)
    end)

    Enum.each(nidx, fn index ->
      %{^index => attr} = node
      %{^index => itab} = table

      case :ets.lookup(itab, attr) do
        [{_, [^id]}] ->
          :ets.delete(itab, attr)

        [{_, ids}] ->
          :ets.insert(itab, {attr, remove(ids, id)})

        [] ->
          []
      end
    end)
  end

  defp index_lookup(table, index, function) when is_function(function, 1) do
    itab = Map.fetch!(table, index)

    :ets.foldl(
      fn {attr, ids}, acc -> if apply(function, [attr]), do: join(ids, acc), else: acc end,
      [],
      itab
    )
  end

  defp index_lookup(table, index, attr) do
    itab = Map.fetch!(table, index)

    case :ets.lookup(itab, attr) do
      [{_attr, ids}] -> ids
      [] -> []
    end
  end

  defp filter(table, filter) do
    {:ok, filter!(table, filter)}
  rescue
    e in Gim.NoIndexError -> {:error, e}
  end

  defp filter!(table, {:or, filter}) do
    Enum.reduce(filter, [], fn filter, acc ->
      join(filter!(table, filter), acc)
    end)
  end

  defp filter!(table, {:and, filter}) do
    Enum.reduce_while(filter, nil, fn filter, acc ->
      case acc do
        [] -> {:halt, []}
        nil -> {:cont, filter!(table, filter)}
        acc -> {:cont, intersect(filter!(table, filter), acc)}
      end
    end)
  end

  defp filter!(_table, {:__id__, id}) do
    [id]
  end

  defp filter!(table, {field, value}) do
    index_lookup(table, field, value)
  rescue
    KeyError ->
      raise Gim.NoIndexError,
            "Unable to filter #{inspect(field)} in #{inspect(table.__type__)} by #{inspect(value)}"
  end

  defp filter!(table, filter) when is_list(filter) do
    filter!(table, {:and, filter})
  end
end
