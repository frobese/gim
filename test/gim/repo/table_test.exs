defmodule GimTest.TableTest do
  @moduledoc false
  use ExUnit.Case

  alias Gim.Repo.Table
  alias GimTest.Animal

  for module <- [Table.Ets] do
    mod_name = Module.concat(__MODULE__, module)

    defmodule mod_name do
      @moduledoc false
      use ExUnit.Case, async: false

      setup_all do
        module = unquote(module)
        table = module.new(__MODULE__, Animal)

        Enum.each(Animal.data(), &module.insert(table, &1))
        [table: table, module: module]
      end

      describe "#{module} -- tests" do
        @tag table: true
        test "basic testing", %{module: module, table: _table} do
          assert module == unquote(module)
        end

        @tag table: true
        test "all", %{module: module, table: table} do
          assert {:ok, animals} = module.query(table, nil, [])
          assert 473 == length(animals)
        end

        @tag table: true
        test "fetch", %{module: module, table: table} do
          assert {:ok, [%Animal{impound_no: "K12-000416"}]} =
                   module.query(table, nil, impound_no: "K12-000416")
        end

        @tag table: true
        test "simple queries", %{module: module, table: table} do
          {:ok, dogs} = module.query(table, nil, animal_type: "Dog")

          for dog <- dogs do
            assert dog.animal_type == "Dog"
          end

          {:ok, cats} = module.query(table, nil, animal_type: "Cat")

          for cat <- cats do
            assert cat.animal_type == "Cat"
          end

          {:ok, cats_and_dogs} =
            module.query(table, nil, {:or, [animal_type: "Cat", animal_type: "Dog"]})

          {:ok, male_dogs_and_female_cats} =
            module.query(
              table,
              nil,
              {:or,
               [
                 {:and, [animal_type: "Cat", sex: :female]},
                 {:and, [animal_type: "Dog", sex: :male]}
               ]}
            )

          for animal <- male_dogs_and_female_cats do
            assert (animal.animal_type == "Cat" and animal.sex == :female) or
                     (animal.animal_type == "Dog" and animal.sex == :male)
          end

          {:ok, female_dogs_and_male_cats} =
            module.query(
              table,
              nil,
              {:or,
               [
                 {:and, [animal_type: "Cat", sex: :male]},
                 {:and, [animal_type: "Dog", sex: :female]}
               ]}
            )

          for animal <- female_dogs_and_male_cats do
            assert (animal.animal_type == "Dog" and animal.sex == :female) or
                     (animal.animal_type == "Cat" and animal.sex == :male)
          end

          assert 473 == length(dogs) + length(cats)
          assert 473 == length(male_dogs_and_female_cats) + length(female_dogs_and_male_cats)
          assert 473 == length(cats_and_dogs)
        end

        @tag table: true
        test "filter with function", %{module: module, table: table} do
          module.query(table, nil, impound_no: &String.ends_with?(&1, "1"))
        end
      end
    end
  end
end
