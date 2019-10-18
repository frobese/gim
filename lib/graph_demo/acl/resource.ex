defmodule GraphDemo.Acl.Resource do
  use Gim.Schema

  alias GraphDemo.Acl.Access

  schema do
    property :name, index: :unique
    has_edges :accesses, Access, reflect: :resource
  end
end
