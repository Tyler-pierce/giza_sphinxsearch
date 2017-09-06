defmodule Giza do
  @moduledoc """
  Giza Sphinx Search client. The Giza core class provides wrapping to make using Sphinx easy in the typical infrastructure of an
  elixir application.  Any Giza functionality is easiest to use when started by piping a request starting
  here. All functionality is available through Giza.Query, Giza.Request etc.. this module aims to be agnostic of the query type
  (native, sphinxQL, http, real-time) and may become a protocol at some point.
  """

  alias Giza.{Query, Request}
  alias Giza.Structs.{SphinxqlResponse}

  @doc """
  Create a query based on the supplied index(es) and search phrase.  This is the easiest way to start building a query to Sphinx and
  supports piping to all Giza.Query's interface. Returns a tuple suitable for sending to Giza's erlang parser for speaking the sphinx
  native format.

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

  @doc """
  Send a request to the configured sphinx daemon.  The results will be parsed as a map for easy pattern matching on whatever parts of the
  result of interest.  Words returns a tuple with the search phrase, the amount of documents found containing a hit, and the amount of total
  hits (well enough weighted match to return a result).

  ## Examples

    iex> Giza.send(query)
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
  def send(query) do
    case Request.send(query) do
      {:ok, result} ->
        {:ok, parse_result(result)}
      {:error, error} ->
        {:error, error}
    end
  end

  def send!(query) do
    case Request.send(query) do
      {:ok, result} ->
        parse_result(result)
      {:error, error} ->
        error
    end
  end

  @doc """
  Take a giza result tuple and return it as a map

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

  @doc """
  Takes a giza result from a search and returns a list of the document id's

  ## Examples

      iex> SmileysSearch.get_doc_ids(giza_result)
      {:ok, [1, 5, 6, 7], 4}
  """
  def get_doc_ids(giza_result) do
    case giza_result do
      {:ok, %SphinxqlResponse{matches: matches, fields: fields}} ->
        id_position = find_id_position(fields, 0)

        case id_position do
          nil ->
            {:error, "No id field found (Giza defaults to looking for the id field)"}
          _ ->
            {:ok, get_sphinxql_doc_ids(matches, id_position, [])}
        end
      {:ok, %{matches: matches, total: total}} ->
        {:ok, get_doc_ids(matches, []), total}
      {:error, error} ->
        {:error, error}
    end
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
end
