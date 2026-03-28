defmodule Giza.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {MyXQL,
       name: :mysql_sphinx_client,
       hostname: Application.get_env(:giza_sphinxsearch, :host, "localhost"),
       port: Application.get_env(:giza_sphinxsearch, :sql_port, 9306),
       username: ""}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Giza.Supervisor)
  end
end
