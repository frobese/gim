defmodule Gim.Repo do
  @moduledoc """
  Defines a repository.

  A repository maps to an underlying data store hold in-memory.

  When used, the repository expects the `:types` as option.
  The `:types` is a list of schema types to register.
  For example, the repository:

      defmodule Repo do
        use Gim.Repo,
          types: [Author, Post]
      end

  """

  # https://github.com/elixir-ecto/ecto/blob/v3.2.5/lib/ecto/repo.ex

  @doc false
  defmacro __using__(opts) do
    types = Keyword.get(opts, :types, [])
    quote bind_quoted: [types: types] do
      use GenServer

      alias Gim.Query

      # for type <- types do
      #   ref = Module.concat(__MODULE__, type)
      #   uindexes = type.__schema__(:indexes_unique)
      #   nindexes = type.__schema__(:indexes_non_unique)
      #   defmodule ref do
      #     use Gim.Repo.Table, type: type, uindexes: uindexes, nindexes: nindexes
      #   end

      # end

      for type <- types do
        defguard is_type(type) when true
      end

      defguard is_type(_type) when false


      defmodule State do
        @moduledoc false
        defstruct types # Repo state consists of all type tables
      end

      @default_args [name: __MODULE__, table: Gim.Repo.Table.Ets]
      def start_link(args \\ []) do
        args = Keyword.merge(@default_args, args)
        GenServer.start_link(__MODULE__, args, name: args[:name], spawn_opt: [fullsweep_after: 50])
      end

      @impl true
      def init(args) do
        module = Keyword.get(args, :table)

        tables = Enum.into(unquote(types), %{}, fn type ->
          reference = Module.concat(__MODULE__, type)
          table = module.new(reference, type)
          {type, {reference, module, table}}
        end)

        {:ok, struct(State, tables)}
      end

      # Server

      @impl true
      def handle_call({:state}, _from, state) do
        {:reply, state, state}
      end

      @impl true
      def handle_call({:all}, _from, state) do
        nodes = for type <- unquote(types) do
          # ref = Module.concat(__MODULE__, type)
          %{^type => {_, module, table}} = state
          module.all(table)
        end |> List.flatten()

        {:reply, nodes, state}
      end

      @impl true
      def handle_call({:resolve, %Query{type: type, filter: filter}}, from, state) do
        case Map.fetch(state, type) do
          {:ok, {_, module, table}} ->
            {:reply, module.query(table, nil, filter), state}
          :error ->
            {:reply, {:error, Gim.NoSuchTypeError}, state}
        end
      end

      def handle_call({:insert, %{__struct__: type} = node}, _from, state) do
        case Map.fetch(state, type) do
          {:ok, {_, module, table}} ->
            node = %{node | __repo__: __MODULE__}
            node = module.insert(table, node)

            reflect_assocs(state, node)
            {:reply, node, state}
          :error ->
            {:reply, {:error, Gim.NoSuchTypeError}, state}
        end
      end

      @impl true
      def handle_cast({:update, %{__struct__: type} = node}, state) do
        case Map.fetch(state, type) do
          {:ok, {_, module, table}} ->
            module.update(table, node)

            reflect_assocs(state, node)
            {:noreply, state}
          :error ->
            {:reply, {:error, Gim.NoSuchTypeError}, state}
        end
      end

      @impl true
      def handle_call({:merge, %{__struct__: type, __id__: id} = node}, _from, state) do
        case Map.fetch(state, type) do
          {:ok, {_, module, table}} ->
            {:ok, [old]} = module.query(table, [id], [])
            node = node_merge(old, node)
            module.update(table, node)

            reflect_assocs(state, node)
            {:reply, node, state}
          :error ->
            {:reply, {:error, Gim.NoSuchTypeError}, state}
        end
      end

      @impl true
      def handle_cast({:delete, %{__struct__: type, __id__: _id} = node}, state) do
        case Map.fetch(state, type) do
          {:ok, {_, module, table}} ->
            module.delete(table, node)

            {:noreply, state}
          :error ->
            {:reply, {:error, Gim.NoSuchTypeError}, state}
        end
      end

      # Merge edges

      def node_merge(%{__struct__: struct} = old, %{__struct__: struct} = node) do
        assocs = struct.__schema__(:associations)
        Enum.reduce(assocs, node, fn assoc, node ->
          edge_merge(old, node, assoc)
        end)
      end

      def edge_merge(old, node, assoc) do
        #old_edges = Map.fetch!(old, assoc)
        #new_edges = Map.fetch!(node, assoc)
        %{^assoc => old_edges} = old
        %{^assoc => new_edges} = node
        edges = union_edge(old_edges, new_edges)
        %{node | assoc => edges}
      end

      # Reflect edges

      def reflect_assocs(node) do
        tables = unquote(types) |> Enum.into(%{}, fn type ->
          ref = Module.concat(__MODULE__, type)
          {type, ref.names()}
        end)

        reflect_assocs(tables, node)
      end

      def reflect_assocs(tables, %{__struct__: struct} = node) do
        assocs = struct.__schema__(:associations)
        Enum.each(assocs, fn assoc ->
          reflect_assoc(tables, node, assoc)
        end)
      end

      def reflect_assoc(tables, %{__struct__: struct, __id__: id} = node, assoc) do
        case struct.__schema__(:association, assoc) do
          nil -> :ok
          reflect ->
            type = struct.__schema__(:type, assoc)
#            IO.puts("Map.fetch(tables, type) #{inspect(type)} : #{inspect(Map.fetch(tables, type))}")
            {:ok, table} = Map.fetch(tables, type)
            targets = Map.fetch!(node, assoc)
            reflect_edge(type, table, reflect, id, targets)
        end
      end

      def reflect_edge(type, table, reflect, id, list) when is_list(list) do
        Enum.each(list, fn target ->
          reflect_edge(type, table, reflect, id, target)
        end)
      end
      def reflect_edge(_type, _table, _reflect, _id, nil) do
        :ok # unset single edge
      end
      for type <- types do
        # ref = Module.concat(__MODULE__, type)
        def reflect_edge(unquote(type), {ref, module, table}, reflect, id, target) do
#          case module.fetch(table, target) do
#            {:ok, node} ->
#              node = put_edge(node, reflect, id)
#              module.update(table, node)
#            _ ->
#              IO.puts("Missing node #{inspect module} #{inspect target} on reflect #{inspect reflect}, id #{inspect id}")
#              table
#          end
          {:ok, [node]} = module.query(table, [target], [])
          node = put_edge(node, reflect, id)
          module.update(table, node)
        end
      end

      def put_edge(node, edge, id) do
        x = Map.fetch!(node, edge)
        %{node | edge => union_edge(id, x)}
      end

      def union_edge(nil, other), do: other
      def union_edge(id, nil), do: id
      def union_edge(id, list) when is_list(list), do: list_put(list, id)
      def union_edge(_id, other), do: other # don't override existing edge

      def list_put(list, elems) when is_list(elems) do
        Enum.reduce(elems, list, fn elem, list ->
          list_put(list, elem)
        end)
      end
      def list_put(list, elem) do
        if Enum.any?(list, fn x -> x == elem end) do
          list
        else
          [elem | list]
        end
      end

      # API


      def types do
        unquote(types)
      end

      def dump do
        GenServer.call(__MODULE__, {:all})
      end

      defp resolve(%Gim.Query{type: type} = query) when is_type(type) do
        GenServer.call(__MODULE__, {:resolve, query})
      end

      def all(type) when is_type(type) do
        resolve(%Query{type: type})
      end

      def all!(type) when is_type(type) do
        case all(type) do
          {:ok, res} -> res
          {:error, exception} -> raise exception
        end
      end

      @doc """
      Get a node by a given edge, or list of nodes by given edges.
      """
      def fetch!(type, id) when is_type(type) do
        fetch!(type, :__id__, id)
      end

      def fetch_or(type, id) do
        case fetch!(type, id) do
          {:ok, res} -> res
          x when is_list(x) -> x
          x -> raise Gim.NoNodeError, "No such Node #{inspect x}"
        end
      end

      @doc """
      Get all nodes of a given type with key==value.
      Always returns a list.
      """
      def get_by(type, key, value) when is_type(type) do
        case all(type) do
          {:ok, res} ->
            Enum.filter(res, fn
              %{^key => ^value} -> true
              _ -> false
            end)
          err -> err
        end
      end

      @doc """
      Get all nodes of a given type by a given index value.
      Always returns a list.
      """
      def get(type, key, value) when is_type(type) do
        case resolve(%Query{type: type, filter: [{key, value}]}) do
          {:ok, nodes} -> nodes
          {:error, error} -> raise error
        end
      end

      @doc """
      Fetch a node of a given type by a given unique index value.
      Returns `{:ok, node}` or `{:error, _}`.
      """
      def fetch(type, key, value) do
        case get(type, key, value) do
          [node] -> {:ok, node}
          [] -> {:error, Gim.NoNodeError}
          _ -> {:error, Gim.MultipleNodesError}
        end
      end

      @doc """
      Fetch a node of a given type by a given unique index value.
      Returns the node or raises.
      """
      def fetch!(type, key, value) do
        case get(type, key, value) do
          [node] -> node
          [] -> raise Gim.NoNodeError, "No such Node"
          _ -> raise Gim.MultipleNodesError, "Multiple Nodes found"
        end
      end

      for type <- types do
        # ref = Module.concat(__MODULE__, type)
        assocs = type.__schema__(:associations)

        def create(%{unquote(type) => tables}, %{__struct__: unquote(type)} = node) do
          # remove all edges
          naked = Enum.reduce(unquote(assocs), node, fn assoc, node ->
            clear_edges(node, assoc)
          end)
          naked = %{naked | __repo__: __MODULE__}
          %{__id__: id, __repo__: repo} = insert(naked)

          %{node | __id__: id, __repo__: repo}
        end
      end

      def create(%{__struct__: struct} = node) do
        assocs = struct.__schema__(:associations)
        # remove all edges
        naked = Enum.reduce(assocs, node, fn assoc, node ->
          clear_edges(node, assoc)
        end)
        %{__id__: id, __repo__: repo} = GenServer.call(__MODULE__, {:insert, naked})
        # -or-
#        ref = Module.concat(__MODULE__, struct)
#        naked = %{naked | __repo__: __MODULE__}
#        %{__id__: id, __repo__: repo} = naked = ref.insert(naked)
#
#        #state = GenServer.call(__MODULE__, {:state})
#        #reflect_assocs(state, naked)

        %{node | __id__: id, __repo__: repo}
      end

      def clear_edges(node, assoc) do
        empty = case Map.fetch!(node, assoc) do
          list when is_list(list) -> []
          _ -> nil
        end
        Map.put(node, assoc, empty)
      end

      @doc """
      Insert a fresh node into the repo. The nodes must not have and id.
      """
      def insert(node, opts \\ []) do
        GenServer.call(__MODULE__, {:insert, node})
      end

      def insert!(node, opts \\ []) do
        case insert(node, opts) do
          {:ok, res} -> res
          x -> raise Gim.DuplicateNodeError, "Duplicate Node #{inspect x}"
        end
      end

      @doc """
      Update a node by replacing the attributes and edges.
      """
      def update(node, opts \\ []) do
        GenServer.cast(__MODULE__, {:update, node})
        node
      end

      @doc """
      Update a node by replacing the attributes and merging the edges.
      """
      for type <- types do
        # ref = Module.concat(__MODULE__, type)

        def merge(%{unquote(type) => {_, module, table}}, %{__struct__: unquote(type), __id__: id} = node) do
          {:ok, [old]} = module.query(table, [id], [])
          node = node_merge(old, node)
          module.update(table, node)
        end
      end

      def merge(node) do
        GenServer.call(__MODULE__, {:merge, node})
        # -or-
#        state = GenServer.call(__MODULE__, {:state})
#        merge(state, node)
#        reflect_assocs(state, node)
      end

      def merge!(node) do
        case merge(node) do
          {:ok, res} -> res
          x -> raise Gim.NoNodeError, "No such Node #{inspect x}"
        end
      end

      @doc """
      Deletes a node without consistency checks.
      """
      def delete(node, opts \\ []) do
        GenServer.cast(__MODULE__, {:delete, node})
      end

      # Import helper

      def resolve_node(%{__struct__: struct} = node, nodes, errors) do
        assocs = struct.__schema__(:associations)
        Enum.reduce(assocs, node, fn assoc, node ->
          links = Map.fetch!(node, assoc)
          %{node | assoc => resolve_assoc(links, nodes, errors)}
        end)
      end

      def resolve_assoc(links, nodes, errors) when is_list(links) do
        links
        |> Enum.map(fn link -> resolve_assoc(link, nodes, errors) end)
        |> Enum.reject(&is_nil/1)
      end
      def resolve_assoc(link, nodes, :ignore) when is_binary(link) do
        case Map.fetch(nodes, link) do
          {:ok, %{__id__: id}} -> id
          _ -> nil
        end
      end
      def resolve_assoc(link, nodes, _errors) when is_binary(link) do
        case Map.fetch(nodes, link) do
          {:ok, %{__id__: id}} -> id
          _ -> raise Gim.UnknownEdgeError, "Unknown Edge #{inspect link}"
        end
      end
      def resolve_assoc(link, _nodes, _errors) when is_number(link) do
        link # assume already resolved
      end
      def resolve_assoc(nil, _nodes, _errors) do
        nil # unset single edge
      end

      # Opts are errors: :raise|:warn|:ignore
      def import(nodes, opts \\ []) do
        errors = opts |> Keyword.get(:errors, :raise)
        state = GenServer.call(__MODULE__, {:state})
        # 1st pass: Create (insert)
        nodes =
          nodes
          |> Enum.map(fn {k, n} -> {k, create(state, n)} end)
          |> Enum.into(%{})
        # 2nd pass: Resolve (merge)
        nodes
          |> Enum.map(fn {k, n} -> resolve_node(n, nodes, errors) end)
          |> Enum.map(fn n ->
#            merge(n)
             merge(state, n)
             reflect_assocs(state, n)
          end)
      end

      # Export helper

      def type_aliases() do
        types = unquote(types)
        offset = prefix_len(types)
        Enum.into(types, %{}, fn x -> {x, String.slice(to_string(x), offset..-1)} end)
      end

      defp prefix_len([]), do: ""
      defp prefix_len(strs) do
        min = Enum.min(strs) |> to_string()
        max = Enum.max(strs) |> to_string()
        index = Enum.find_index(0..String.length(min), fn i -> String.at(min, i) != String.at(max, i) end)
        if index, do: index, else: String.length(min)
      end

    end
  end
end
