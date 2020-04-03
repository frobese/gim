defmodule GimTest.Acl.Permission do
  use Gim.Schema

  alias GimTest.Acl.Role

  schema do
    property(:name, index: :unique)
    has_edges(:roles, Role, reflect: :permissions)
  end
end
