defmodule GimTest.Movies.Character do
  @moduledoc false
  use Gim.Schema

  alias GimTest.Movies.Performance

  schema do
    property(:name, index: :unique)
    has_edges(:performances, Performance, reflect: :character)
  end
end
