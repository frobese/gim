defmodule Gim.Repo.Table.LegacyEts do
  use Gim.Repo.Table

  @moduledoc """
  Defines a typed table of nodes.

  A repository holds each distinct node type in a typed Table.
  """

  def type(%{__type__: type}), do: type
  def uindexes(%{__uindexes__: uindexes}), do: uindexes
  def nindexes(%{__nindexes__: nindexes}), do: nindexes
  def indexes(%{__uindexes__: uindexes, __nindexes__: nindexes}), do: uindexes ++ nindexes

  def names(_table) do
    # TODO: should :ets.whereis/1
    raise "not implemented"
  end

  def new(reference, type) do
    uindexes = type.__schema__(:indexes_unique)
    nindexes = type.__schema__(:indexes_non_unique)

    table = %{
      __type__: type,
      __uindexes__: uindexes,
      __nindexes__: nindexes
    }

    table =
      Enum.reduce(uindexes ++ nindexes, table, fn index, table ->
        itab_name = Module.concat(reference, index)

        itab =
          case :ets.whereis(itab_name) do
            :undefined ->
              :ets.new(itab_name, [:public, :named_table, :duplicate_bag]) |> :ets.whereis()

            ref ->
              ref
          end

        Map.put(table, index, itab)
      end)

    tab_name = Module.concat(reference, :nodes)

    tab =
      case :ets.whereis(tab_name) do
        :undefined -> :ets.new(tab_name, [:public, :named_table, :set]) |> :ets.whereis()
        ref -> ref
      end

    Map.put(table, :nodes, tab)
  end

  defp lookup_element(tab, key) do
    try do
      :ets.lookup_element(tab, key, 2)
    rescue
      ArgumentError -> []
    end
  end

  # def all() do
  #   tab = Module.concat(__MODULE__, :nodes)
  #   :ets.foldl(fn {_id, value}, acc -> [value | acc] end, [], tab)
  # end

  def all(%{nodes: tab} = _table) do
    :ets.foldl(
      fn {id, value}, acc -> if(id != :__autoid__, do: [value | acc], else: acc) end,
      [],
      tab
    )
  end

  # def fetch!(id) when is_list(id) do
  #   tab = Module.concat(__MODULE__, :nodes)
  #   Enum.map(id, &:ets.lookup_element(tab, &1, 2))
  # end

  # def fetch!(id) do
  #   tab = Module.concat(__MODULE__, :nodes)
  #   :ets.lookup_element(tab, id, 2)
  # end

  def fetch!(%{nodes: tab} = _table, id) when is_list(id) do
    Enum.map(id, &:ets.lookup_element(tab, &1, 2))
  end

  def fetch!(%{nodes: tab} = _table, id) do
    :ets.lookup_element(tab, id, 2)
  end

  #      def fetch(%Table{nodes: nodes} = _table, id) do
  #        Map.fetch(nodes, id)
  #      end

  def get_by(table, key, value) do
    table
    |> all()
    |> Enum.filter(fn
      %{^key => ^value} -> true
      _ -> false
    end)

    # or is Map.values() faster?
    # |> Enum.map(&elem(&1, 1))
  end

  # for index <- uindexes do
  #   def get(unquote(index), value) do
  #     itab = Module.concat(__MODULE__, unquote(index))
  #     tab = Module.concat(__MODULE__, :nodes)

  #     lookup_element(itab, value)
  #     |> Enum.map(&:ets.lookup_element(tab, &1, 2))
  #   end

  def get(%{nodes: tab} = table, index, value) do
    table
    |> Map.get(index)
    |> lookup_element(value)
    |> Enum.map(&:ets.lookup_element(tab, &1, 2))
  end

  # end

  # for index <- nindexes do
  #   def get(unquote(index), value) do
  #     itab = Module.concat(__MODULE__, unquote(index))
  #     tab = Module.concat(__MODULE__, :nodes)

  #     lookup_element(itab, value)
  #     |> Enum.map(&:ets.lookup_element(tab, &1, 2))
  #   end

  #   def get(%Table{:nodes => tab, unquote(index) => itab} = _table, unquote(index), value) do
  #     lookup_element(itab, value)
  #     |> Enum.map(&:ets.lookup_element(tab, &1, 2))
  #   end
  # end

  # def get(_table, _index, _value) do
  #   # no such index
  #   nil
  # end

  # def insert(node) do
  #   insert(@table_aliases, node)
  # end

  def insert(%{nodes: tab} = table, %{__id__: nil} = node) do
    # assign automatic id
    id = :ets.update_counter(tab, :__autoid__, 1, {nil, 0})
    node = Map.put(node, :__id__, id)

    # update the indexes
    Enum.map(table.__uindexes__, fn index ->
      %{^index => attr} = node
      %{^index => itab} = table
      # TODO: error on dup: Map.get(newindex, attr) != nil
      :ets.insert(itab, {attr, id})
    end)

    Enum.map(table.__nindexes__, fn index ->
      %{^index => attr} = node
      %{^index => itab} = table
      :ets.insert(itab, {attr, id})
    end)

    # actually insert the node
    :ets.insert(tab, {id, node})
    node
  end

  def insert(%{} = _table, %{__id__: _} = _node) do
    raise "Can't insert existing node"
  end

  # def update(node) do
  #   update(@table_aliases, node)
  # end

  def update(%{} = _table, %{__id__: nil} = _node) do
    raise "Can't update new node"
  end

  def update(%{nodes: tab} = table, %{__id__: id} = node) do
    # fetch the stored node to get the currently indexed attributes
    oldnode = :ets.lookup_element(tab, id, 2)

    # update the indexes
    Enum.map(table.__uindexes__, fn index ->
      %{^index => oldattr} = oldnode
      %{^index => attr} = node
      %{^index => itab} = table
      :ets.delete_object(itab, {oldattr, id})
      :ets.insert(itab, {attr, id})
    end)

    Enum.map(table.__nindexes__, fn index ->
      %{^index => oldattr} = oldnode
      %{^index => attr} = node
      %{^index => itab} = table
      :ets.delete_object(itab, {oldattr, id})
      :ets.insert(itab, {attr, id})
    end)

    # actually update the node
    # replace node
    :ets.insert(tab, {id, node})
    :ok
  end

  # def delete(node) do
  #   delete(@table_aliases, node)
  # end

  def delete(%{} = _table, %{__id__: nil} = _node) do
    raise "Can't delete new node"
  end

  def delete(%{nodes: tab} = table, %{__id__: id} = _node) do
    # fetch the stored node to ensure we have the actual indexed attributes
    node = :ets.lookup_element(tab, id, 2)

    # update the indexes
    Enum.map(table.__uindexes__, fn index ->
      %{^index => attr} = node
      %{^index => itab} = table
      :ets.delete_object(itab, {attr, id})
    end)

    Enum.map(table.__nindexes__, fn index ->
      %{^index => attr} = node
      %{^index => itab} = table
      :ets.delete_object(itab, {attr, id})
    end)

    # actually delete the node
    :ets.delete(tab, id)
    :ok
  end
end
