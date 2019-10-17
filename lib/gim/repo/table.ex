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
      indexes_def = Enum.map(indexes, fn x -> {x, %{}} end)

      def type(), do: unquote(type)
      def uindexes(), do: unquote(uindexes)
      def nindexes(), do: unquote(nindexes)
      def indexes(), do: unquote(indexes)

      defstruct [autoid: 0, nodes: %{}] ++ indexes_def
      alias __MODULE__, as: Table

      def all(%Table{nodes: nodes} = _table) do
        nodes |> Map.values()
      end

      def fetch!(%Table{nodes: nodes} = _table, id) when is_list(id) do
        Enum.map(id, &Map.fetch!(nodes, &1))
      end
      def fetch!(%Table{nodes: nodes} = _table, id) do
        Map.fetch!(nodes, id)
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
        def get(%Table{:nodes => nodes, unquote(index) => index} = _table, unquote(index), value) do
          case Map.get(index, value) do
            nil -> []
            x -> [Map.fetch!(nodes, x)]
          end
        end
      end
      for index <- nindexes do
        def get(%Table{:nodes => nodes, unquote(index) => index} = _table, unquote(index), value) do
          index
          |> Map.get(value, [])
          |> Enum.map(&Map.fetch!(nodes, &1))
        end
      end
      def get(_table, _index, _value) do
        nil # no such index
      end

      def insert(%Table{autoid: autoid, nodes: nodes} = table, %{__id__: nil} = node) do
        # assign automatic id
        {autoid, id} = {autoid + 1, autoid}
        node = Map.put(node, :__id__, id)

        # update the indexes
        table = Enum.reduce(unquote(uindexes), table, fn index, table ->
          %{^index => attr} = node
          %{^index => newindex} = table
          # TODO: error on dup: Map.get(newindex, attr) != nil
          newindex = Map.put(newindex, attr, id)
          %{table | index => newindex}
        end)
        table = Enum.reduce(unquote(nindexes), table, fn index, table ->
          %{^index => attr} = node
          %{^index => newindex} = table
          newindex = Map.update(newindex, attr, [id], fn x -> [id | x] end)
          %{table | index => newindex}
        end)

        # actually insert the node
        nodes = Map.put(nodes, id, node)
        {%{table | autoid: autoid, nodes: nodes}, node}
      end
      def insert(%Table{} = _table, %{__id__: _} = _node) do
        raise "Can't insert existing node"
      end

      def update(%Table{} = _table, %{__id__: nil} = _node) do
        raise "Can't update new node"
      end
      def update(%Table{nodes: nodes} = table, %{__id__: id} = node) do
        # fetch the stored node to get the currently indexed attributes
        oldnode = Map.fetch!(nodes, id)

        # update the indexes
        table = Enum.reduce(unquote(uindexes), table, fn index, table ->
          %{^index => oldattr} = oldnode
          %{^index => attr} = node
          %{^index => newindex} = table
          newindex = Map.delete(newindex, oldattr)
          newindex = Map.put(newindex, attr, id)
          %{table | index => newindex}
        end)
        table = Enum.reduce(unquote(nindexes), table, fn index, table ->
          %{^index => oldattr} = oldnode
          %{^index => attr} = node
          %{^index => newindex} = table
          newindex = Map.update!(newindex, oldattr, fn x -> List.delete(x, id) end)
          newindex = Map.update(newindex, attr, [id], fn x -> [id | x] end)
          %{table | index => newindex}
        end)

        # actually update the node
        nodes = Map.put(nodes, id, node)
        %{table | nodes: nodes}
      end

      def delete(%Table{} = _table, %{__id__: nil} = _node) do
        raise "Can't delete new node"
      end
      def delete(%Table{nodes: nodes} = table, %{__id__: id} = _node) do
        # fetch the stored node to ensure we have the actual indexed attributes
        node = Map.fetch!(nodes, id)

        # update the indexes
        table = Enum.reduce(unquote(uindexes), table, fn index, table ->
          %{^index => attr} = node
          %{^index => newindex} = table
          newindex = Map.delete(newindex, attr)
          %{table | index => newindex}
        end)
        table = Enum.reduce(unquote(nindexes), table, fn index, table ->
          %{^index => attr} = node
          %{^index => newindex} = table
          newindex = Map.update!(newindex, attr, fn x -> List.delete(x, id) end)
          %{table | index => newindex}
        end)

        # actually delete the node
        nodes = Map.delete(nodes, id)
        %{table | nodes: nodes}
      end

    end
  end
end
