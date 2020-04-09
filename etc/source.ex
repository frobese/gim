defmodule Source do
  use Gim.Schema

  schema do
    property(:prop)
    has_edge(:target, Target, reflect: :target_edge)
  end
end
