defmodule Gim.Repo.Table.Ets do
  use Gim.Repo.Table
  # defstruct [
  #   :ref,
  #   :uindexes,
  #   :nindexes,
  #   :table
  # ]

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
    :ets.foldl(fn {_id, value}, acc -> [value | acc] end, [], nodes)
  end

  def query(%{nodes: nodes}, ids, []) when is_list(ids) do
    Enum.map(ids, &:ets.lookup_element(nodes, &1, 2))

    # :ets.foldl(fn {id, value}, acc -> if(id in ids, do: [value | acc], else: acc) end, [], nodes)
  end

  def query(table, nil, filter) do
    query(table, filter(table, filter), [])
  end

  ### Legacy Api
  def all(table) do
    query(table, nil, [])
  end

  def fetch(table, id) do
    table
    |> query([id], [])
    |> List.first()
  end

  def fetch!(table, id) do
    table
    |> query([id], [])
    |> List.first()
  end

  def get_by(table, field, value) do
    query(table, nil, [{field, value}])
  end

  def get(table, field, value) do
    query(table, nil, [{field, value}])
  end

  ### Helper

  defp index_add(%{__uindexes__: uidx, __nindexes__: nidx} = table, %{__id__: id} = node) do
    Enum.each(uidx, fn index ->
      %{^index => attr} = node
      %{^index => itab} = table
      :ets.insert(itab, {attr, id})
    end)

    Enum.each(nidx, fn index ->
      %{^index => attr} = node
      %{^index => itab} = table

      index =
        case :ets.lookup(itab, attr) do
          [] -> [id]
          [{_, ids}] -> Enum.sort([id | ids])
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
          :ets.insert(itab, {attr, List.delete(ids, id)})

        [] ->
          []
      end
    end)
  end

  defp index_lookup(table, index, attr) do
    %{^index => itab} = table

    case :ets.lookup(itab, attr) do
      [{_attr, ids}] -> ids
      [] -> []
    end
  end

  defp filter(table, filter, acc \\ [])

  defp filter(table, [{field, value} | filter], acc) do
    ids = List.wrap(index_lookup(table, field, value))

    filter(table, filter, ids ++ acc)
  end

  defp filter(_table, [], acc) do
    Enum.uniq(acc)
  end
end
