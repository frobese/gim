defmodule GimTest.RepoTest do
  use ExUnit.Case

  test "Missing Type" do
    assert_raise Gim.NoSuchTypeError,
                 "GimTest.Biblio.Book has an edge targeting GimTest.Biblio.Publisher which is not part of the Repository\n",
                 fn ->
                   Code.eval_quoted(
                     quote do
                       defmodule Test.Repo do
                         use Gim.Repo,
                           types: [
                             GimTest.Biblio.Author,
                             GimTest.Biblio.Book
                           ]
                       end
                     end
                   )
                 end
  end
end
