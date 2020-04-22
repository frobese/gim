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

    assert [%Book{title: "Neuromancer"}, %Book{title: "Count Zero"}] =
             books = Author.author_of(author)

    assert [^author] = Book.authored_by(books)
  end

  test "repo guard" do
    require Biblio.Repo

    assert Biblio.Repo.is_type(Author)
    assert Biblio.Repo.is_type(Book)
    assert Biblio.Repo.is_type(Publisher)
    refute Biblio.Repo.is_type(GimTest.Animal)
  end

  test "add edge" do
    assert {:ok, the_light} = Biblio.Repo.fetch(Biblio.Book, :title, "The Light Fantastic")
    assert {:ok, book} = Biblio.Repo.insert(%Biblio.Book{title: "The Colour of Magic"})
    assert {:ok, terry} = Biblio.Repo.fetch(Biblio.Author, :name, "Terry Pratchett")

    book_with_author = Biblio.Book.set_authored_by(book, terry)
    assert {:ok, _book} = Biblio.Repo.update(book_with_author)

    book_with_similar_to = Biblio.Book.set_similar_to(book, the_light)
    assert {:ok, _book} = Biblio.Repo.update(book_with_similar_to)
  end
end
