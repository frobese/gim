defmodule GimTest.Movies.Movie do
  use Gim.Schema

  alias GimTest.Movies.{Genre, Person, Performance}

  schema do
    property(:name, index: :unique)
    property(:initial_release_date, index: true)
    has_edges(:genre, Genre, reflect: :movies)
    has_edges(:director, Person, reflect: :director)
    has_edges(:starring, Performance, reflect: :film)
  end
end
