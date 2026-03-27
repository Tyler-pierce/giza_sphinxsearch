defmodule SphinxQL do
	@moduledoc """
	Query building helper functions for SphinxQL requests (http://sphinxsearch.com/docs/devel.html#sphinxql-reference). 
	This is the recommended way to query Sphinx (for client speed particularly) and will be the most supported style in 
	Giza going forward.  SphinxQL is very close to standard SQL with a few non-supported terms that wouldn't make
	sence in the search world and a few extras that only make sense in Sphinx's world. 100% of Sphinx' functionality is 
	accessable through this method.
	"""
	alias Giza.Structs.{SphinxqlQuery, SphinxqlResponse}

	@default_suggest_limit 5
	@default_suggest_max_edits 4

	@doc """
	Return a http api query structure with default values

	## Examples

		iex> Giza.SphinxQL.new() |> ...
	"""
	def new() do
		%SphinxqlQuery{}
	end

	@doc """
	Return a SphinxQL query with it's raw field set allowing to run a custom client created query. Raw overrides other options such
	as select, where, etc.  If you can't find functionality needed from the query helpers in this module, this is the best
	way to unlock the full feature set of sphinx.

	## Examples

		iex> SphinxQL.new()
		     |> Giza.SphinxQL.raw("SELECT id, WEIGHT() as w FROM posts_index WHERE MATCH('subetei the swift')")
	"""
	def raw(%SphinxqlQuery{} = query, raw_query_string) when is_binary(raw_query_string) do
		%{query | :raw => raw_query_string}
	end	

	@doc """
	Return a SphinxQL query augmented with a select statement. Either a string (binary) or list of fields is acceptable input.

	## Examples

		iex> Giza.SphinxQL.new() |> Giza.SphinxQL.select(["id", "WEIGHT() as w"])
	"""
	def select(%SphinxqlQuery{} = query, fields) when is_binary(fields) do
		select(query, String.split(fields, ","))
	end

	def select(%SphinxqlQuery{} = query, fields) when is_list(fields) do
		%{query | :select => Enum.map(fields, fn(x) -> String.trim(x) end)}
	end

	@doc """
	Shortcut helper function to form a suggestion query. Options can be passed to change the default limit and
	max edits (amount of levenstein distance acceptable, so 4 would mean 4 characters can be wrong)

	## Examples

		iex> SphinxQL.new()
		     |> SphinxQL.suggest("sbetei", "posts_index", limit: 3, max_edits: 4)
	"""
	def suggest(%SphinxqlQuery{} = query, index, phrase, opts \\ []) when is_binary(index) do
		limit = Keyword.get(opts, :limit, @default_suggest_limit)

		max_edits = Keyword.get(opts, :max_edits, @default_suggest_max_edits)

		call(
			query,
			"QSUGGEST('" <> phrase <> "','" <> index <> "', " <> Integer.to_string(limit) 
			<> " as limit, " <> Integer.to_string(max_edits) <> " as max_edits)"
		)
	end

	@doc """
	Return a SphinxQL query augmented with a CALL statement. A string is acceptable input.

	## Examples

		iex> Giza.SphinxQL.new() |> Giza.SphinxQL.call("QSUGGEST('subtei', 'posts_index')") |> Giza.SphinxQL.send()
	"""
	def call(%SphinxqlQuery{} = query, call) when is_binary(call) do
		%{query | :call => call}
	end

	@doc """
	Returns a SphinxQL query augmented with an index to select from.

	## Examples

		iex> Giza.SphinxQL.new() |> Giza.SphinxQL.from("posts")
	"""
	def from(%SphinxqlQuery{} = query, index) when is_binary(index) do
		%{query | :from => index}
	end

	@doc """
	Returns a SphinxQL query augmented with a where clause which will be formated as a MATCH query, a common way
	of asking Sphinx for search matches on a word or phrase (word bag)

	## Examples

		iex> Giza.SphinxQL.new() |> Giza.SphinxQL.match("Subetei the Swift")
	"""
	def match(%SphinxqlQuery{} = query, search_phrase) when is_list(search_phrase) do
		match(query, Enum.join(Enum.map(search_phrase, fn(x) -> String.trim(x) end), " "))
	end	

	def match(%SphinxqlQuery{} = query, search_term) when is_binary(search_term) do
		%{query | :where => "MATCH('" <> String.trim(search_term) <> "')"}
	end

	@doc """
	Returns a SphinxQL query with a where clause added. A string representing the whole where part of your query
	is the only accepted input. Often used for filtering as =/IN/etc map directly to attribute filters.

	## Examples

		iex> Giza.SphinxQL.new() |> Giza.SphinxQL.where("MATCH('tengri') AND room = 'mongol lounge'")
	"""
	def where(%SphinxqlQuery{} = query, where) when is_binary(where) do
		%{query | :where => String.trim(where)}
	end

	@doc """
	Returns an api query augmented with a limit for amount of returned documents.  Note that Sphinx also allows for setting
	an internal limit in configuration.  Only an integer is acceptable input.

	## Examples

		iex> Giza.SphinxQL.new() |> Giza.SphinxQL.limit(1)
	"""
	def limit(%SphinxqlQuery{} = query, limit) when is_integer(limit) do
		%{query | :limit => limit}
	end 

	@doc """
	Returns a SphinxQL query augmented with a limit for amount of returned documents.  Only an integer is acceptable input. This
	is normally used to support pagination.

	## Examples

		iex> Giza.SphinxQL.new() |> Giza.SphinxQL.offset(10)
	"""
	def offset(%SphinxqlQuery{} = query, offset) when is_integer(offset) do
		%{query | :offset => offset}
	end

	@doc """
	Returns a SphinxQL query with an option added such as used for the expression ranker

	## Examples

		iex> SphinxQL.new()
		|> SphinxQL.option("ranker=expr('sum(lcs*user_weight)*1000+bm25'))")
		|> SphinxQL.send()

		%SphinxqlResponse{ .. }
	"""
	def option(%SphinxqlQuery{} = query, option) do
		%{query | :option => option}
	end

	@doc """
	Add an order by clause to return sorted by results.  Sphinx accepts a max of 5 order by attributes and
	it's builtins are:
		@id (match ID)
		@weight (match weight)
		@rank (match weight)
		@relevance (match weight)
		@random (return results in random order)

	## Examples

			iex> SphinxQL.new()
			|> SphinxQL.order_by("@relevance DESC, updated_at DESC")
			|> SphinxQL.send()

			%SphinxqlResponse{ .. }
	"""
	def order_by(%SphinxqlQuery{} = query, order_by) do
		%{query | :order_by => order_by}
	end

	@doc """
	Return meta information about the latest query on the current client.  This is commonly used to retrieve the total returned
	in that query and the total available without limit.  This information can be used for pagination

	http://sphinxsearch.com/docs/devel.html#sphinxql-show-meta

	## Examples

		iex> Giza.SphinxQL.meta()

			{:ok, %SphinxqlMeta{"total": 20, "total_found": 1000, "time": 0.0006, ...}
	"""
	def meta do
		{:ok, sphinxql_result} =
			%SphinxqlQuery{}
			|> raw("SHOW META;")
			|> send()

		{:ok, meta_matches_to_map(sphinxql_result.matches, %{})}
	end

	# PRIVATE FUNCTIONS
	###################
	defp meta_matches_to_map([], %{} = map_acc) do
		map_acc
	end

	defp meta_matches_to_map([[match_key, match_value]|tail], %{} = map_acc) do
		meta_matches_to_map(tail, Map.put(map_acc, String.to_atom(match_key), match_value))
	end
end
