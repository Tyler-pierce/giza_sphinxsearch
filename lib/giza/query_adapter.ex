defmodule Giza.QueryAdapter do
  @moduledoc """
  Behaviour for executing raw query strings against Sphinx/Manticore.

  The default implementation (`Giza.QueryAdapter.MyXQL`) sends the query over
  the MySQL protocol via the MyXQL library.  In test, swap in
  `Giza.QueryAdapter.Sandbox` to record queries and return canned responses
  without a running search daemon.

  Configure the adapter in your application config:

      config :giza_sphinxsearch, :query_adapter, Giza.QueryAdapter.Sandbox
  """

  @type raw_result :: {:ok, map()} | {:error, term()}

  @callback execute(query_string :: String.t()) :: raw_result()
end
