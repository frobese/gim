defmodule GraphDemo.Movies.Performance do
  use Gim.Schema

  alias GraphDemo.Movies.{Movie, Person, Character}

  schema do
    has_edge :film, Movie, reflect: :starring
    has_edge :actor, Person, reflect: :actor
    has_edge :character, Character, reflect: :performances
  end
end
