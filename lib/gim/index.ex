defmodule Gim.Index do
  @moduledoc """
  Internal helper module to handle indexes.
  """
  @type id :: pos_integer()
  @type index :: list(id)

  @doc """
  Turns a given list into an index

      iex> new([10, 13, 6, 60, 2])
      [60, 13, 10, 6, 2]

      iex> new([2, 2, 2, 3])
      [3, 2]
  """
  @spec new(list :: index) :: index
  def new(list) do
    Enum.reduce(list, [], &add(&2, &1))
  end

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
      [99, 50, 10, 0]

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

      iex> intersect([[99, 77, 66, 50, 30, 10, 0], [99, 70, 60, 50, 11, 10, 1, 0], [99, 50, 10]])
      [99, 50, 10]
  """
  @spec intersect(indexes :: list(index)) :: index
  def intersect(lists) do
    lists
    |> Enum.sort()
    |> Enum.reduce(&intersect/2)
  end

  @doc """
  Joins the given indexes

      iex> join([99, 50, 13], [90, 50, 10])
      [99, 90, 50, 13, 10]

      iex> join([], [99, 70, 60, 50, 11, 10, 1, 0])
      [99, 70, 60, 50, 11, 10, 1, 0]
  """
  @spec join(index_a :: index, index_b :: index) :: index
  def join([head | rest_a], [head | rest_b]) do
    [head | join(rest_a, rest_b)]
  end

  def join([head_a | rest_a], [head_b | _] = index_b) when head_a > head_b do
    [head_a | join(rest_a, index_b)]
  end

  def join([head_a | _] = index_a, [head_b | rest_b]) when head_a < head_b do
    [head_b | join(index_a, rest_b)]
  end

  def join([], rest) do
    rest
  end

  def join(rest, []) do
    rest
  end

  @doc """
  Intersects a list of indexes

      iex> join([[99, 55, 42, 11], [98, 54, 42, 10], [90, 50, 42]])
      [99, 98, 90, 55 , 54, 50, 42, 11, 10]
  """
  @spec join(indexes :: list(index)) :: index
  def join(lists) do
    lists
    |> Enum.sort()
    |> Enum.reduce(&join/2)
  end

  @doc """
  Returns the difference of two given indexes

      iex> difference([99, 66, 77, 50, 30, 10, 0], [99, 70, 60, 50, 11, 10, 1, 0])
      {[77, 66, 30], [70, 60, 11, 1]}

      iex> difference([5, 4, 3, 2, 1], [5, 4, 3, 2, 1])
      {[], []}

      iex> difference([], [])
      {[], []}
  """
  def difference(index_a, index_b) do
    difference(index_a, index_b, {[], []})
  end

  defp difference(index_a, [], {diff_a, diff_b}) do
    {join(index_a, diff_a), diff_b}
  end

  defp difference([], index_b, {diff_a, diff_b}) do
    {diff_a, join(index_b, diff_b)}
  end

  defp difference([head | rest_a], [head | rest_b], diff) do
    difference(rest_a, rest_b, diff)
  end

  defp difference([head_a | rest_a], [head_b | _] = index_b, {diff_a, diff_b})
       when head_a > head_b do
    difference(rest_a, index_b, {add(diff_a, head_a), diff_b})
  end

  defp difference([head_a | _] = index_a, [head_b | rest_b], {diff_a, diff_b})
       when head_a < head_b do
    difference(index_a, rest_b, {diff_a, add(diff_b, head_b)})
  end
end
