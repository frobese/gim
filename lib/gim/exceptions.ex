defmodule Gim.NoSuchTypeError do
  @moduledoc """
  Raised at runtime when a query references an unknown type.
  """
  defexception [:message]
end

defmodule Gim.NoNodeError do
  @moduledoc """
  Raised at runtime when a query is invalid.
  """
  defexception [:message]
end

defmodule Gim.MultipleNodesError do
  @moduledoc """
  Raised at runtime when a query is invalid.
  """
  defexception [:message]
end

defmodule Gim.DuplicateNodeError do
  @moduledoc """
  Raised at runtime when a query is invalid.
  """
  defexception [:message]
end

defmodule Gim.UnknownEdgeError do
  @moduledoc """
  Raised at runtime when a insert/update is invalid.
  """
  defexception [:message]
end

defmodule Gim.NoIndexError do
  @moduledoc """
  Raised at runtime when a query tries to filter an unindexed property.
  """
  defexception [:message]
end

# defmodule Gim.InvalidFilter do
#   @moduledoc """
#   Raised at runtime when a query filter is inproper.
#   """
#   defexception [:message]
# end
