defmodule Mix.Tasks.Giza.Sphinx.Searchd do
  @moduledoc """
  Mix shortcut to running the Sphinx Indexer to build an index against the data source
  """
  use Mix.Task

  @shortdoc "Shortcut to run the Sphinx Search Daemon"


  def run([]) do
    {result, _} = System.cmd("searchd", ["-c", "sphinx/sphinx.conf"])

    Mix.shell.info result

    Mix.shell.info "Searchd run"
  end
end