defmodule GimTest.Biblio.Repo do
  @moduledoc false
  alias GimTest.Biblio

  use Gim.Repo,
    types: [
      Biblio.Author,
      Biblio.Book,
      Biblio.Publisher
    ]
end
