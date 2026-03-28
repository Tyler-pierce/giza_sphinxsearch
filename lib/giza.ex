defmodule Giza do
  @moduledoc ~S"""
  Client for Sphinx/Manticore Search

  Sphinx is a robust and fast database indexer and search daemon that can process large amounts of
  concurrent through-put.  Giza aims to make implementing Sphinx in your Elixir apps quick and simple. 
  See examples below for most use cases and dive deeper if need be through the docs.

  See docs or README for more info on Sphinx + Manticore

  ## Up & Running

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

  3) Install sphinx or manticore (making sure searchd is started).

      Option: Install from here https://manticoresearch.com/downloads/
      Option: Install from here http://sphinxsearch.com/downloads/current/

  Now you can use the examples below and throughout the documentation in your code

  ## Examples

      iex> alias Giza.{SearchTable, ManticoreQL}

      iex> SearchTables.create_table("test_table_3", [{"title", "text"}, {"price", "uint"}], fuzzy_match: true)
      
      {:ok, ..}

      iex> SearchTables.insert("test_table", ["title", "price"], ["test", 1])

      {:ok, ..}

      iex> ManticoreQL.new()
           |> ManticoreQL.suggest("test_table", "tst") 
           |> ManticoreQL.send!()

      %SphinxqlResponse{fields: ["suggest", "distance", "docs"], matches: [["split", 1, 5]...]}

      iex> result = ManticoreQL.new()
                    |> ManticoreQL.from("test_table")
                    |> ManticoreQL.match("te*")
                    |> Gize.send!()

      %SphinxqlResponse{fields: ["id", "title", "price"], total: 1, matches: [[1444.., "test", 1]]

      iex> Giza.ids!(result)
      [1444809278530519042]

      iex> SphinxQL.new()
           |> SphinxQL.raw("SELECT id, WEIGHT() as w FROM test_table WHERE MATCH('test')")
           |> SphinxQL.send()

      {:ok, %SphinxqlResponse{ .. }}
  """
  alias Giza.QueryBuilder
  alias Giza.Structs.{SphinxqlQuery, SphinxqlResponse}

  @doc """
  Send a composed query to Sphinx/Manticore & return a result

  ## Examples

    iex> ManticoreQL.new()
      |> ManticoreQL.select(["id", "title", "knn_dist()"])
      |> ManticoreQL.from("articles")
      |> ManticoreQL.knn("embedding", 5, [0.1, 0.2, 0.3, 0.4])
      |> Giza.send()

    {:ok, %SphinxqlResponse{matches: [..], total: 100, ..}}
  """
  def send(%SphinxqlQuery{} = query) do
    query
    |> case do
         %{raw: nil} -> QueryBuilder.query_to_string(query)
         %{raw: raw_query} -> raw_query
       end
    |> run_query()
  end

  @doc """
  Return SphinxqlResponse directly
  """
  def send!(query) do
    {:ok, result} = send(query)

    result
  end

  @doc """
  Retrieve flat list of ids from SphinxqlResponse result. Can optionally pass a field
  name to retrieve.
  """
  def ids!(response, ids \\ "id")

  def ids!(%SphinxqlResponse{fields: fields, matches: matches}, field) do
    i = Enum.find_index(fields, &(&1 == field))

    Enum.map(matches, &Enum.at(&1, i))
  end

  def ids!({:ok, %SphinxqlResponse{} = response}, field), do: ids!(response, field)

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

  # PRIVATE FUNCTIONS
  ###################
  defp run_query(query_string) do
    adapter = Application.get_env(:giza_sphinxsearch, :query_adapter, Giza.QueryAdapter.MyXQL)

    case adapter.execute(query_string) do
      {:ok, %{columns: columns, rows: rows, num_rows: num_rows}} ->
        {:ok, %SphinxqlResponse{matches: rows, fields: columns, total: num_rows}}

      {:error, %{message: message}} ->
        {:error, message}
    end
  end

  defp parse_result(result) do
    {:giza_query_result, query_matches, attrs, fields, words, total, total_found, time, status, warnings} = result

    %{
      :matches => query_matches,
      :attrs => attrs,
      :fields => fields,
      :words => words,
      :total => total,
      :total_found => total_found,
      :time => time,
      :status => status,
      :warnings => warnings
    }
  end
end
