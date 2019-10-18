defmodule GraphDemo.Movies.Person do
  use Gim.Schema

  alias GraphDemo.Movies.{Movie, Performance}

  schema do
    property :name, index: :unique
    has_edges :director, Movie, reflect: :director
    has_edges :actor, Performance, reflect: :actor
  end
end
