defmodule Giza.SphinxQL do
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

		iex> Giza.SphinxQL.new() |> Giza.SphinxQL.raw("SELECT id, WEIGHT() as w FROM posts_index WHERE MATCH('subetei the swift')")
	"""
	def raw(%SphinxqlQuery{} = query, raw_query_string) when is_binary(raw_query_string) do
		query_new = %{query | :raw => raw_query_string}
		query_new
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
		query_new = %{query | :select => Enum.map(fields, fn(x) -> String.trim(x) end)}
		query_new
	end

	@doc """
	Shortcut helper function to form a suggestion query. Options can be passed to change the default limit and
	max edits (amount of levenstein distance acceptable, so 4 would mean 4 characters can be wrong)

	## Examples

		iex> Giza.SphinxQL.new() |> Giza.SphinxQL.suggest("sbetei", "posts_index", [limit: 3, max_edits: 4])
	"""
	def suggest(%SphinxqlQuery{} = query, index, phrase, opts \\ []) when is_binary(index) do
		limit = cond do 
			Keyword.has_key?(opts, :limit) ->
				Keyword.get(opts, :limit)
			true ->
				@default_suggest_limit
		end

		max_edits = cond do
			Keyword.has_key?(opts, :max_edits) ->
				Keyword.get(opts, :max_edits)
			true ->
				@default_suggest_max_edits
		end

		query_new = call(query, "QSUGGEST('" <> phrase <> "','" <> index <> "', " <> Integer.to_string(limit) 
			<> " as limit, " <> Integer.to_string(max_edits) <> " as max_edits)")
		query_new
	end

	@doc """
	Return a SphinxQL query augmented with a CALL statement. A string is acceptable input.

	## Examples

		iex> Giza.SphinxQL.new() |> Giza.SphinxQL.call("QSUGGEST('subtei', 'posts_index')") |> Giza.SphinxQL.send()
	"""
	def call(%SphinxqlQuery{} = query, call) when is_binary(call) do
		query_new = %{query | :call => call}
		query_new
	end

	@doc """
	Returns a SphinxQL query augmented with an index to select from.

	## Examples

		iex> Giza.SphinxQL.new() |> Giza.SphinxQL.from("posts")
	"""
	def from(%SphinxqlQuery{} = query, index) when is_binary(index) do
		query_new = %{query | :from => index}
		query_new
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
		query_new = %{query | :limit => limit}
		query_new
	end 

	@doc """
	Returns a SphinxQL query augmented with a limit for amount of returned documents.  Only an integer is acceptable input. This
	is normally used to support pagination.

	## Examples

		iex> Giza.SphinxQL.new() |> Giza.SphinxQL.offset(10)
	"""
	def offset(%SphinxqlQuery{} = query, offset) when is_integer(offset) do
		query_new = %{query | :offset => offset}
		query_new
	end

	@doc """
	Returns a SphinxQL query with an option added such as used for the expression ranker

	## Examples

		iex> SphinxQL.new()
		|> SphinxQL.option("ranker=expr('sum(lcs*user_weight)*1000+bm25'))")
	"""
	def option(%SphinxqlQuery{} = query, option) do
		%{query | :option => option}
	end

	@doc """
	Return meta information about the latest query on the current client.  This is commonly used to retrieve the total returned
	in that query and the total available without limit.  This information can be used for pagination

	http://sphinxsearch.com/docs/devel.html#sphinxql-show-meta

	## Examples

		iex> Giza.SphinxQL.meta()

			{:ok, %SphinxqlMeta{"total": 20, "total_found": 1000, "time": 0.0006, ...}
	"""
	def meta() do
		{:ok, sphinxql_result} = %SphinxqlQuery{}
			|> raw("SHOW META;")
			|> send()

		{:ok, meta_matches_to_map(sphinxql_result.matches, %{})}
	end

	@doc """
	Send a query to be executed after preprocessing of the SphinxqlQuery structure. Returns a tuple with :ok or :error and the error
	message if applicable.

	## Examples

		iex> Giza.SphinxQL.new() |> Giza.SphinxQL.raw("SELECT id FROM test_index WHERE MATCH('great kahn')") |> Giza.SphinxQL.send()
	"""
	def send(%SphinxqlQuery{} = query) do
		query_string = case query do
			%{raw: nil} ->
				query_to_string(query)
			%{raw: raw_query} ->
				raw_query
		end

		case Mariaex.query(:mysql_sphinx_client, query_string, [], [query_type: :text]) do
			{:ok, %{columns: columns, rows: rows, num_rows: num_rows}} ->
				{:ok, %SphinxqlResponse{matches: rows, fields: columns, total: num_rows}}
			{:error, %{mariadb: %{message: message}}} ->
        {:error, message}
		end
	end

	defp meta_matches_to_map([], %{} = map_acc) do
		map_acc
	end

	defp meta_matches_to_map([[match_key, match_value]|tail], %{} = map_acc) do
		meta_matches_to_map(tail, Map.put(map_acc, String.to_atom(match_key), match_value))
	end

	defp query_to_string(query) do
		case query_to_string_call(query) do
			nil ->
				query_part_list = [
					query_to_string_select(query),
					query_to_string_call(query),
					query_to_string_from(query),
					query_to_string_where(query),
					query_to_string_limit(query),
					query_to_string_option(query)
				]

				query_list_to_string(query_part_list, nil)
			query_string ->
				# Call overrides all other query parts
				query_string
		end
		
	end

	defp query_to_string_select(%SphinxqlQuery{select: nil}) do
		nil
	end

	defp query_to_string_select(%SphinxqlQuery{select: select}) do
		"SELECT " <> Enum.join(select, ",")
	end

	defp query_to_string_from(%SphinxqlQuery{from: nil}) do
		nil
	end

	defp query_to_string_from(%SphinxqlQuery{from: from}) do
		"FROM " <> from
	end

	defp query_to_string_where(%SphinxqlQuery{where: nil}) do
		nil
	end

	defp query_to_string_where(%SphinxqlQuery{where: where}) do
		"WHERE " <> where
	end

	defp query_to_string_limit(%SphinxqlQuery{limit: nil, offset: nil}) do
		nil
	end

	defp query_to_string_limit(%SphinxqlQuery{limit: limit, offset: offset}) do
		"LIMIT " <> Integer.to_string(offset) <> "," <> Integer.to_string(limit)
	end

	defp query_to_string_option(%SphinxqlQuery{option: nil}) do
		nil
	end

	defp query_to_string_option(%SphinxqlQuery{option: option}) do
		"OPTION " <> option
	end

	defp query_to_string_call(%SphinxqlQuery{call: nil}) do
		nil
	end

	defp query_to_string_call(%SphinxqlQuery{call: call}) do
		"CALL " <> call
	end

	defp query_list_to_string([query_part|tail], acc) do
		if acc do
			if query_part do
				query_list_to_string(tail, acc <> " " <> query_part)
			else
				query_list_to_string(tail, acc)
			end
		else
			query_list_to_string(tail, query_part)
		end
	end

	defp query_list_to_string([], acc) do
		acc
	end
end