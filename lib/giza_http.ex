defmodule Giza.Http do
	@moduledoc """
	Query building helper functions for HTTP Sphinx API requests and responses. Add customizations such as limits and matches to a
	query.  When Sphinx 3.x is released this library will become much more fleshed out; however in the meantime it should satisfy
	most production search needs.
	"""

	alias Giza.Structs.HttpQuery

	@doc """
	Return a http api query structure with default values

	## Examples

		iex> Giza.http.new() |> ...
	"""
	def new() do
		%HttpQuery{}
	end

	@doc """
	Return an api query augmented with a select statement. Either a string (binary) or list of fields
	is acceptable input.

	## Examples

		iex> Giza.Http.new() |> Giza.Http.select(["title", "body", "id"])
	"""
	def select(%HttpQuery{} = http_query, fields) when is_binary(fields) do
		select(http_query, String.split(fields, ","))
	end

	def select(%HttpQuery{} = http_query, fields) when is_list(fields) do
		http_query_new = %{http_query | :select => Enum.map(fields, fn(x) -> String.trim(x) end)}
		http_query_new
	end

	@doc """
	Returns an api query augmented with a table to select from. Currently in this first version of the api
	only one table can be selected from.

	## Examples

		iex> Giza.Http.new() |> Giza.Http.from("posts")
	"""
	def from(%HttpQuery{} = http_query, table) when is_binary(table) do
		http_query_new = %{http_query | :from => table}
		http_query_new
	end

	@doc """
	Returns an api query augmented with a where clause which will be formated as a MATCH query, a common way
	of asking Sphinx for search matches.

	## Examples

		iex> Giza.Http.new() |> Giza.Http.match("Subetei the Swift")
	"""
	def match(%HttpQuery{} = http_query, search_term) when is_binary(search_term) do
		http_query_new = %{http_query | :where => "MATCH('" <> String.trim(search_term) <> "')"}
		http_query_new
	end

	@doc """
	Returns an api query augmented with a free form where clause. Usually not needed as other helpers will format
	most types of where queries.

	## Examples

		iex> Giza.Http.new() |> Giza.Http.where("MATCH('tengri')")
	"""
	def where(%HttpQuery{} = http_query, where) when is_binary(where) do
		http_query_new = %{http_query | :where => String.trim(where)}
		http_query_new
	end

	@doc """
	Returns an api query augmented with a limit for amount of returned documents.  Note that Sphinx also allows for setting
	an internal limit in configuration.  Only an integer is acceptable input.

	## Examples

		iex> Giza.Http.new() |> Giza.Http.limit(1)
	"""
	def limit(%HttpQuery{} = http_query, limit) when is_integer(limit) do
		http_query_new = %{http_query | :limit => limit}
		http_query_new
	end 

	@doc """
	Returns an api query augmented with a limit for amount of returned documents.  Only an integer is acceptable input. This
	is normally used to support pagination.

	## Examples

		iex> Giza.Http.new() |> Giza.Http.offset(10)
	"""
	def offset(%HttpQuery{} = http_query, offset) when is_integer(offset) do
		http_query_new = %{http_query | :offset => offset}
		http_query_new
	end

	def send(_query) do
		
	end
end