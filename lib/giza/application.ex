defmodule Giza.Application do
  @moduledoc false

  use Supervisor

  def start_link(_args) do
    Supervisor.start_link(__MODULE__, [], [])
  end

  def init(opts) do
    workers = get_workers(opts, Keyword.get(opts, :workers, []), [])

    sql_client =
      {Mariaex,
       name: :mysql_sphinx_client,
       hostname: Application.get_env(:giza_sphinxsearch, :host, "localhost"),
       port: Application.get_env(:giza_sphinxsearch, :sql_port, 9306),
       username: "",
       skip_database: true,
       sock_type: :tcp}

    Supervisor.init([sql_client | workers], strategy: :one_for_one)
  end

  defp get_workers(_, [], acc), do: acc

  defp get_workers(opts, [name | t], acc) do
    get_workers(opts, t, [
      {Giza.Service,
       name: name,
       host: Application.get_env(:giza_sphinxsearch, :host, "localhost"),
       port: Application.get_env(:giza_sphinxsearch, :port, 9312)}
      | acc
    ])
  end
end
