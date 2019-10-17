defmodule GraphDemo.Movies.Movie do
  use Gim.Schema

  alias GraphDemo.Movies.Person
  alias GraphDemo.Movies.Genre

  schema do
    field :name, :string, index: :unique
    field :initial_release_date, :string, index: true
    has_many :genre, Genre, reflect: :movies
    has_many :director, Person, reflect: :director
    has_many :starring, Person, reflect: :starring
  end
end
