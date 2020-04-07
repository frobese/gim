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

    guard = guard(Macro.expand(types, __CALLER__))

    quote bind_quoted: [types: types, guard: guard] do
      alias Gim.Query

      defstruct types

      quote do
        guard
      end

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
      end

      # API

      def types do
        unquote(types)
      end

      def dump do
        GenServer.call(__MODULE__, {:all})
      end

      def resolve(%Gim.Query{type: type} = query) when is_type(type) do
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

          err ->
            err
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

      def get(type, _key, _value) do
        raise Gim.NoSuchTypeError, "No such Type #{inspect(type)}"
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
          x -> raise Gim.NoNodeError, "No such Node #{inspect(x)}"
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

      @doc """
      Inserts a fresh node in the repo without the edges.
      """
      def create(%{__struct__: struct} = node) when is_type(struct) do
        # remove all edges
        naked = Gim.Query.clear_edges(node)

        %{__id__: id, __repo__: repo} = insert(naked)

        %{node | __id__: id, __repo__: repo}
      end

      @doc """
      Insert a fresh node into the repo. The nodes must not have and id.
      """
      def insert(%{__struct__: struct, __id__: nil} = node) when is_type(struct) do
        GenServer.call(__MODULE__, {:insert, node})
      end

      def insert!(node) do
        case insert(node) do
          {:ok, res} -> res
          x -> raise Gim.DuplicateNodeError, "Duplicate Node #{inspect(x)}"
        end
      end

      @doc """
      Update a node by replacing the attributes and edges.
      """
      def update(node) do
        GenServer.call(__MODULE__, {:update, node})
        node
      end

      @doc """
      Update a node by replacing the attributes and merging the edges.
      """
      def merge(node) do
        GenServer.call(__MODULE__, {:merge, node})
      end

      def merge!(node) do
        case merge(node) do
          {:ok, res} -> res
          x -> raise Gim.NoNodeError, "No such Node #{inspect(x)}"
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
          |> Enum.map(fn {k, node} -> {k, create(node)} end)
          |> Enum.into(%{})

        # 2nd pass: Resolve (merge)
        nodes
        |> Enum.map(fn {k, node} -> Gim.Repo.__put_assocs__(node, nodes, errors) end)
        |> Enum.map(fn node ->
          merge(node)
          # merge(state, n)
          # reflect_assocs(state, n)
          # update(node)
        end)
      end
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

  defp guard([]) do
    quote do
      defguard is_type(_) when false
    end
  end

  defp guard(types) do
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

    quote do
      defguard is_type(type) when unquote(conditions)
    end
  end
end
