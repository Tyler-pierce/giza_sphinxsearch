defmodule Giza.SphinxQL.Recipe do
  @moduledoc """
  Query building helper functions for SphinxQL designed in commonly useful ways.  Provides guidance when
  trying to take advantage of advanced search functionality without having to know every nuance of sphinx'
  query language.
  """

  alias Giza.SphinxQL
  alias Giza.Structs.SphinxqlQuery

  @doc """
  Influence your search results by how recently they were added or updated (or whatever the date field you pass
  represents).  For the example below ensure you are selecting the date in your index as a unix timestamp (mysql: 
  UNIX_TIMESTAMP(updated_timestamp), postgres: extract(epoch from updated_timestamp)).

  ## Example

      iex> SphinxQL.new()
      |> SphinxQL.from("blog_posts")
      |> SphinxQL.match("red clown")
      |> SphinxQL.Recipe.weigh_by_date("last_updated_timestamp")
      |> SphinxQL.send()

      %SphinxqlResponse{ .. }

  """
  def weigh_by_date(%SphinxqlQuery{} = query, timestamp_field \\ "updated_timestamp") when is_binary(timestamp_field) do
    ranker = "ranker = expr('sum((extract(epoch FROM now()) - #{timestamp_field})/1000 + (lcs*user_weight))*1000+bm25')"

    SphinxQL.option(query, ranker)
  end

  @doc """
  Search on a string and add on as many filters as wanted. This can be used to add simple constraints to a search.

  ## Example

      iex> SphinxQL.new()
      |> SphinxQL.from("blog_comments")
      |> SphinxQL.Recipe.match_and_filter("subetei", post_id: 1, depth: 2)
      |> SphinxQL.send()

      %SphinxqlResponse{ .. }
  """
  def match_and_filter(%SphinxqlQuery{} = query, search_string, filters) do
    filter_string = build_filter_string(filters, [])

    SphinxQL.where(query, "MATCH('#{search_string}') AND #{filter_string}")
  end

  defp build_filter_string([], acc), do: Enum.join(acc, " AND ")

  defp build_filter_string([{field, filter}|filters], acc) when is_integer(filter) do
    field = Atom.to_string(field)

    build_filter_string(filters, ["#{field} = #{filter}"|acc])
  end

  defp build_filter_string([{field, filter}|filters], acc) when is_binary(filter) do
    build_filter_string(filters, ["#{field} = '#{filter}'"|acc])
  end
end