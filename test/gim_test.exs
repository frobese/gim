defmodule GimTest do
  use ExUnit.Case

  # doctest Gim, import: true

  alias GimTest.Movies

  setup do
    Movies.setup()
    # {:ok, pid: pid}
  end

  test "all" do
    Movies.Repo.all(Movies.Movie)
  end
end
