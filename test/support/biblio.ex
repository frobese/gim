defmodule GimTest.Biblio do
  alias GimTest.Biblio.{Repo, Author, Book, Publisher}

  @sets [:set1, :set2, :set3]

  @set1 %{
    "a1" => %Author{name: "William Gibson", author_of: ["b1", "b2"]},
    "a2" => %Author{name: "Terry Pratchett", author_of: ["b3", "b4"]},
    "b1" => %Book{title: "Neuromancer", authored_by: "a1", published_by: ["p1"]},
    "b2" => %Book{title: "Count Zero", authored_by: "a1", published_by: ["p2"]},
    "b3" => %Book{title: "The Light Fantastic", authored_by: "a2", published_by: ["p3"]},
    "b4" => %Book{title: "Hogfather", authored_by: "a2", published_by: ["p2"]},
    "p1" => %Publisher{name: "Ace Books", publisher_of: ["b1"]},
    "p2" => %Publisher{name: "Victor Gollancz", publisher_of: ["b2", "b4"]},
    "p3" => %Publisher{name: "Colin Smythe", publisher_of: ["b3"]}
  }

  @set2 %{
    "a1" => %Author{name: "William Gibson", author_of: ["b1", "b2"]},
    "a2" => %Author{name: "Terry Pratchett", author_of: ["b3", "b4"]},
    "b1" => %Book{title: "Neuromancer"},
    "b2" => %Book{title: "Count Zero"},
    "b3" => %Book{title: "The Light Fantastic"},
    "b4" => %Book{title: "Hogfather"},
    "p1" => %Publisher{name: "Ace Books", publisher_of: ["b1"]},
    "p2" => %Publisher{name: "Victor Gollancz", publisher_of: ["b2", "b4"]},
    "p3" => %Publisher{name: "Colin Smythe", publisher_of: ["b3"]}
  }

  @set3 %{
    "a1" => %Author{name: "William Gibson"},
    "a2" => %Author{name: "Terry Pratchett"},
    "b1" => %Book{title: "Neuromancer", authored_by: "a1", published_by: ["p1"]},
    "b2" => %Book{title: "Count Zero", authored_by: "a1", published_by: ["p2"]},
    "b3" => %Book{title: "The Light Fantastic", authored_by: "a2", published_by: ["p3"]},
    "b4" => %Book{title: "Hogfather", authored_by: "a2", published_by: ["p2"]},
    "p1" => %Publisher{name: "Ace Books"},
    "p2" => %Publisher{name: "Victor Gollancz"},
    "p3" => %Publisher{name: "Colin Smythe"}
  }

  def setup(data \\ :set1) when data in @sets do
    Repo.start_link()

    data
    |> case do
      :set1 -> @set1
      :set2 -> @set2
      :set3 -> @set3
    end
    |> Repo.import()

    :ok
  end
end
