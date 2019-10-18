defmodule GraphDemo.Movies.Character do
  use Gim.Schema

  alias GraphDemo.Movies.Performance

  schema do
    property :name, index: :unique
    has_edges :performances, Performance, reflect: :character
  end
end
