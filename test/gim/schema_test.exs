defmodule GimTest.SchemaTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  setup context do
    on_exit(fn ->
      [Target, Source]
      |> Enum.each(fn mod ->
        if Code.ensure_loaded?(mod) do
          :code.delete(mod)
          :code.purge(mod)
        end
      end)
    end)

    context
  end

  describe "Reflects" do
    test "missing target" do
      assert_raise Gim.SchemaError,
                   "The targeted edge :target_edge is not present in Target",
                   fn ->
                     Code.compile_quoted(
                       quote do
                         defmodule Target do
                           use Gim.Schema

                           schema do
                             property(:prop)
                           end
                         end

                         defmodule Source do
                           use Gim.Schema

                           schema do
                             property(:prop)
                             has_edge(:target, Target, reflect: :target_edge)
                           end
                         end
                       end
                     )
                   end
    end

    test "Wrong target type" do
      assert_raise Gim.SchemaError,
                   "The type of the target edge :target_edge in Source is Target but was expected to be Source\n",
                   fn ->
                     Code.compile_quoted(
                       quote do
                         defmodule Target do
                           use Gim.Schema

                           schema do
                             property(:prop)
                             has_edge(:target_edge, Target)
                           end
                         end

                         defmodule Source do
                           use Gim.Schema

                           schema do
                             property(:prop)
                             has_edge(:target, Target, reflect: :target_edge)
                           end
                         end
                       end
                     )
                   end
    end

    test "Missing reflect" do
      output =
        capture_io(:stdio, fn ->
          Kernel.ParallelCompiler.compile(["etc/target.ex", "etc/source.ex"])
        end)

      assert String.contains?(
               output,
               "\*\* (Gim.SchemaError) Bidirectional edges should target each other.\nAdd a reflect to the target edge"
             )
    end

    test "Not a gim schema" do
      assert_raise Gim.SchemaError,
                   "The target type Atom is not a gim schema",
                   fn ->
                     Code.compile_quoted(
                       quote do
                         defmodule Source do
                           use Gim.Schema

                           schema do
                             property(:prop)
                             has_edge(:target, Atom)
                           end
                         end
                       end
                     )
                   end
    end
  end
end
