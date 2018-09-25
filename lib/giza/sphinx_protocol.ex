defmodule Giza.SphinxProtocol do
	@moduledoc """
	Send query to Sphinx Daemon and return results syncronously using sphinx native protocol. Module could be removed/refactored soon.
	"""

  @doc """
  Send a request to the configured sphinx daemon.  The results will be parsed as a map for easy pattern matching on whatever parts of the
  result of interest.  Words returns a tuple with the search phrase, the amount of documents found containing a hit, and the amount of total
  hits (well enough weighted match to return a result).

 		## Examples

    iex> Giza.send(query)
    {:ok,
      %{attrs: [{"title", 7}, {"body", 7}],
        fields: ["title", "body", "tags"],
        matches: [{171,
          [doc_id: 171, weight: 2,
           attrs: [{"title", 7}, {"body", 7}]]}],
        {190,
        ..
        }],
        status: 0, 
        time: 0.008, 
        total: 19, 
        total_found: 19, 
        warnings: [],
        words: [{"test", 19, 23}]
      }
    }
  """
  def send(query) do
    case send_erlang_giza(query) do
      {:ok, result} ->
        {:ok, Giza.result_tuple_to_map(result)}
      {:error, error} ->
        {:error, error}
    end
  end

  def send!(query) do
    case send_erlang_giza(query) do
      {:ok, result} ->
        Giza.result_tuple_to_map(result)
      {:error, error} ->
        error
    end
  end

	@doc """
	Build a new default query against the passed index and phrase

		## Examples

    iex> Giza.SphinxProtocol.new('postsummary_fast_index postsummary_slow_index', 'baggy')
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
				""
		end

		:giza_query.new(index, search)
	end

  @doc """
  Create a query based on the supplied index(es) and search phrase.  This is the easiest way to start building a query to Sphinx and
  supports piping to all Giza.Query's interface. Returns a tuple suitable for sending to Giza's erlang parser for speaking the sphinx
  native format.

  	## Examples

    iex> Giza.query('postsummary_fast_index postsummary_slow_index', 'baggy')
    {:giza_query, 'localhost', 9312, 0, 275,
    "postsummary_fast_index postsummary_slow_index", 0, 25, 0, 0, 1000, 0, 0, "",
    "", 0, "@group desc", "test", [], 0, [], [], 0}
  """
  def query(index, search_phrase) do
    new(index, search_phrase)
    |> connection()
  end

	@doc """
	Return a new query with the configured host and port

		## Examples

    iex> Giza.SphinxProtocol.connection(query)
    {:giza_query, 'localhost', 9312, 0, 275,
			"postsummary_fast_index postsummary_slow_index", 0, 25, 0, 0, 1000, 0, 0, "",
			"", 0, "@group desc", "test", [], 0, [], [], 0}
	"""
	def connection(query) do
  	:giza_query.host(query, Application.get_env(:giza_sphinxsearch, :host))
  	|> :giza_query.port(Application.get_env(:giza_sphinxsearch, :port))
  end

  def connection(query, host, port) do
  	:giza_query.host(query, host)
  	|> :giza_query.port(port)
  end

  @doc """
  Return a query structure with the phrase string set. This is a wrapper to support all of giza_query.erl, so not
  recommended to use directly

  	## Examples

  	iex> Giza.SphinxProtocol.query_phrase(query, 'searchforme')
  	{:giza_query, 'localhost', 9312, 0, 275,
			"postsummary_fast_index postsummary_slow_index", 0, 25, 0, 0, 1000, 0, 0, "",
			"", 0, "@group desc", "searchforme", [], 0, [], [], 0}
  """
  def query_phrase(query, query_phrase) do
  	:giza_query.query_string(query, query_phrase)
  end

  @doc """
  Retrun a query structure with a limit added. A sphinx limited query will return the amount of total matches but will
  limit the returned documents.  This along with offset is commonly used for pagination

  	## Examples

  	iex> Giza.SphinxProtocol.limit(query, 10)
  	{:giza_query, 'localhost', 9312, 0, 275,
			"postsummary_fast_index postsummary_slow_index", 0, 10, 0, 0, 1000, 0, 0, "",
			"", 0, "@group desc", "searchforme", [], 0, [], [], 0}
  """
  def limit(query, limit) do
  	:giza_query.limit(query, limit)
  end

  @doc """
  Return a query structure with a limit added. A sphinx limited query will return the amount of total matches but will
  limit the returned documents.  This along with offset is commonly used for pagination

  	## Examples

  	iex> Giza.SphinxProtocol.limit(query, 10)
  	{:giza_query, 'localhost', 9312, 0, 275,
			"postsummary_fast_index postsummary_slow_index", 10, 25, 0, 0, 1000, 0, 0, "",
			"", 0, "@group desc", "searchforme", [], 0, [], [], 0}
  """
  def offset(query, offset) do
  	:giza_query.offset(query, offset)
  end

	@doc """
	Return the maximum matches a query can return.  Unlike limit, rather than page the returned results, it limits them before results are
	tabulated and returned and affects your total results count returned.

	## Examples

			iex> Giza.SphinxProtocol.max_matches(query, 20)
			{:giza_query, 'localhost', 9312, 0, 275,
			"postsummary_fast_index postsummary_slow_index", 10, 25, 0, 0, 20, 0, 0, "",
 			"", 0, "@group desc", "searchforme", [], 0, [], [], 0}
	"""
  def max_matches(query, max) do
  	:giza_query.max_matches(query, max)
  end

  @doc """
  Automatically changes your sort mode to SPHINX_SORT_EXTENDED (default is SPHINX_SORT_RELEVANCE). Takes the given expression
  and uses that to rank results. http://sphinxsearch.com/docs/current.html#sort-extended.

  	## Examples

  	iex> Giza.SphinxProtocol.sort_extended(query, '@weight + (publicvotes + ln(userreputation)) * 0.1')
  	{:giza_query, 'localhost', 9312, 0, 275,
			"postsummary_fast_index postsummary_slow_index", 10, 25, 0, 0, 1000, 0, 4, "@weight + (publicvotes + ln(userreputation)) * 0.1",
			"", 0, "@group desc", "searchforme", [], 0, [], [], 0}
  """
  def sort_extended(query, expression) do
  	:giza_query.sort_extended(query, expression)
  end

	@doc """
	Use one of your sphinx attributes to filter results down to the values you pass.

	## Examples

			sphinx.conf:

			source some_index : sql
			{
			...
			sql_attr_uint = user_age
			...
			}

			iex> Giza.SphinxProtocol.filter_include(query, 'user_age', [50, 60, 70])
			{:giza_query, 'localhost', 9312, 0, 275,
			"postsummary_fast_index postsummary_slow_index", 10, 25, 0, 0, 1000, 0, 4, "",
			"", 0, "@group desc", "searchforme", [{:value, 'user_age', false, [50,60,70]}], 0, [], [], 0}

			iex> Giza.SphinxProtocol.filter_include(query, 'user_age', 50, 60])
			{:giza_query, 'localhost', 9312, 0, 275,
			"postsummary_fast_index postsummary_slow_index", 10, 25, 0, 0, 1000, 0, 4, "",
			"", 0, "@group desc", "searchforme", [{:range, 'user_age', false, {50,60}}], 0, [], [], 0}

	"""
  def filter_include(query, name, values) do
  	:giza_query.add_filter(query, name, false, values)
  end

  def filter_include(query, name, min, max) do
  	:giza_query.add_filter_range(query, name, min, max)
  end

	@doc """
	Use one of your sphinx attributes to filter results to exclude the values you pass.

	## Examples

			sphinx.conf:

			source some_index : sql
			{
			...
			sql_attr_uint = user_age
			...
			}

			iex> Giza.SphinxProtocol.filter_exclude(query, 'user_age', [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
			{:giza_query, 'localhost', 9312, 0, 275,
			"postsummary_fast_index postsummary_slow_index", 10, 25, 0, 0, 1000, 0, 4, "",
			"", 0, "@group desc", "searchforme", [{:value, 'user_age', true, [1,2,3,4,5,6,7,8,9,10]}], 0, [], [], 0}

			iex> Giza.SphinxProtocol.filter_exclude(query, 'user_age', 1, 10)
			{:giza_query, 'localhost', 9312, 0, 275,
			"postsummary_fast_index postsummary_slow_index", 10, 25, 0, 0, 1000, 0, 4, "",
			"", 0, "@group desc", "searchforme", [{:range, 'user_age', true, {1,10}}], 0, [], [], 0}

	"""
  def filter_exclude(query, name, values) do
  	:giza_query.add_filter(query, name, true, values)
  end

  def filter_exclude(query, name, min, max) do
  	:giza_query.add_filter_range(query, name, true, min, max)
  end
    
	@doc """
	Utilize geo ability in a sphinx query.

	## Examples

			iex> Giza.SphinxProtocol.geo(query, 0.659298124, -2.136602399)
			{:giza_query, 'localhost', 9312, 0, 275,
			"postsummary_fast_index postsummary_slow_index", 10, 25, 0, 0, 1000, 0, 4, "",
			"", 0, "@group desc", "genghis khan", [], {:deg, 0.659298124, -2.136602399}, [], [], 0}		
	"""
  def geo(query, lat, long) do
  	:giza_query.geo(query, lat, long)
  end

	@doc """
	Assign additional weight to be added to each of your index on the passed query.  If you have results from index_a and 
	index_b with weight results 2 and 3 and use the below example call, your document weight will be 2 * 30 + 3 * 80 = 300.  
	Without weights sphinx would simple choose the latter index if the document is found in both indexes (3).  This can be useful 
	depending on how your data is partitioned or doing more complex searches from multiple sources.

	## Examples

			iex> Giza.SphinxProtocol.geo(query, [postsummary_fast_index: 30, postsummary_slow_index: 80])
			{:giza_query, 'localhost', 9312, 0, 275,
			"postsummary_fast_index postsummary_slow_index", 10, 25, 0, 0, 1000, 0, 4, "",
			"", 0, "@group desc", "searchforme", [], 0, [postsummary_fast_index: 30, postsummary_slow_index: 80], [], 0}
	"""
  def index_weights(query, weights) do
  	:giza_query.index_weights(query, weights)
  end

	@doc """
	Assign weights on a per field basis. Should be a list of fields from the query source of the indexes of your query. This will
	affect the weight of your query and can tilt phrase matching in favor of results from favored sources. The example below weighs
	results from the title as 50% more valued than results from the body text.  Keep in mind any fields not listed keep their default
	of 1.

	## Examples

			iex> Giza.SphinxProtocol.field_weights(query, [title: 3, body: 2])
			{:giza_query, 'localhost', 9312, 0, 275,
			"postsummary_fast_index postsummary_slow_index", 10, 25, 0, 0, 1000, 0, 4, "",
			"", 0, "@group desc", "searchforme", [], 0, [], [title: 3, body: 2], 0}
	"""
  def field_weights(query, field_weights) do
  	:giza_query.field_weights(query, field_weights)
  end

	@doc """
	Allows clustering of results. Details on how this can be helpful (and it can!) are contained in the sphinx documentation:
	http://sphinxsearch.com/docs/current.html#clustering
	Clustering results are compatible with AVG, SUMS and such function calls you may be used to from SQL. Use SetSelect in conjunction
	with Group (not yet supported in this client). Default value is @group desc (simply return results in order of descending weight)
	"""
  def group_by(query, group_by) do
  	:giza_query.group_by(query, group_by)
  end

	defp send_erlang_giza(query) do
		:giza_request.send(query)
	end
end