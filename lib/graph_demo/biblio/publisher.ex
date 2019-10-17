defmodule GraphDemo.Biblio.Publisher do
  use Gim.Schema

  alias GraphDemo.Biblio.Book

  schema do
    field :name, :string, index: :unique
    has_many :books, Book, reflect: :publishers
  end
end
