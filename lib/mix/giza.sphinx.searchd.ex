defmodule Mix.Tasks.Giza.Sphinx.Searchd do
  @moduledoc """
  Mix wrapper to run searchd
  """
  use Mix.Task

  @shortdoc "Shortcut to run the Sphinx Search Daemon"


  def run([]) do
    {result, _} = System.cmd("searchd", [])

    Mix.shell.info result

    Mix.shell.info "Searchd run"
  end
end