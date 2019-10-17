defmodule GraphDemo.Biblio.Repo do
  alias GraphDemo.Biblio

  @moduledoc false
  use Gim.Repo,
    types: [
      Biblio.Author,
      Biblio.Book,
      Biblio.Publisher,
    ]
end
