defmodule Gim.Repo.Table do
  @moduledoc """
  Defines a typed table of nodes.

  A repository holds each distinct node type in a typed Table.
  """

  defmacro __using__(opts) do
    type = Keyword.get(opts, :type)
    uindexes = Keyword.get(opts, :uindexes, [])
    nindexes = Keyword.get(opts, :nindexes, [])

    quote bind_quoted: [type: type, uindexes: uindexes, nindexes: nindexes] do
      indexes = uindexes ++ nindexes

      def type(), do: unquote(type)
      def uindexes(), do: unquote(uindexes)
      def nindexes(), do: unquote(nindexes)
      def indexes(), do: unquote(indexes)

      defstruct [:nodes] ++ uindexes ++ nindexes
      alias __MODULE__, as: Table

      def new() do
        table = %Table{}

        table = Enum.reduce(unquote(indexes), table, fn index, table ->
          itab_name = Module.concat(__MODULE__, index)
          itab = case :ets.whereis(itab_name) do
            :undefined  -> :ets.new(itab_name, [:named_table, :duplicate_bag]) |> :ets.whereis()
            ref -> ref
          end
          %{table | index => itab}
        end)

        tab_name = Module.concat(__MODULE__, :nodes)
        tab = case :ets.whereis(tab_name) do
          :undefined  -> :ets.new(tab_name, [:named_table, :set]) |> :ets.whereis()
          ref -> ref
        end

        %{table | nodes: tab}
      end

      defp lookup_element(tab, key) do
        try do
          :ets.lookup_element(tab, key, 2)
        rescue
          ArgumentError -> []
        end
      end

      def all(%Table{nodes: tab} = _table) do
        :ets.foldl(fn {_id, value} -> value end, [], tab)
      end

      def fetch!(%Table{nodes: tab} = _table, id) when is_list(id) do
        Enum.map(id, &:ets.lookup_element(tab, &1, 2))
      end
      def fetch!(%Table{nodes: tab} = _table, id) do
        :ets.lookup_element(tab, id, 2)
      end

      def get_by(%Table{nodes: nodes} = table, key, value) do
        nodes
        |> Enum.filter(fn
          {_, %{^key => ^value}} -> true
          _ -> false
        end)
        |> Enum.map(&elem(&1, 1)) # or is Map.values() faster?
      end

      for index <- uindexes do
        def get(%Table{:nodes => tab, unquote(index) => itab} = _table, unquote(index), value) do
          lookup_element(itab, value)
          |> Enum.map(&:ets.lookup_element(tab, &1, 2))
        end
      end
      for index <- nindexes do
        def get(%Table{:nodes => tab, unquote(index) => itab} = _table, unquote(index), value) do
          lookup_element(itab, value)
          |> Enum.map(&:ets.lookup_element(tab, &1, 2))
        end
      end
      def get(_table, _index, _value) do
        nil # no such index
      end

      def insert(%Table{nodes: tab} = table, %{__id__: nil} = node) do
        # assign automatic id
        id = :ets.update_counter(tab, :__autoid__, 1, {nil, 0})
        node = Map.put(node, :__id__, id)

        # update the indexes
        Enum.map(unquote(uindexes), fn index ->
          %{^index => attr} = node
          %{^index => itab} = table
          # TODO: error on dup: Map.get(newindex, attr) != nil
          :ets.insert(itab, {attr, id})
        end)
        Enum.map(unquote(nindexes), fn index ->
          %{^index => attr} = node
          %{^index => itab} = table
          :ets.insert(itab, {attr, id})
        end)

        # actually insert the node
        :ets.insert(tab, {id, node})
        node
      end
      def insert(%Table{} = _table, %{__id__: _} = _node) do
        raise "Can't insert existing node"
      end

      def update(%Table{} = _table, %{__id__: nil} = _node) do
        raise "Can't update new node"
      end
      def update(%Table{nodes: tab} = table, %{__id__: id} = node) do
        # fetch the stored node to get the currently indexed attributes
        oldnode = :ets.lookup_element(tab, id, 2)

        # update the indexes
        Enum.map(unquote(uindexes), fn index ->
          %{^index => oldattr} = oldnode
          %{^index => attr} = node
          %{^index => itab} = table
          :ets.delete_object(itab, {oldattr, id})
          :ets.insert(itab, {attr, id})
        end)
        Enum.map(unquote(nindexes), fn index ->
          %{^index => oldattr} = oldnode
          %{^index => attr} = node
          %{^index => itab} = table
          :ets.delete_object(itab, {oldattr, id})
          :ets.insert(itab, {attr, id})
        end)

        # actually update the node
        :ets.insert(tab, {id, node}) # replace node
        :ok
      end

      def delete(%Table{} = _table, %{__id__: nil} = _node) do
        raise "Can't delete new node"
      end
      def delete(%Table{nodes: tab} = table, %{__id__: id} = _node) do
        # fetch the stored node to ensure we have the actual indexed attributes
        node = :ets.lookup_element(tab, id, 2)

        # update the indexes
        Enum.map(unquote(uindexes), fn index ->
          %{^index => attr} = node
          %{^index => itab} = table
          :ets.delete_object(itab, {attr, id})
        end)
        Enum.map(unquote(nindexes), fn index ->
          %{^index => attr} = node
          %{^index => itab} = table
          :ets.delete_object(itab, {attr, id})
        end)

        # actually delete the node
        :ets.delete(tab, id)
        :ok
      end

    end
  end
end
