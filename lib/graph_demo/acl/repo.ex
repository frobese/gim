defmodule GraphDemo.Acl.Repo do
  alias GraphDemo.Acl

  @moduledoc false
  use Gim.Repo,
    types: [
      Acl.Access,
      Acl.Permission,
      Acl.Resource,
      Acl.Role,
      Acl.User,
    ]
end
