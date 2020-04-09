defmodule Target do
  use Gim.Schema

  schema do
    property(:prop)
    has_edge(:target_edge, Source)
  end
end
