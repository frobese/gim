defmodule GimTest.TableTest do
  use ExUnit.Case

  alias Gim.Repo.Table
  alias GimTest.Animal

  for module <- [Table.Ets, Table.LegacyEts] do
    mod_name = Module.concat(__MODULE__, module)

    defmodule mod_name do
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
          assert 473 == length(module.all(table))
        end

        @tag table: true
        test "fetch", %{module: module, table: table} do
          assert [%Animal{impound_no: "K12-000416"}] =
                   module.get(table, :impound_no, "K12-000416")
        end

        @tag table: true
        test "dogs and cats", %{module: module, table: table} do
          dogs = module.get(table, :animal_type, "Dog")

          for dog <- dogs do
            assert dog.animal_type == "Dog"
          end

          cats = module.get(table, :animal_type, "Cat")

          for cat <- cats do
            assert cat.animal_type == "Cat"
          end

          assert 473 == length(dogs) + length(cats)
        end
      end
    end
  end
end
