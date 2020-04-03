defmodule Gim.Repo.Table do
  @moduledoc """
  Defines a typed table of nodes.

  A repository holds each distinct node type in a typed Table.
  """

  defmacro __using__(_opts \\ []) do
    quote do
      @behaviour unquote(__MODULE__)
    end
  end

  @callback new(reference :: atom(), type :: atom()) :: map()
  @callback all(table :: map()) :: list()
  @callback fetch!(table :: map(), integer()) :: struct()
  @callback fetch(table :: map(), integer()) :: struct()
  @callback get(table :: map(), field :: atom(), value :: any()) :: list(struct())
  @callback get_by(table :: map(), field :: atom(), value :: any()) :: list(struct())
  @callback insert(table :: map(), struct()) :: struct()
  @callback update(table :: map(), struct()) :: struct()
  @callback delete(table :: map(), struct()) :: :ok
end
