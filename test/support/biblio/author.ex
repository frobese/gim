defmodule GimTest.Biblio.Author do
  use Gim.Schema

  alias GimTest.Biblio.Book

  schema do
    property(:name, index: :unique)
    property(:age, default: 0, index: true)
    has_edges(:author_of, Book, reflect: :authored_by)
  end
end
