defmodule Mix.Tasks.Giza.Sphinx.Index do
  use Mix.Task

  @shortdoc "Shortcut to run the Sphinx Indexer"

  @moduledoc """
  Mix shortcut to running the Sphinx Indexer to build an index against the data source.

  Options:

  Called without argument, indexer will run all indexes.  If you want to re-run the indexes while
  searchd is running, use rotate as a first option and you will seamlessly rotate the new indexes in.

  You can also append options that will override all and index only specific indexes.

  ## Example

      > mix giza.sphinx.index rotate

      > mix giza.sphinx.index rotate blog_posts blog_authors

      > mix giza.sphinx.index blog_posts
  """

  def run([]) do
    run_command(["-c", "sphinx/sphinx.conf", "--all"])
  end

  def run(["rotate"|options]) do
    indices = case options do
      [] ->
        ["--all"]
      _ ->
        options
    end

    run_command(["-c", "sphinx/sphinx.conf", "--rotate"|indices])
  end

  def run(indices) do
    run_command(["-c", "sphinx/sphinx.conf"] ++ indices)
  end

  defp run_command(options) do
    {result, _} = System.cmd("indexer", options)

    print_command_result(result)

    Mix.shell.info "Indexing complete"
  end

  defp print_command_result(result) do
    results = String.split(result, "\n")

    for result <- results do
      IO.inspect result
    end
  end
end