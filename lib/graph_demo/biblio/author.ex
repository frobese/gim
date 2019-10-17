defmodule GraphDemo.Biblio.Author do
  use Gim.Schema

  alias GraphDemo.Biblio.Book

  schema do
    field :name, :string, index: :unique
    field :age, :integer, default: 0, index: true
    has_many :books, Book, reflect: :author
  end
end
