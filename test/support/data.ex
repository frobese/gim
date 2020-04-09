defmodule GimTest.Data do
  @moduledoc false

  def check({path, _url, md5_sum}) do
    if File.exists?(path) do
      if md5_sum == md5_hash(path) do
        :ok
      else
        {:error, :hash}
      end
    else
      {:error, :nofile}
    end
  end

  def download({path, url, md5_sum}) do
    with :ok <- download_prep(),
         {:ok, body} <- do_download(url),
         ^md5_sum <- String.downcase(Base.encode16(:crypto.hash(:md5, body))) do
      File.write(path, body)
    else
      {:error, _} = error -> error
      _hash -> {:error, :hash}
    end
  end

  defp do_download(url) when is_binary(url) do
    url
    |> String.to_charlist()
    |> do_download()
    |> case do
      {:ok, {{_, 200, _}, _header, body}} -> {:ok, body}
      {:error, _} = error -> error
      error -> {:error, error}
    end
  end

  defp do_download(url) do
    :httpc.request(:get, {url, []}, [], [])
  end

  defp download_prep do
    inets =
      case :inets.start() do
        :ok -> :ok
        {:error, {:already_started, :inets}} -> :ok
        error -> error
      end

    if inets == :ok do
      case :ssl.start() do
        :ok -> :ok
        {:error, {:already_started, :ssl}} -> :ok
        error -> error
      end
    else
      inets
    end
  end

  defp md5_hash(path) do
    path
    |> File.stream!([:read, :binary], 1024 * 1024)
    |> Enum.reduce(:crypto.hash_init(:md5), &:crypto.hash_update(&2, &1))
    |> :crypto.hash_final()
    |> Base.encode16()
    |> String.downcase()
  end
end
