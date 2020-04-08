defmodule GimTest do
  @moduledoc false
  use ExUnit.Case
  alias GimTest.Biblio, as: MyApp

  doctest Gim, import: true

  alias GimTest.Biblio
  alias Biblio.{Repo, Author, Book, Publisher}

  setup do
    Biblio.setup(:set3)
    # {:ok, pid: pid}
  end

  # @tag movies: true
  test "all" do
    assert {:ok, books} = Repo.all(Book)
    assert 4 == length(books)
  end

  test "fetch!" do
    assert %Book{__id__: 1} = Repo.fetch!(Book, 1)
    assert_raise Gim.NoNodeError, fn -> Repo.fetch!(Book, 33) end
    assert %Book{title: "Neuromancer"} = Repo.fetch!(Book, :title, "Neuromancer")
    assert_raise Gim.NoNodeError, fn -> Repo.fetch!(Book, :title, "Neuroma") end
  end

  # test "get_by" do
  #   assert [%Book{body: nil} | _] = Repo.get_by(Book, :body, nil)
  # end

  test "get" do
    assert [%Book{title: "Neuromancer"}] = Repo.get(Book, :title, "Neuromancer")
    assert_raise Gim.NoIndexError, fn -> Repo.get(Book, :body, nil) end
  end

  test "fetch" do
    assert {:ok, %Book{title: "Neuromancer"}} = Repo.fetch(Book, :title, "Neuromancer")
    assert {:error, Gim.NoNodeError} = Repo.fetch(Book, :title, "Neuroma")
  end

  test "edges" do
    assert [book] = Repo.get(Book, :title, "Neuromancer")

    assert [%Author{name: "William Gibson"}] = [author] = Gim.Query.edges(book, :authored_by)

    assert [%Book{title: "Neuromancer"}, %Book{title: "Count Zero"}] =
             Enum.sort(Gim.Query.edges(author, :author_of))
  end

  test "repo guard" do
    require Biblio.Repo

    assert Biblio.Repo.is_type(Author)
    assert Biblio.Repo.is_type(Book)
    assert Biblio.Repo.is_type(Publisher)
    refute Biblio.Repo.is_type(GimTest.Animal)
  end
end
