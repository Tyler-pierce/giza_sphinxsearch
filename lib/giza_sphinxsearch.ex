defmodule Giza do

  alias Giza.{Query}

  @moduledoc """
  Giza Sphinx Search client.
  """

  @doc """
  Build a query for your configured sphinx instance to search against the passed index and phrase

  ## Examples

      iex> Giza.query('postsummary_fast_index postsummary_slow_index', 'baggy')
      {:giza_query, 'localhost', 9312, 0, 275,
      "postsummary_fast_index postsummary_slow_index", 0, 25, 0, 0, 1000, 0, 0, "",
      "", 0, "@group desc", "test", [], 0, [], [], 0}

  """
  def query(index, search_phrase) do
    Query.new(index, search_phrase)
      |> Query.connection()
  end
end
