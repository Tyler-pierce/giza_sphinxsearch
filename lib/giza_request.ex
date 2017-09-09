defmodule Giza.Request do
	@moduledoc """
	Send query to Sphinx Daemon and return results syncronously using sphinx native protocol. Module could be removed/refactored soon.
	"""

	@doc """
	Sends a query to the configured host and port.  First build a query using Giza.Query
	and use this to retrieve your results.

	## Examples

		iex> Giza.Request.send(query)
		{:giza_query_result, [...matches...], {..attrs..}, {..fields..}, [..words..], 20, 1000, 0.00325, ?SEARCHD_OK, []} = giza_response
	"""
	def send(query) do
		:giza_request.send(query)
	end
end