defmodule Giza.Service do
  @moduledoc """
  The Giza genserver worker.  Handles result calling that can be supervised and handled upon any issue or crash. Note that multiple
  workers would be needed for concurrency.  Avoid using this service if your requests are already concurrent and you don't
  want to set up multiple service workers, as Sphinx can handle many concurrent requests and bottlenecks should be avoided.
  """
  use GenServer

  alias Giza.SphinxProtocol

  ### GenServer

  @spec start_link(Keyword.t) :: GenServer.on_start
  def start_link([{:name, name}|opts]) do
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  GenServer.init/1 callback

  Start http service and initialize sphinx with connection options that will be used in every query
  """
  def init(_) do
    _ = case Code.ensure_loaded(HTTPoison) do
      {:module, poison} ->
        poison.start()
      _ ->
        false
    end

    giza_query_default_state = :giza_query.new() 
      |> :giza_query.host(Application.get_env(:giza_sphinxsearch, :host, "localhost"))
      |> :giza_query.http_port(Application.get_env(:giza_sphinxsearch, :http_port, 9308))
      |> :giza_query.port(Application.get_env(:giza_sphinxsearch, :port, 9312))

    {:ok, giza_query_default_state}
  end

  @doc """
  GenServer.handle_call/3 callback

  Handle request to query Sphinx via Sphinx protocol directly
  """
  def handle_call({:protocol_send, query}, _from, query_state) do
    result = query
      |> SphinxProtocol.connection(:giza_query.host(query_state), :giza_query.port(query_state))
      |> SphinxProtocol.send()

    case result do
      {:ok, giza_result} ->
        {:reply, {:ok, Giza.result_tuple_to_map(giza_result)}, query_state}
      result ->
        {:reply, result, query_state}
    end
  end

  @doc """
  GenServer.handle_call/3 callback

  Handle request to query via Sphinx Http API
  """
  def handle_call({:http_send, query}, _from, query_state) do
    url = "http://" <> :giza_query.host(query_state) <> ":" <> :giza_query.http_port(query_state) <> "/"

    result = HTTPoison.post url, "{\"body\": \"" <> query <> "\"}", [{"Content-Type", "application/json"}]

    {:reply, result, query_state}
  end

  @doc """
  GenServer.handle_call/3 callback

  Handle request to query via SphinxQL
  """
  def handle_call({:sphinxql_send, query}, _from, query_state) do
    result = Giza.SphinxQL.send(query)

    {:reply, result, query_state}
  end

  ### Client API / Helper functions

  @doc """
  Send a query using the native sphinx protocol
  """
  def protocol_send(query) do 
    GenServer.call(__MODULE__, {:protocol_send, query})
  end

  @doc """
  Send a query using the Sphinx HTTP API (Experimental)
  """
  def http_send(query) do
    GenServer.call(__MODULE__, {:http_send, query})
  end

  @doc """
  Send a query using SphinxQL (Recommended)
  """
  def sphinxql_send(query) do
    GenServer.call(__MODULE__, {:sphinxql_send, query})
  end
end