defmodule GimTest.Movies.Genre do
  @moduledoc false
  use Gim.Schema

  alias GimTest.Movies.Movie

  schema do
    property(:name, index: :unique)
    has_edges(:movies, Movie, reflect: :genre)
  end
end
