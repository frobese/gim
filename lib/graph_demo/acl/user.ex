defmodule GraphDemo.Acl.User do
  use Gim.Schema

  alias GraphDemo.Acl.Access

  schema do
    field :name, :string, index: :unique
    has_many :accesses, Access, reflect: :user
  end
end
