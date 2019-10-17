defmodule GraphDemo.Acl.Access do
  use Gim.Schema

  alias GraphDemo.Acl.{User, Resource, Role}

  schema do
    field :name, :string, index: :unique
    has_one :user, User, reflect: :accesses
    has_one :resource, Resource, reflect: :accesses
    has_one :role, Role, reflect: :accesses
  end
end
