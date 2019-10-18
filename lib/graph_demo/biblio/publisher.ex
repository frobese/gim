defmodule GraphDemo.Biblio.Publisher do
  use Gim.Schema

  alias GraphDemo.Biblio.Book

  schema do
    property :name, index: :unique
    has_edges :publisher_of, Book, reflect: :published_by
  end
end
