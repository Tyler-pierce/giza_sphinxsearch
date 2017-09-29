defmodule Giza.Mixfile do
  use Mix.Project

  def project do
    [app: :giza_sphinxsearch,
     version: "0.1.4",
     elixir: "~> 1.4",
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
    [{:ex_doc, "~> 0.14", only: :dev, runtime: false},
     {:httpoison, "~> 0.13"},
     {:mariaex, "~> 0.8.2"}]
  end

  defp description do
    """
    Sphinx Search client based on Giza and updated for Elixir and OTP. Sphinx is simple, highly configurable, lightweight, robust
    and FAST.  Now handles search suggestions for autocomplete and all 3 Sphinx query engines (SphinxQL, Native protocol, and HTTP API).
    """
  end

  defp package do
    [name: :giza_sphinxsearch,
     description: "Sphinx Client for Elixir",
     files: ["lib", "giza_erlang", "mix.exs", "README.md"],
     maintainers: ["Tyler Pierce"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => "https://github.com/Tyler-pierce/giza_sphinxsearch"},
     source_url: "https://github.com/Tyler-pierce/giza_sphinxsearch"]
  end
end
