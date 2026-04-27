defmodule Giza.Mixfile do
  use Mix.Project

  def project do
    [app: :giza_sphinxsearch,
     version: "2.1.1",
     elixir: "~> 1.9",
     erlc_paths: ["giza_erlang"],
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description(),
     deps: deps(),
     package: package()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger], mod: {Giza.Application, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:ex_doc, "~> 0.16", only: :dev, runtime: false},
      {:req, "~> 0.5"},
      {:myxql, "~> 0.7"},
      {:telemetry, "~> 1.0"}
    ]
  end

  defp description() do
    """
    Giza: Sphinx & Manticore Fulltext Search client for Elixir. Sphinx is a simple, highly configurable, 
    lightweight, robust and fast search service. Feature rich: vector search, distributed, sharding, 
    percolated, search suggestions, real time index.
    """
  end

  defp package do
    [name: :giza_sphinxsearch,
     description: "Giza: Manticore Client for Elixir",
     files: ["lib", "test", "config", "giza_erlang", "mix.exs", "README.md"],
     maintainers: ["Tyler Pierce"],
     licenses: ["Apache-2.0"],
     links: %{
      "GitHub" => "https://github.com/Tyler-pierce/giza_sphinxsearch", 
      "Sphinx Search" => "http://sphinxsearch.com/",
      "Manticore Search" => "https://manticoresearch.com/"},
     source_url: "https://github.com/Tyler-pierce/giza_sphinxsearch"]
  end
end
