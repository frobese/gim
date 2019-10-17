defmodule GraphDemo.Acl.Permission do
  use Gim.Schema

  alias GraphDemo.Acl.Role

  schema do
    field :name, :string, index: :unique
    has_many :roles, Role, reflect: :permissions
  end
end
