defmodule Giza do
  @moduledoc ~S"""
  Client for Sphinx Search, the search product built by the legendary Andrew Aksyonoff.  Sphinx is 
  a robust and FAST database indexer and search daemon that can process large amounts of concurrent 
  through-put.  Giza aims to make implementing Sphinx in your Elixir apps quick and simple.  Check
  out the examples below for most use cases and dive deeper if need be through the docs. The github
  docs take an Elixir perspective approach.  This doc here will get you up and running with Sphinx
  and Elixir.

  ## Example
  Let's integrate into a Phoenix App.

  1) Add Giza to dependencies (in mix.exs)

      def deps do
        [{:giza_sphinxsearch, "~> 1.0.1"},
         ...]
      end

  2) Add Giza to your OTP tree in your application file at lib/yourapp/application.ex

      children = [
        ...,
        supervisor(Giza.Application, [])
      ]

  3) Install sphinx or manticore.

      Option: Install from here https://manticoresearch.com/downloads/
      Option: Install from here http://sphinxsearch.com/downloads/current/

  4) Generate a config file.  From your apps directory:

      # Config file will appear in sphinx/sphinx.conf
      > mix giza.sphinx.config

  5) Run the index and start the search daemon

      > mix giza.sphinx.index
      > (Output shown: check for any issues in your indices!)
      > mix.giza.sphinx.searchd

  Now you can use the examples below and throughout the documentation in your code!


  ## Example

      alias Giza.SphinxQL

      SphinxQL.new() 
        |> SphinxQL.suggest("posts_index", "splt")
        |> SphinxQL.send()

      %SphinxqlResponse{fields: ["suggest", "distance", "docs"], matches: [["split", 1, 5]...]}


  ## Example

      SphinxQL.new()
      |> SphinxQL.from("posts, posts_recent")
      |> SphinxQL.match("tengri")
      |> SphinxQL.send()
      |> Giza.get_doc_ids()

      [1, 4, 6, 12, ..]

      {:ok, %{:total_found => last_query_total_found} = Giza.SphinxQL.meta()

      800


  ## Example

      SphinxQL.new()
      |> SphinxQL.raw("SELECT id, WEIGHT() as w FROM posts_index WHERE MATCH('subetei the swift')")
      |> SphinxQL.send()

      %SphinxqlResponse{ .. }  
  """

  alias Giza.Structs.SphinxqlResponse

  @doc """
  Takes a giza result from a search and returns a list of the document id's

  ## Examples

      iex> Giza.get_doc_ids(giza_result)
      {:ok, [1, 5, 6, 7], 4}
  """
  def get_doc_ids(%SphinxqlResponse{matches: matches, fields: fields}) do
    id_position = find_id_position(fields, 0)

    case id_position do
      nil ->
        {:error, "No id field found (Giza defaults to looking for the id field)"}
      _ ->
        {:ok, get_sphinxql_doc_ids(matches, id_position, [])}
    end
  end

  def get_doc_ids({:ok, %{matches: matches, total: total}}), do: {:ok, get_doc_ids(matches, []), total}
  def get_doc_ids(error), do: error

  @doc """
  Take a sphinx protocol giza result from the erlang tcp implementation's tuple and return it as a map easier
  to navigate in Elixir.

  ### Examples

      iex> Giza.result_tuple_to_map({:giza_query_result, ...})
      {:ok,
      %{attrs: [{"title", 7}, {"body", 7}],
      fields: ["title", "body", "tags"],
      matches: [{171,
      [doc_id: 171, weight: 2,
      attrs: [{"title", 7}, {"body", 7}]]}],
      {190,
      ..
      }],
      status: 0, 
      time: 0.008, 
      total: 19, 
      total_found: 19, 
      warnings: [],
      words: [{"test", 19, 23}]
      }
      }
  """
  def result_tuple_to_map(%SphinxqlResponse{} = result) do
    result
  end

  def result_tuple_to_map(result) do
    parse_result(result)
  end

  defp get_doc_ids([], accum) do
    Enum.uniq accum
  end

  defp get_doc_ids([query_attr|tail], accum) do
    {doc_id, _} = query_attr
    new_accum = [doc_id|accum]

    get_doc_ids(tail, new_accum)
  end

  defp get_sphinxql_doc_ids([match|matches], id_position, acc) do
    get_sphinxql_doc_ids(matches, id_position, [Enum.fetch!(match, id_position)|acc])
  end

  defp get_sphinxql_doc_ids([], _, acc) do
    acc
  end

  defp find_id_position([first_field|tail], acc) do
    case first_field do
      "id" ->
        acc
      _ ->
        find_id_position(tail, acc + 1)
    end
  end

  defp find_id_position([], _) do
    nil
  end

  defp parse_result(result) do
    {:giza_query_result, query_matches, attrs, fields, words, total, total_found, time, status, warnings} = result

    %{:matches => query_matches,
      :attrs => attrs,
      :fields => fields,
      :words => words,
      :total => total,
      :total_found => total_found,
      :time => time,
      :status => status,
      :warnings => warnings}
  end
end
