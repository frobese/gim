defmodule GimTest.QueryTest do
  @moduledoc false
  use ExUnit.Case, async: false

  import Gim.Query

  alias Gim.Query
  alias GimTest.{Animal, Biblio}

  defmodule Repo do
    @moduledoc false
    use Gim.Repo,
      types: [
        Animal
      ]
  end

  setup_all do
    Repo.start_link()

    Enum.each(Animal.data(), &Repo.insert(&1))

    GimTest.Biblio.setup()
    []
  end

  test "Query" do
    assert %Query{type: Animal, filter: {:or, [__id__: 1]}} == query(%Animal{__id__: 1})

    assert %Query{type: Animal, filter: {:or, [__id__: 1, __id__: 2]}} ==
             query([%Animal{__id__: 1}, %Animal{__id__: 2}])

    {:ok, animals} = Repo.all(Animal)
    assert %Query{} = query(animals)
  end

  describe "Filter" do
    # alias GimTest.Biblio.{Author, Book, Publisher}
    alias GimTest.Biblio.Author

    test "simple join" do
      query = query(Author)

      assert %Query{filter: {:and, [name: "Klaus"]}} =
               filter(filter(query, :and, name: "Klaus"), [])

      assert %Query{filter: {:and, [name: "Klaus"]}} = filter(query, :and, name: "Klaus")
      assert %Query{filter: {:and, [name: "Klaus"]}} = filter(query, {:and, name: "Klaus"})
      assert %Query{filter: {:and, [name: "Klaus"]}} = filter(query, :and, {:and, name: "Klaus"})
      assert %Query{filter: {:and, [name: "Klaus"]}} = filter(query, name: "Klaus")

      assert %Query{filter: {:or, [name: "Klaus"]}} = filter(query, :or, name: "Klaus")
      assert %Query{filter: {:or, [name: "Klaus"]}} = filter(query, {:or, name: "Klaus"})
      assert %Query{filter: {:or, [name: "Klaus"]}} = filter(query, :or, {:or, name: "Klaus"})
    end

    test "no so simple joins" do
      query = query(Author)
      q_and = filter(query, name: "Klaus")
      q_or = filter(query, :or, name: "Klaus")

      assert %Query{filter: {:and, [{:or, [name: "Klaus"]}, name: "Paul"]}} =
               filter(q_or, :and, name: "Paul")

      assert %Query{filter: {:and, [name: "Klaus", name: "Paul"]}} =
               filter(q_and, :and, name: "Paul")

      assert %Query{filter: {:or, [{:and, [name: "Klaus"]}, name: "Paul"]}} =
               filter(q_and, :or, name: "Paul")

      assert %Query{filter: {:or, [name: "Klaus", name: "Paul"]}} =
               filter(q_or, :or, name: "Paul")
    end
  end

  describe "Expand" do
    # alias GimTest.Biblio.{Author, Book, Publisher}
    alias GimTest.Biblio.Author

    test "simple expand" do
      query = query(Author)

      assert %Query{expand: [author_of: []]} = expand(query, :author_of)
      assert %Query{expand: [author_of: []]} = expand(query, author_of: [])
    end

    test "multi level expand" do
      query = query(Author)

      assert %Query{expand: [author_of: [published_by: []]]} =
               expand(query, author_of: :published_by)

      assert %Query{expand: [author_of: [authored_by: [], published_by: []]]} =
               expand(query, author_of: [:published_by, :authored_by])

      assert %Query{expand: [author_of: [authored_by: [], published_by: []]]} =
               expand(expand(query, author_of: :published_by), author_of: :authored_by)
    end

    test "edge check" do
      query = query(Author)

      assert_raise Gim.QueryError, fn -> expand(query, :name) end
      assert_raise Gim.QueryError, fn -> expand(query, author_of: :body) end
    end
  end

  describe "Resolve" do
    @tag query: true
    test "all" do
      {:ok, animals} =
        Animal
        |> query()
        |> Repo.resolve()

      assert 473 == length(animals)
    end

    @tag query: true
    @tag data_animal: true
    test "fetch" do
      assert {:ok, [%Animal{impound_no: "K12-000416"}]} =
               Animal
               |> query()
               |> filter(impound_no: "K12-000416")
               |> Repo.resolve()
    end

    @tag query: true
    @tag data_animal: true
    test "simple queries" do
      {:ok, dogs} =
        Animal
        |> query()
        |> filter(animal_type: "Dog")
        |> Repo.resolve()

      for dog <- dogs do
        assert dog.animal_type == "Dog"
      end

      {:ok, cats} =
        Animal
        |> query()
        |> filter(animal_type: "Cat")
        |> Repo.resolve()

      for cat <- cats do
        assert cat.animal_type == "Cat"
      end

      {:ok, cats_and_dogs} =
        Animal
        |> query()
        |> filter(animal_type: "Dog")
        |> filter(:or, animal_type: "Cat")
        |> Repo.resolve()

      {:ok, male_dogs_and_female_cats} =
        Animal
        |> query()
        |> filter(animal_type: "Dog")
        |> filter(sex: :male)
        |> filter(:or, {:and, animal_type: "Cat", sex: :female})
        |> Repo.resolve()

      for animal <- male_dogs_and_female_cats do
        assert (animal.animal_type == "Cat" and animal.sex == :female) or
                 (animal.animal_type == "Dog" and animal.sex == :male)
      end

      {:ok, female_dogs_and_male_cats} =
        Animal
        |> query()
        |> filter(animal_type: "Cat")
        |> filter(sex: :male)
        |> filter(:or, {:and, animal_type: "Dog", sex: :female})
        |> Repo.resolve()

      for animal <- female_dogs_and_male_cats do
        assert (animal.animal_type == "Dog" and animal.sex == :female) or
                 (animal.animal_type == "Cat" and animal.sex == :male)
      end

      assert 473 == length(dogs) + length(cats)
      assert 473 == length(male_dogs_and_female_cats) + length(female_dogs_and_male_cats)
      assert 473 == length(cats_and_dogs)
    end

    test "expand" do
      assert {:ok, authors} =
               Biblio.Author
               |> query()
               |> filter(name: "Terry Pratchett")
               |> expand(:author_of)
               |> Biblio.Repo.resolve()

      assert %Biblio.Book{} = List.first(Map.fetch!(List.first(authors), :author_of))
    end
  end
end
