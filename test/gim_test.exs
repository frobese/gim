defmodule GimTest do
  use ExUnit.Case

  # doctest Gim, import: true

  alias GimTest.Biblio
  alias Biblio.{Repo, Author, Book, Publisher}

  setup do
    Biblio.setup(:set1)
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

  test "get_by" do
    assert [%Book{body: nil} | _] = Repo.get_by(Book, :body, nil)
  end

  test "get" do
    assert [%Book{title: "Neuromancer"}] = Repo.get(Book, :title, "Neuromancer")
    assert_raise Gim.NoIndexError,fn -> Repo.get(Book, :body, nil) end
  end

  test "fetch" do
    assert {:ok, %Book{title: "Neuromancer"}} = Repo.fetch(Book, :title, "Neuromancer")
    assert {:error, Gim.NoNodeError} = Repo.fetch(Book, :title, "Neuroma")
  end
end
