defmodule GimTest.Animal do
  use Gim.Schema

  # alias GimTest.Movies.{Genre, Person, Performance}
  @keys [
    :impound_no,
    :intake_date,
    :intake_type,
    :animal_type,
    :neutered_status,
    :sex,
    :age_intake,
    :condition,
    :breed,
    :aggressive,
    :independent,
    :intelligent,
    :loyal,
    :social,
    :good_with_kids,
    :max_life_expectancy,
    :max_weight,
    :dog_group,
    :color,
    :weight,
    :lab_test,
    :outcome_date,
    :outcome_type,
    :days_shelter
  ]

  @boolean [
    :neutered_status,
    :aggressive,
    :independent,
    :intelligent,
    :loyal,
    :social,
    :good_with_kids
  ]

  @ints [
    :age_intake,
    :max_life_expectancy,
    :max_weight,
    :days_shelter
  ]

  @floats [:weight]

  schema do
    property(:impound_no, index: :primary)
    property(:intake_date)
    property(:intake_type)
    property(:animal_type, index: true)
    property(:neutered_status)
    property(:sex)
    property(:age_intake)
    property(:condition)
    property(:breed)
    property(:aggressive)
    property(:independent)
    property(:intelligent)
    property(:loyal)
    property(:social)
    property(:good_with_kids)
    property(:max_life_expectancy)
    property(:max_weight)
    property(:dog_group)
    property(:color)
    property(:weight)
    property(:lab_test)
    property(:outcome_date)
    property(:outcome_type)
    property(:days_shelter)
  end

  def data do
    path = Path.join(["etc", "AnimalData.csv"])

    path
    |> File.stream!([])
    |> NimbleCSV.RFC4180.parse_stream()
    # |> Stream.filter(fn [head | _tail] -> IO.inspect(head) != "Impound.No" end)
    |> Stream.map(&map/1)
  end

  def map(animal) when is_list(animal) and length(animal) == 24 do
    data = Enum.map(List.zip([@keys, animal]), &cast/1)

    struct(__MODULE__, data)
  end

  def cast(pair)

  def cast({key, "NA"}) do
    {key, nil}
  end

  def cast({key, value}) when key in @ints do
    {value, ""} = Integer.parse(value)
    {key, value}
  end

  def cast({key, value}) when key in @floats do
    {value, ""} = Float.parse(value)
    {key, value}
  end

  def cast({key, "Y"}) when key in @boolean do
    {key, true}
  end

  def cast({key, "N"}) when key in @boolean do
    {key, false}
  end

  def cast({key, "Male"}) when key == :sex do
    {key, :male}
  end

  def cast({key, "Female"}) when key == :sex do
    {key, :female}
  end

  def cast({_, _} = pair) do
    pair
  end
end
