defmodule GraphDemo.Acl.Resource do
  use Gim.Schema

  alias GraphDemo.Acl.Access

  schema do
    field :name, :string, index: :unique
    has_many :accesses, Access, reflect: :resource
  end
end
