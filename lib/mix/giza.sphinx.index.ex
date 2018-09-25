defmodule Mix.Tasks.Giza.Sphinx.Index do
  @moduledoc """
  Mix shortcut to running the Sphinx Indexer to build an index against the data source
  """
  use Mix.Task

  @shortdoc "Shortcut to run the Sphinx Indexer"


  def run([]) do
    {result, _} = System.cmd("indexer", ["-c", "sphinx/sphinx.conf", "--all"])

    print_command_result(result)

    Mix.shell.info "Indexing complete"
  end

  def run(indices) do
    {result, _} = System.cmd("indexer", ["-c", "sphinx/sphinx.conf"] ++ indices)

    print_command_result(result)
  end

  defp print_command_result(result) do
    results = String.split(result, "\n")

    for result <- results do
      IO.inspect result
    end
  end
end