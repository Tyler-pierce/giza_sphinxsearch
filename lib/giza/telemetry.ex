defmodule Giza.Telemetry do
  @moduledoc """
  Telemetry events emitted by Giza.

  Giza uses `:telemetry` to emit events around SphinxQL query execution,
  following the same span convention used by Ecto and other Elixir libraries.

  ## Events

  ### `[:giza, :query, :start]`

  Emitted before the query is sent to the adapter.

  Measurements:
    - `:system_time` — `System.system_time/0`

  Metadata:
    - `:query` — the raw query string sent to the adapter
    - `:source` — the table/index name (from `SphinxqlQuery.from`), or `nil`

  ### `[:giza, :query, :stop]`

  Emitted after a successful query execution.

  Measurements:
    - `:duration` — elapsed time in native units (use `System.convert_time_unit/3`)

  Metadata:
    - `:query` — the raw query string
    - `:source` — the table/index name, or `nil`
    - `:result` — the `{:ok, %SphinxqlResponse{}}` or `{:error, reason}` tuple

  ### `[:giza, :query, :exception]`

  Emitted when the query raises an exception.

  Measurements:
    - `:duration` — elapsed time in native units

  Metadata:
    - `:query` — the raw query string
    - `:source` — the table/index name, or `nil`
    - `:kind` — `:throw`, `:error`, or `:exit`
    - `:reason` — the exception or thrown value
    - `:stacktrace` — the stacktrace
  """

  @doc false
  def span(query_string, source, fun) do
    metadata = %{query: query_string, source: source}

    :telemetry.span([:giza, :query], metadata, fn ->
      result = fun.()
      {result, Map.put(metadata, :result, result)}
    end)
  end
end
