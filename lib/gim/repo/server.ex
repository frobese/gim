defmodule Gim.Repo.Server do
  @moduledoc false
  use GenServer

  alias Gim.Query
  alias Gim.Index

  @impl true
  def init(args) do
    with {:ok, module} <- Keyword.fetch(args, :module),
         {:ok, types} <- Keyword.fetch(args, :types),
         {:ok, table_module} <- Keyword.fetch(args, :table) do
      tables =
        Enum.into(types, %{}, fn type ->
          reference = Module.concat(module, type)
          table = table_module.new(reference, type)
          {type, {reference, table_module, table}}
        end)

      {:ok, struct(module, tables)}
    end
  end

  # Server

  @impl true
  def handle_call({:state}, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:all}, _from, state) do
    nodes =
      for {_type, {_, module, table}} <- state do
        {:ok, nodes} = module.query(table, nil, [])
        nodes
      end
      |> List.flatten()

    {:reply, nodes, state}
  end

  def handle_call({:resolve, %Query{type: type, filter: filter}}, _from, state) do
    case Map.fetch(state, type) do
      {:ok, {_, module, table}} ->
        {:reply, module.query(table, nil, filter), state}

      :error ->
        {:reply, {:error, %Gim.NoSuchTypeError{message: "No such Type #{inspect(type)}"}}, state}
    end
  end

  def handle_call({:insert, %{__struct__: type} = node}, _from, %repo{} = state) do
    case Map.fetch(state, type) do
      {:ok, {_, module, table}} ->
        node = %{node | __repo__: repo}
        node = module.insert(table, node)

        reflect_assocs(state, node)
        {:reply, {:ok, node}, state}

      :error ->
        {:reply, {:error, %Gim.NoSuchTypeError{message: "No such Type #{inspect(type)}"}}, state}
    end
  end

  def handle_call({:merge, node}, _from, state) do
    {:reply, update(state, node, merge: true), state}
  end

  def handle_call({:update, node}, _from, state) do
    {:reply, update(state, node), state}
  end

  def handle_call({:delete, %{__struct__: type, __id__: _id} = node}, _from, state) do
    case Map.fetch(state, type) do
      {:ok, {_, module, table}} ->
        module.delete(table, node)

        {:reply, :ok, state}

      :error ->
        {:reply, {:error, %Gim.NoSuchTypeError{message: "No such Type #{inspect(type)}"}}, state}
    end
  end

  defp get!(state, type, id) do
    {_, module, table} = Map.fetch!(state, type)
    {:ok, [node]} = module.query(table, [id], [])
    node
  end

  defp update(state, %{__struct__: type, __id__: id} = node, opts \\ []) do
    with {:ok, {_, module, table}} <- Map.fetch(state, type),
         {:ok, [old_node]} <- module.query(table, [id], []) do
      node =
        if Keyword.get(opts, :merge, false) do
          node_merge(old_node, node)
        else
          node
        end

      module.update(table, node)

      if Keyword.get(opts, :reflect, true), do: reflect_assocs(state, node, old_node)
      {:ok, node}
    else
      :error ->
        {:error, %Gim.NoSuchTypeError{message: "No such Type #{inspect(type)}"}}

      {:ok, []} ->
        {:error,
         %Gim.NoNodeError{message: "No Node found for #{inspect(type)} with id #{inspect(id)}"}}
    end
  end

  defp node_merge(%{__struct__: struct} = old, %{__struct__: struct} = node) do
    assocs = struct.__schema__(:associations)

    Enum.reduce(assocs, node, fn assoc, node ->
      case struct.__schema__(:association, assoc) do
        {_, :one, _, _} ->
          Map.update!(node, assoc, fn id -> id || Map.get(old, assoc, nil) end)

        {_, :many, _, _} ->
          Map.update!(node, assoc, fn ids -> Index.join(ids, Map.get(old, assoc, [])) end)
      end
    end)
  end

  defp reflect_assocs(state, %struct{} = node) do
    reflect_assocs(state, node, struct!(struct))
  end

  defp reflect_assocs(state, %struct{} = node, old_node) do
    Enum.each(struct.__schema__(:associations), fn assoc ->
      case struct.__schema__(:association, assoc) do
        {_assoc, :one, type, reflect} ->
          new_id = Map.fetch!(node, assoc)
          old_id = Map.fetch!(old_node, assoc)

          unless old_id == new_id do
            unless is_nil(old_id) do
              reflect_node = Query.delete_edge(get!(state, type, old_id), reflect, old_node)

              update(state, reflect_node, reflect: false)
            end

            unless is_nil(new_id) do
              reflect_node = Query.add_edge(get!(state, type, new_id), reflect, node)

              update(state, reflect_node, reflect: false)
            end
          end

        {_assoc, :many, type, reflect} ->
          new_ids = Map.fetch!(node, assoc)
          old_ids = Map.fetch!(old_node, assoc)

          {added, removed} = Index.difference(new_ids, old_ids)

          Enum.each(removed, fn old_id ->
            reflect_node = Query.delete_edge(get!(state, type, old_id), reflect, old_node)

            update(state, reflect_node, reflect: false)
          end)

          Enum.each(added, fn new_id ->
            reflect_node = Query.add_edge(get!(state, type, new_id), reflect, node)

            update(state, reflect_node, reflect: false)
          end)
      end
    end)
  end
end
