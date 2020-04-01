defmodule Gim.Repo.Index do
  @type id :: pos_integer()
  @type index :: list(id)

  @doc """
  Adds an id to the given index

      iex> add([], 42)
      [42]

      iex> add([404, 23, 13], 42)
      [404, 42, 23, 13]

  Since ids have to be unique, duplicates are prevented

      iex> add([404, 42, 23, 13], 42)
      [404, 42, 23, 13]
  """
  @spec add(index :: index, id :: id) :: index
  def add(index, id)

  def add([], id) do
    [id]
  end

  def add([head | rest], id) when id < head do
    [head | add(rest, id)]
  end

  def add([head | _] = list, id) when id > head do
    [id | list]
  end

  def add([head | _] = list, head) do
    list
  end

  @doc """
  Removes an id from the given index

      iex> remove([], 42)
      []

      iex> remove([404, 42, 23, 13], 42)
      [404, 23, 13]
  """
  @spec remove(index :: index, id :: id) :: index
  def remove(index, id) do
    List.delete(index, id)
  end

  @doc """
  Intersects the given indexes

      iex> intersect([99, 66, 77, 50, 30, 10, 0], [99, 70, 60, 50, 11, 10, 1, 0])
      [99, 50, 10]

      iex> intersect([], [99, 70, 60, 50, 11, 10, 1, 0])
      []
  """
  @spec intersect(index_a :: index, index_b :: index) :: index
  def intersect([head | rest_a], [head | rest_b]) do
    [head | intersect(rest_a, rest_b)]
  end

  def intersect([head_a | rest_a], [head_b | _] = index_b) when head_a > head_b do
    intersect(rest_a, index_b)
  end

  def intersect([head_a | _] = index_a, [head_b | rest_b]) when head_a < head_b do
    intersect(index_a, rest_b)
  end

  def intersect([], _) do
    []
  end

  def intersect(_, []) do
    []
  end

  @doc """
  Intersects a list of indexes

      iex> intersect([[99, 66, 77, 50, 30, 10, 0], [99, 70, 60, 50, 11, 10, 1, 0], [99, 50, 10]])
      [99, 50, 10]
  """
  @spec intersect(indexes :: list(index)) :: index
  def intersect(lists) do
    lists
    |> Enum.sort()
    |> Enum.reduce(&intersect/2)
  end
end
