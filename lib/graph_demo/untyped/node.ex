defmodule GraphDemo.Untyped.Node do
  use Gim.Schema
  alias __MODULE__

  schema do
    property :id, index: :unique
    property :data
    has_edges :links, Node
  end
end
