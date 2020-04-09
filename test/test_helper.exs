require Logger

# ex_unit_conf = IO.inspect(ExUnit.configuration())

requirements = [
  {GimTest.Animal, :data_animal}
  # {GimTest.Movies, :data_movies}
]

for {module, data_tag} <- requirements do
  try do
    {file, url, _} = data_info = module.data_info

    case GimTest.Data.check(data_info) do
      {:error, _} ->
        Logger.warn([file, " does not exist or is corrupt. Downloading ..."])

        case GimTest.Data.download(data_info) do
          {:error, error} ->
            Logger.warn([
              "Download for ",
              file,
              " from ",
              url,
              " failed with ",
              inspect(error, prettty: true)
            ])

            ExUnit.configure(exclude: [data_tag | ExUnit.configuration()[:exclude]])

          :ok ->
            :ok
        end

      :ok ->
        :ok
    end
  rescue
    error ->
      Logger.warn([
        "Data check for tag  ",
        inspect(data_tag),
        " failed with: ",
        Exception.format(:error, error)
      ])

      ExUnit.configure(exclude: [data_tag | ExUnit.configuration()[:exclude]])
  end
end

ExUnit.start()
