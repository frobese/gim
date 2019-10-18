defmodule GraphDemo.Biblio.Author do
  use Gim.Schema

  alias GraphDemo.Biblio.Book

  schema do
    property :name, index: :unique
    property :age, default: 0, index: true
    has_edges :author_of, Book, reflect: :authored_by
  end
end
