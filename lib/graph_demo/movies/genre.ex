defmodule GraphDemo.Movies.Genre do
  use Gim.Schema

  alias GraphDemo.Movies.Movie

  schema do
    field :name, :string, index: :unique
    has_many :movies, Movie, reflect: :genre
  end
end
