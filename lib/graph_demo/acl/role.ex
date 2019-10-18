defmodule GraphDemo.Acl.Role do
  use Gim.Schema

  alias GraphDemo.Acl.{Access, Permission}

  schema do
    property :name, index: :unique
    has_edges :accesses, Access, reflect: :role
    has_edges :permissions, Permission, reflect: :roles
  end
end
