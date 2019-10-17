defmodule GraphDemo.Biblio.Book do
  use Gim.Schema

  alias GraphDemo.Biblio.Author
  alias GraphDemo.Biblio.Publisher

  schema do
    field :title, :string, index: :unique
    field :body, :string
    has_one :author, Author, reflect: :books
    has_many :publishers, Publisher, reflect: :books
  end
end
