defmodule Mix.Tasks.Giza.Sphinx.Searchd do
  @moduledoc """
  Mix shortcut to running the Sphinx Indexer to build an index against the data source
  """
  use Mix.Task

  @shortdoc "Shortcut to run the Sphinx Search Daemon"


  def run([]) do
    {result, _} = System.cmd("searchd", ["-c", "sphinx/sphinx.conf"])

    print_command_result(result)

    Mix.shell.info "Searchd run"
  end

  defp print_command_result(result) do
    results = String.split(result, "\n")

    for result <- results do
      IO.inspect result
    end
  end
end