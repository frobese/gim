defmodule GimTest.Acl.Access do
  @moduledoc false
  use Gim.Schema

  alias GimTest.Acl.{User, Resource, Role}

  schema do
    property(:name, index: :unique)
    has_edge(:user, User, reflect: :accesses)
    has_edge(:resource, Resource, reflect: :accesses)
    has_edge(:role, Role, reflect: :accesses)
  end
end
