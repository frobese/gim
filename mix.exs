defmodule Gim.MixProject do
  use Mix.Project

  @version "1.2.2"

  def project do
    [
      app: :gim,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def elixirc_paths(env) when env in [:dev, :test] do
    ["test/support" | elixirc_paths(nil)]
  end

  def elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.19", only: :dev},
      # {:jason, "~> 1.0"},
      {:nimble_csv, "~> 0.7", only: [:dev, :test]},
      {:observer_cli, "~> 1.5", only: :dev}
    ]
  end

  defp description do
    "Schema-based In-Memory Graph Database."
  end

  defp docs do
    [
      main: "Gim",
      source_ref: "v#{@version}",
      logo: "images/gim-bildmarke.png",
      canonical: "http://hexdocs.pm/gim",
      source_url: "https://github.com/frobese/gim"
    ]
  end

  defp package do
    [
      maintainers: ["Christian Zuckschwerdt", "Hans Gödeke"],
      files: ~w(lib mix.exs README* LICENSE*),
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/frobese/gim"
      }
    ]
  end
end
