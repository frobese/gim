defmodule GraphDemo.Untyped.Contact do
  defstruct [:name, :age, :height]
end

defmodule GraphDemo.Untyped.Hobby do
  defstruct [:kind, :outdoors?]
end

defmodule GraphDemo.Untyped.Location do
  defstruct [:area, :long, :lat]
end
