defmodule Giza.Mixfile do
  use Mix.Project

  def project do
    [app: :giza_sphinxsearch,
     version: "1.0.6",
     elixir: "~> 1.5",
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
    [extra_applications: [:logger]]
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
    [{:ex_doc, "~> 0.16", only: :dev, runtime: false},
     {:httpoison, "~> 1.3"},
     {:mariaex, "~> 0.9"}]
  end

  defp description() do
    """
    Giza: Sphinx Fulltext Search client for Elixir. Sphinx is a simple, highly configurable, lightweight, robust
    and FAST search indexer and daemon.  Feature rich: distributed index, search suggestions, real time index,
    much more. Giza also supports the Manticore fork.
    """
  end

  defp package do
    [name: :giza_sphinxsearch,
     description: "Giza: Sphinx Client for Elixir",
     files: ["lib", "giza_erlang", "sphinx", "mix.exs", "README.md"],
     maintainers: ["Tyler Pierce"],
     licenses: ["Apache 2.0"],
     links: %{
      "GitHub" => "https://github.com/Tyler-pierce/giza_sphinxsearch", 
      "Sphinx Search" => "http://sphinxsearch.com/",
      "Manticore Search" => "https://manticoresearch.com/"},
     source_url: "https://github.com/Tyler-pierce/giza_sphinxsearch"]
  end
end
