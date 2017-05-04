defmodule Giza.Mixfile do
  use Mix.Project

  def project do
    [app: :giza_sphinxsearch,
     version: "0.0.1",
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
    []
  end

  defp description do
    """
    Reviving the old Giza erlang client for sphinx full text search in Elixir. Sphinx is quality software 
    and this writers preferred full text search engine.  It is simple, highly configurable, lightweight, robust
    and FAST.  This project wraps the older Giza project's erlang calls and as implementing newer Sphinx features, 
    will start to take over as a fully elixir based project.
    """
  end

  defp package do
    [name: :giza_sphinxsearch,
     files: ["lib", "giza_erlang", "mix.exs", "README", "LICENSE*"],
     maintainers: ["Tyler Pierce"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => "https://github.com/Tyler-pierce/giza_sphinxsearch"},
     source_url: "https://github.com/Tyler-pierce/giza_sphinxsearch"]
  end
end
