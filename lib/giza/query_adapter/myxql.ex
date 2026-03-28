defmodule Giza.QueryAdapter.MyXQL do
  @moduledoc """
  Production adapter that sends queries over the MySQL protocol to
  Sphinx/Manticore via the `:mysql_sphinx_client` MyXQL connection.
  """

  @behaviour Giza.QueryAdapter

  @impl true
  def execute(query_string) do
    MyXQL.query(:mysql_sphinx_client, query_string, [], query_type: :text)
  end
end
