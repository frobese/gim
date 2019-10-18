defmodule GraphDemo.Biblio.Book do
  use Gim.Schema

  alias GraphDemo.Biblio.Author
  alias GraphDemo.Biblio.Publisher

  schema do
    property :title, index: :unique
    property :body
    has_edge :authored_by, Author, reflect: :author_of
    has_edges :published_by, Publisher, reflect: :publisher_of
  end
end
