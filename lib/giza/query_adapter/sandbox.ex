defmodule Giza.QueryAdapter.Sandbox do
  @moduledoc """
  Test adapter that records every executed query and returns configurable
  responses.  No running Sphinx/Manticore instance is required.

  ## Setup

  Start the sandbox in `test/test_helper.exs`:

      Giza.QueryAdapter.Sandbox.start_link()
      ExUnit.start()

  And configure it in `config/test.exs`:

      config :giza_sphinxsearch, :query_adapter, Giza.QueryAdapter.Sandbox

  ## Usage in tests

      setup do
        Giza.QueryAdapter.Sandbox.reset()
        :ok
      end

      test "my query" do
        # default response is {:ok, %{columns: [], rows: [], num_rows: 0}}
        {:ok, _} = SearchTables.create_table("t", "title text")

        assert Sandbox.last_query() == "CREATE TABLE t (title text)"
        assert length(Sandbox.queries()) == 1
      end

  ## Custom responses

      # Static response for all queries
      Sandbox.set_response({:ok, %{columns: ["id"], rows: [[1]], num_rows: 1}})

      # Function response — inspect the SQL to decide what to return
      Sandbox.set_response({:fn, fn
        "DESCRIBE" <> _ -> {:ok, %{columns: ["Field", "Type"], rows: [["title", "text"]], num_rows: 1}}
        _ -> {:ok, %{columns: [], rows: [], num_rows: 0}}
      end})

      # Simulate an error
      Sandbox.set_response({:error, %{mariadb: %{message: "table not found"}}})
  """

  @behaviour Giza.QueryAdapter

  use Agent

  def start_link(_opts \\ []) do
    Agent.start_link(fn -> initial_state() end, name: __MODULE__)
  end

  @doc "Clear recorded queries and reset the response to the default."
  def reset do
    Agent.update(__MODULE__, fn _state -> initial_state() end)
  end

  @doc """
  Set the response returned by `execute/1`.

  Accepts a static term (returned as-is) or `{:fn, fun}` where `fun` receives
  the query string and returns the response.
  """
  def set_response(response) do
    Agent.update(__MODULE__, fn state -> %{state | response: response} end)
  end

  @doc "Return the list of query strings executed so far, in chronological order."
  def queries do
    Agent.get(__MODULE__, fn state -> Enum.reverse(state.queries) end)
  end

  @doc "Return the most recently executed query string, or `nil`."
  def last_query do
    Agent.get(__MODULE__, fn state -> List.first(state.queries) end)
  end

  @doc "Return how many queries have been executed since the last reset."
  def query_count do
    Agent.get(__MODULE__, fn state -> length(state.queries) end)
  end

  # --- QueryAdapter callback ------------------------------------------------

  @impl true
  def execute(query_string) do
    Agent.get_and_update(__MODULE__, fn state ->
      response = resolve_response(state.response, query_string)
      new_state = %{state | queries: [query_string | state.queries]}
      {response, new_state}
    end)
  end

  # --- Private --------------------------------------------------------------

  defp resolve_response({:fn, fun}, query_string) when is_function(fun, 1) do
    fun.(query_string)
  end

  defp resolve_response(response, _query_string), do: response

  defp initial_state do
    %{queries: [], response: {:ok, %{columns: [], rows: [], num_rows: 0}}}
  end
end
