defmodule Mix.Tasks.Giza.Sphinx.Query do
  @moduledoc """
  Mix shortcut to run a query directly against the locally running sphinx instance.

  Use MySQL syntax along with Sphinx specific commands while Sphinx search daemon is running.

  ## Examples

      > mix giza.sphinx.query "SELECT * FROM i_blog WHERE MATCH('swift messenger')"
  """
  use Mix.Task

  @shortdoc "Run a query against the locally running sphinx instance"


  def run([query]) do
    {result, _} = System.cmd("mysql", ["-h", "0", "-P", "9306", "-e", query])

    Mix.shell.info result

    Mix.shell.info "Query run"
  end

  def run(_) do
    Mix.shell.info "Sphinx.Query expects 1 argument (a SphinxQL Query)"
  end
end