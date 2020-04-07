defmodule GimTest.QueryTest do
  @moduledoc false
  use ExUnit.Case, async: false

  import Gim.Query, only: [query: 1, filter: 2, filter: 3]

  alias Gim.Repo.Table
  alias GimTest.Animal

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
    []
  end

  @tag query: true
  test "all" do
    {:ok, animals} =
      Animal
      |> query()
      |> Repo.resolve()

    assert 473 == length(animals)
  end

  @tag query: true
  test "fetch" do
    assert {:ok, [%Animal{impound_no: "K12-000416"}]} =
             Animal
             |> query()
             |> filter(impound_no: "K12-000416")
             |> Repo.resolve()
  end

  @tag query: true
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
end
