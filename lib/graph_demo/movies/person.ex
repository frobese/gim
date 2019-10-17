defmodule GraphDemo.Movies.Person do
  use Gim.Schema

  alias GraphDemo.Movies.Movie

  schema do
    field :name, :string, index: :unique
    has_many :director, Movie, reflect: :director
    has_many :starring, Movie, reflect: :starring
  end
end
