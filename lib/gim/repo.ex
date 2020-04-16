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
    types = Macro.expand(Keyword.get(opts, :types, []), __CALLER__)

    quote bind_quoted: [types: types] do
      alias Gim.Query

      @after_compile Gim.Repo

      defstruct types

      conditions =
        types
        |> Enum.map(fn type ->
          quote do
            type == unquote(type)
          end
        end)
        |> Enum.reduce(fn guard, acc ->
          quote do
            unquote(guard) or unquote(acc)
          end
        end)

      defguard is_type(type) when unquote(conditions)

      @default_args [
        name: __MODULE__,
        module: __MODULE__,
        table: Gim.Repo.Table.Ets,
        types: types
      ]
      @configurable [:name, :types, :table]
      def start_link(args \\ []) do
        args = Keyword.merge(@default_args, Keyword.take(args, @configurable))

        GenServer.start_link(Gim.Repo.Server, args,
          name: args[:name],
          spawn_opt: [fullsweep_after: 50]
        )
      rescue
        # Its needed since the spawn ops mess with the dialyzer
        _e in ArgumentError ->
          {:error, :unexpected}
      end

      # API
      def types do
        unquote(types)
      end

      def dump do
        GenServer.call(__MODULE__, {:all})
      end

      def resolve(%Gim.Query{type: type, expand: expand} = query)
          when is_type(type) and length(expand) > 0 do
        case GenServer.call(__MODULE__, {:resolve, query}) do
          {:ok, nodes} ->
            Gim.Repo.__expand__(nodes, expand)

          error ->
            error
        end
      end

      def resolve(%Gim.Query{type: type} = query) when is_type(type) do
        GenServer.call(__MODULE__, {:resolve, query})
      end

      def resolve!(query) do
        case resolve(query) do
          {:ok, nodes} -> nodes
          {:error, error} -> raise error
        end
      end

      def all(type) when is_type(type) do
        resolve(%Query{type: type})
      end

      def all!(type) when is_type(type) do
        case all(type) do
          {:ok, nodes} -> nodes
          {:error, exception} -> raise exception
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
      Get a node by a given edge, or list of nodes by given edges.
      """
      def fetch!(type, id) when is_type(type) do
        fetch!(type, :__id__, id)
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

      @doc """
      Inserts a fresh node in the repo without the edges.
      """
      def create(%{__struct__: struct} = node) when is_type(struct) do
        # remove all edges
        naked = Gim.Query.clear_edges(node)

        case insert(naked) do
          {:ok, %{__id__: id, __repo__: repo}} ->
            {:ok, %{node | __id__: id, __repo__: repo}}

          error ->
            error
        end
      end

      def create!(node) do
        case create(node) do
          {:ok, node} -> node
          {:error, error} -> raise error
        end
      end

      @doc """
      Insert a fresh node into the repo. The nodes must not have and id.
      """
      def insert(%{__struct__: struct, __id__: nil} = node) when is_type(struct) do
        GenServer.call(__MODULE__, {:insert, node})
      end

      def insert!(node) do
        case insert(node) do
          {:ok, node} -> node
          {:error, error} -> raise error
        end
      end

      @doc """
      Update a node by replacing the attributes and edges.
      """
      def update(node) do
        GenServer.call(__MODULE__, {:update, node})
      end

      def update!(node) do
        case update(node) do
          {:ok, node} -> node
          {:error, error} -> raise error
        end
      end

      @doc """
      Update a node by replacing the attributes and merging the edges.
      """
      def merge(node) do
        GenServer.call(__MODULE__, {:merge, node})
      end

      def merge!(node) do
        case merge(node) do
          {:ok, node} -> node
          {:error, error} -> raise error
        end
      end

      @doc """
      Deletes a node without consistency checks.
      """
      def delete(node) do
        GenServer.call(__MODULE__, {:delete, node})
      end

      # Import helper

      # Opts are errors: :raise|:warn|:ignore
      def import(nodes, opts \\ []) do
        require Logger

        errors = Keyword.get(opts, :errors, :raise)

        # 1st pass: Create (insert)
        nodes =
          nodes
          |> Enum.map(fn {k, node} -> {k, create!(node)} end)
          |> Enum.into(%{})

        # 2nd pass: Resolve (merge)
        nodes
        |> Enum.map(fn {k, node} -> Gim.Repo.__put_assocs__(node, nodes, errors) end)
        |> Enum.map(fn node -> merge(node) end)
      end
    end
  end

  def __after_compile__(caller, _byte_code) do
    types = caller.module.types()

    for type <- types do
      for {_name, _cardinality, assoc_type, _reflect, _stacktrace} <- type.__schema__(:gim_assocs) do
        unless assoc_type in types do
          message = ~s'''
          #{inspect(type)} has an edge targeting #{inspect(assoc_type)} which is not part of the Repository
          '''

          reraise Gim.NoSuchTypeError, message, Macro.Env.stacktrace(caller)
        end
      end
    end
  end

  def __expand__(nodes, []) do
    {:ok, nodes}
  end

  def __expand__(nodes, path) when is_list(nodes) do
    Enum.reduce_while(Enum.reverse(nodes), {:ok, []}, fn node, {:ok, acc} ->
      case __expand__(node, path) do
        {:ok, node} -> {:cont, {:ok, [node | acc]}}
        error -> {:halt, error}
      end
    end)
  end

  def __expand__(%{__repo__: repo} = node, [{edge, nested} | path]) when is_map(node) do
    with {:ok, nodes} <- repo.resolve(Gim.Query.query(node, edge)),
         {:ok, nodes} <- __expand__(nodes, nested) do
      Map.update!(node, edge, fn assoc ->
        if is_list(assoc) do
          nodes
        else
          List.first(nodes)
        end
      end)
      |> __expand__(path)
    else
      error -> error
    end
  end

  def __put_assocs__(%struct{} = node, nodes, errors) do
    assocs = struct.__schema__(:associations)

    Enum.reduce(assocs, node, fn assoc, node ->
      __put_assoc__(node, assoc, nodes, errors)
    end)
  end

  def __put_assoc__(node, assoc, nodes, _errors) do
    import Gim.Query, only: [add_edge: 3, clear_edge: 2]

    node
    |> Map.fetch!(assoc)
    |> List.wrap()
    |> Enum.reduce(clear_edge(node, assoc), fn link, node ->
      case Map.fetch(nodes, link) do
        {:ok, link_node} ->
          add_edge(node, assoc, link_node)
      end
    end)
  end
end
