defmodule Giza.Service do
  use GenServer

  ### GenServer

  @spec start_link(Keyword.t) :: GenServer.on_start
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  GenServer.init/1 callback

  Start http service and initialize sphinx with connection options that will be used in every query
  """
  def init(opts) do
    HTTPoison.start

    giza_query_default_state = :giza_query.new() 
      |> :giza_query.host(Keyword.get(opts, :host, "localhost"))
      |> :giza_query.http_port(Keyword.get(opts, :http_port, 9308))
      |> :giza_query.port(Keyword.get(opts, :port, 9312))

    {:ok, giza_query_default_state}
  end

  @doc """
  GenServer.handle_call/3 callback

  Handle request to query Sphinx via Sphinx protocol directly
  """
  def handle_call({:send, query}, _from, query_state) do
    result = query
      |> Giza.Query.connection(:giza_query.host(query_state), :giza_query.port(query_state))
      |> Giza.Request.send()

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
  def send(query) do 
    GenServer.call(__MODULE__, {:send, query})
  end

  def http_send(query) do
    GenServer.call(__MODULE__, {:http_send, query})
  end

  def sphinxql_send(query) do
    GenServer.call(__MODULE__, {:sphinxql_send, query})
  end
end