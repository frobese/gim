defmodule GimTest.Biblio.Repo do
  @moduledoc false
  alias GimTest.Biblio

  @moduledoc false
  use Gim.Repo,
    types: [
      Biblio.Author,
      Biblio.Book,
      Biblio.Publisher
    ]
end
