defmodule GraphDemo.Untyped.Repo do
  alias GraphDemo.Untyped

  @moduledoc false
  use Gim.Repo,
    types: [
      Untyped.Node,
    ]
end
