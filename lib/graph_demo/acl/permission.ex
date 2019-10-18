defmodule GraphDemo.Acl.Permission do
  use Gim.Schema

  alias GraphDemo.Acl.Role

  schema do
    property :name, index: :unique
    has_edges :roles, Role, reflect: :permissions
  end
end
