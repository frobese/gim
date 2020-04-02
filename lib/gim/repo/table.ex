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
  @callback insert(table :: map(), struct()) :: struct()
  @callback update(table :: map(), struct()) :: struct()
  @callback delete(table :: map(), struct()) :: :ok
  @callback query(table :: map(), ids :: nil | list(pos_integer()), filter :: list()) :: {:ok, list(struct())} | {:error, Gim.NoIndexError}
end
