defmodule GimTest.Acl.Repo do
  alias GimTest.Acl

  @moduledoc false
  use Gim.Repo,
    types: [
      Acl.Access,
      Acl.Permission,
      Acl.Resource,
      Acl.Role,
      Acl.User
    ]
end