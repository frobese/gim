defmodule Gim.Schema do
  @moduledoc """
  Defines a schema.

  ## Example
      defmodule User do
        use Gim.Schema
        schema "users" do
          field :name, :string, index: :unique
          field :age, :integer, default: 0, index: true
          has_many :posts, Post, reflect: :author
        end
      end

  ## Reflection

  Any schema module will generate the `__schema__` function that can be
  used for runtime introspection of the schema:

  * `__schema__(:fields)` - Returns a list of all field names;
  * `__schema__(:type, field)` - Returns the type of the given field;
  * `__schema__(:indexes)` - Returns a list of all indexed field names;
  * `__schema__(:index, field)` - Returns wheter the given field is indexed;
  * `__schema__(:indexes_unique)` - Returns a list of all unique indexed field names;
  * `__schema__(:index_unique, field)` - Returns wheter the given field is unique indexed;
  * `__schema__(:indexes_non_unique)` - Returns a list of all non-unique indexed field names;
  * `__schema__(:index_non_unique, field)` - Returns wheter the given field is non-unique indexed;
  * `__schema__(:associations)` - Returns a list of all association field names;
  * `__schema__(:association, assoc)` - Returns the association reflection of the given assoc;

  Furthermore, `__struct__` functions are
  defined so structs functionalities are available.

  """

  @doc false
  defmacro __using__(_) do
    # apply(__MODULE__, which, [])
    quote do
      import Gim.Schema, only: [schema: 1]

      Module.register_attribute(__MODULE__, :gim_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :gim_assocs, accumulate: true)
    end
  end

  @doc """
  Defines a schema struct with a source name and field definitions.
  """
  defmacro schema([do: block]) do
    prelude =
      quote do
        Module.register_attribute(__MODULE__, :struct_fields, accumulate: true)

        Gim.Schema.__meta__(__MODULE__, :__id__, nil)
        Gim.Schema.__meta__(__MODULE__, :__repo__, nil)

        import Gim.Schema
        unquote(block)
      end

    postlude =
      quote unquote: false do
        defstruct @struct_fields

        fields = @gim_fields |> Enum.reverse
        assocs = @gim_assocs |> Enum.reverse

        def __schema__(:fields), do: unquote(Enum.map(fields, &elem(&1, 0)))

        def __schema__(:indexes), do: unquote(fields |> Enum.filter(&elem(&1, 2)) |> Enum.map(&elem(&1, 0)))

        for {field, _type, index} <- @gim_fields do
          def __schema__(:index, unquote(field)), do: unquote(index)
        end
        def __schema__(:index, _), do: nil

        def __schema__(:indexes_unique), do: unquote(fields |> Enum.filter(&elem(&1, 2) == :unique) |> Enum.map(&elem(&1, 0)))

        for {field, _type, index} <- @gim_fields do
          def __schema__(:index_unique, unquote(field)), do: unquote(index == :unique)
        end
        def __schema__(:index_unique, _), do: nil

        def __schema__(:indexes_non_unique), do: unquote(fields |> Enum.filter(&elem(&1, 2) == true) |> Enum.map(&elem(&1, 0)))

        for {field, _type, index} <- @gim_fields do
          def __schema__(:index_non_unique, unquote(field)), do: unquote(index == true)
        end
        def __schema__(:index_non_unique, _), do: nil

        def __schema__(:associations), do: unquote(Enum.map(assocs, &elem(&1, 0)))

        for {field, type, reflect} <- @gim_assocs do
          def __schema__(:association, unquote(field)), do: unquote(reflect)
        end
        def __schema__(:association, _), do: nil

        for {field, type, _index} <- @gim_fields do
          def __schema__(:type, unquote(field)), do: unquote(type)
        end
        for {field, type, _reflect} <- @gim_assocs do
          def __schema__(:type, unquote(field)), do: unquote(type)
        end
        def __schema__(:type, _), do: nil
    end

    quote do
      unquote(prelude)
      unquote(postlude)
    end
  end

  defmacro field(name, type \\ :string, opts \\ []) do
    quote do
      Gim.Schema.__field__(__MODULE__, unquote(name), unquote(type), unquote(opts))
    end
  end

  defmacro has_many(name, queryable, opts \\ []) do
    queryable = expand_alias(queryable, __CALLER__)
    reflect = Keyword.get(opts, :reflect)
    quote do
      Gim.Schema.__has_many__(__MODULE__, unquote(name), unquote(queryable), unquote(reflect), unquote(opts))

      def unquote(name)(%{:__repo__ => repo, unquote(name) => edges} = struct) do
        repo.fetch!(unquote(queryable), edges)
      end

      def unquote(:"add_#{name}")(struct, nodes) when is_list(nodes) do
        ids = Enum.map(nodes, fn %{__id__: id} -> id end)
        Map.update!(struct, unquote(name), fn x -> ids ++ x end)
      end
      def unquote(:"add_#{name}")(struct, %{__id__: id} = _node) do
        Map.update!(struct, unquote(name), fn x -> [id | x] end)
      end

      def unquote(:"delete_#{name}")(struct, nodes) when is_list(nodes) do
        Map.update!(struct, unquote(name), fn edges -> Enum.reject(edges, &Enum.member?(nodes, &1)) end)
      end
      def unquote(:"delete_#{name}")(struct, %{__id__: id} = _node) do
        Map.update!(struct, unquote(name), &List.delete(&1, id))
      end

      def unquote(:"set_#{name}")(struct, nodes) when is_list(nodes) do
        ids = Enum.map(nodes, fn %{__id__: id} -> id end)
        Map.put(struct, unquote(name), ids)
      end
      def unquote(:"set_#{name}")(struct, %{__id__: id} = _node) do
        Map.put(struct, unquote(name), [id])
      end

      def unquote(:"clear_#{name}")(struct) do
        Map.put(struct, unquote(name), [])
      end
    end
  end

  defmacro has_one(name, queryable, opts \\ []) do
    queryable = expand_alias(queryable, __CALLER__)
    reflect = Keyword.get(opts, :reflect)
    quote do
      Gim.Schema.__has_one__(__MODULE__, unquote(name), unquote(queryable), unquote(reflect), unquote(opts))

      def unquote(name)(%{:__repo__ => repo, unquote(name) => edge} = struct) do
        repo.fetch!(unquote(queryable), edge)
      end

      def unquote(:"set_#{name}")(struct, %{__id__: id} = _node) do
        Map.put(struct, unquote(name), id)
      end

      def unquote(:"clear_#{name}")(struct) do
        Map.put(struct, unquote(name), nil)
      end
    end
  end

  @doc false
  def __field__(mod, name, type, opts) do
    put_struct_field(mod, name, Keyword.get(opts, :default))
    index = case Keyword.get(opts, :index) do
      :unique -> :unique
      truthy -> !!truthy
    end
    Module.put_attribute(mod, :gim_fields, {name, type, index})
  end

  @doc false
  def __meta__(mod, name, default) do
    put_struct_field(mod, name, default)
  end

  @doc false
  def __has_many__(mod, name, queryable, reflect, opts) do
    put_struct_field(mod, name, Keyword.get(opts, :default, []))
    Module.put_attribute(mod, :gim_assocs, {name, queryable, reflect})
  end

  @doc false
  def __has_one__(mod, name, queryable, reflect, opts) do
    put_struct_field(mod, name, Keyword.get(opts, :default))
    Module.put_attribute(mod, :gim_assocs, {name, queryable, reflect})
  end

  ## Private

  defp put_struct_field(mod, name, assoc) do
    fields = Module.get_attribute(mod, :struct_fields)

    if List.keyfind(fields, name, 0) do
      raise ArgumentError, "field/association #{inspect name} is already set on schema"
    end

    Module.put_attribute(mod, :struct_fields, {name, assoc})
  end

  defp expand_alias({:__aliases__, _, _} = ast, env),
    do: Macro.expand(ast, %{env | function: {:__schema__, 2}})
  defp expand_alias(ast, _env),
    do: ast
end
