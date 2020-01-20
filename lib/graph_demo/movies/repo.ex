defmodule GraphDemo.Movies.Repo do
  alias GraphDemo.Movies
  alias __MODULE__

  @moduledoc false
  use Gim.Repo,
    types: [
      Movies.Person,
      Movies.Genre,
      Movies.Movie,
      Movies.Performance,
      Movies.Character,
    ]

  # example loader
  def load(%{name: name,
             initial_release_date: initial_release_date,
             genre: genre,
             director: director,
             starring: starring} = _movie) do

    # resolve or create genre, director, starring
    genre = genre |> as_list |> Enum.map(&get_or_create(Movies.Genre, &1))
    director = director |> as_list |> Enum.map(&get_or_create(Movies.Person, &1))
    starring = starring |> as_list |> Enum.map(&get_or_create(Movies.Performance, &1))

    # insert movie
    %Movies.Movie{ name: name, initial_release_date: initial_release_date }
    |> Movies.Movie.add_genre(genre)
    |> Movies.Movie.add_director(director)
    |> Movies.Movie.add_starring(starring)
    |> Repo.insert()
  end
  def load(%Movies.Genre{} = node) do
    get_or_insert(node)
  end
  def load(%Movies.Person{} = node) do
    get_or_insert(node)
  end
  def load(%Movies.Performance{film: film, actor: actor, character: character}) do
    film = get_or_create(Movies.Movie, film)
    actor = get_or_create(Movies.Person, actor)
    character = get_or_create(Movies.Character, character)

    # insert performance -- TODO: this won't resolve
    %Movies.Performance{}
    |> Movies.Performance.set_film(film)
    |> Movies.Performance.set_actor(actor)
    |> Movies.Performance.set_character(character)
    |> Repo.insert()
  end
  def load(%Movies.Character{} = node) do
    get_or_insert(node)
  end

  def example() do
    Repo.load(%{name: "Blade Runner",
                initial_release_date: 1982,
                genre: "Sci-Fi",
                director: "Ridley Scott",
                starring: ["Harrison Ford", "Rutger Hauer"]})
  end

  defp as_list(x) when is_list(x), do: x
  defp as_list(x), do: [x]

  defp get_or_create(type, name) do
    case Repo.fetch(type, :name, name) do
      {:ok, node} -> node
      _ -> struct(type, %{ name: name }) |> Repo.insert()
    end
  end

  defp get_or_insert(%{__struct__: type, name: name} = node) do
    case Repo.fetch(type, :name, name) do
      {:ok, node} -> node
      _ -> node |> Repo.insert()
    end
  end
end
