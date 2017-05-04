defmodule Giza.Query do
	defexception message: "query building error"

	@doc """
	Build a new default query against the passed index and phrase

	## Examples

	    iex> Giza.Query.new('postsummary_fast_index postsummary_slow_index', 'baggy')
	    {:giza_query, 'localhost', 9312, 0, 275,
 			"postsummary_fast_index postsummary_slow_index", 0, 25, 0, 0, 1000, 0, 0, "",
 			"", 0, "@group desc", "test", [], 0, [], [], 0}

	"""
	def new(index, search_phrase) do
		search = cond do 
			String.valid?(search_phrase) ->
				to_charlist search_phrase
			is_list(search_phrase) ->
				search_phrase
			true ->
				raise Giza.Query, message: "Invalid search phrase found when building query. Use \"string\" or 'charlist'"
		end

		:giza_query.new(index, search)
	end

	@doc """
	Return a new query with the configured host and port

	## Examples

	    iex> Giza.Query.connection(query)
	    {:giza_query, 'localhost', 9312, 0, 275,
 			"postsummary_fast_index postsummary_slow_index", 0, 25, 0, 0, 1000, 0, 0, "",
 			"", 0, "@group desc", "test", [], 0, [], [], 0}

	"""
	def connection(query) do
    	:giza_query.host(query, Application.get_env(:giza_sphinxsearch, :host))
    		|> :giza_query.port(Application.get_env(:giza_sphinxsearch, :port))
    end
end