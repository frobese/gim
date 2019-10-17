defmodule GraphDemo.Acl.Role do
  use Gim.Schema

  alias GraphDemo.Acl.{Access, Permission}

  schema do
    field :name, :string, index: :unique
    has_many :accesses, Access, reflect: :role
    has_many :permissions, Permission, reflect: :roles
  end
end
