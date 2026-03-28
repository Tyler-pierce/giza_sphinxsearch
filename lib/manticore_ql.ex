defmodule Giza.ManticoreQL do
  @moduledoc """
  Query building helper functions for ManticoreQL. Manticore Search is a fork of Sphinx Search
  with active development and new features. This module delegates the standard query-composing
  interface to `ManticoreQL` and is the place to add Manticore-specific extensions.
  """
  alias Giza.Structs.{SphinxqlQuery, SphinxqlResponse}
  alias Giza.SphinxQL

  # ---- Sphinx and Manticore Compatible ----

  defdelegate new(), to: SphinxQL
  defdelegate raw(query, raw_query_string), to: SphinxQL
  defdelegate select(query, fields), to: SphinxQL
  defdelegate from(query, index), to: SphinxQL
  defdelegate match(query, search_term), to: SphinxQL
  defdelegate where(query, where), to: SphinxQL
  defdelegate limit(query, limit), to: SphinxQL
  defdelegate offset(query, offset), to: SphinxQL
  defdelegate option(query, option), to: SphinxQL
  defdelegate order_by(query, order_by), to: SphinxQL
  defdelegate call(query, call), to: SphinxQL
  defdelegate suggest(query, index, phrase), to: SphinxQL
  defdelegate suggest(query, index, phrase, opts), to: SphinxQL
  defdelegate meta(), to: SphinxQL

  # ---- Manticore ----

  @doc """
  Appends a FACET clause to the query. Multiple calls chain additional facets. Manticore
  reuses the base result set for each facet, so the total cost is only marginally more than
  the plain query.

  Options:
    - `:order` - ORDER BY expression string, e.g. `"COUNT(*) DESC"`
    - `:limit` - integer cap on facet rows returned

  ## Examples

      iex> ManticoreQL.new()
      |> ManticoreQL.from("products")
      |> ManticoreQL.match("phone")
      |> ManticoreQL.facet("brand_id")
      |> ManticoreQL.facet("price", order: "COUNT(*) DESC", limit: 10)
      |> ManticoreQL.send()
  """
  def facet(%SphinxqlQuery{} = query, expr) when is_binary(expr) do
    facet(query, expr, [])
  end

  def facet(%SphinxqlQuery{} = query, expr, opts) when is_binary(expr) and is_list(opts) do
    %{query | facets: query.facets ++ [build_facet_string(expr, opts)]}
  end

  @doc """
  Adds `HIGHLIGHT()` to the SELECT list so Manticore annotates matching keywords in stored
  fields. Requires the table to have `stored_fields` configured.

  Options are passed as keyword pairs and become `key='value'` inside `HIGHLIGHT({...})`.
  Common options: `before_match`, `after_match`, `around`, `limit`, `limit_passages`.

  ## Examples

      iex> ManticoreQL.new()
      |> ManticoreQL.from("articles")
      |> ManticoreQL.match("elixir")
      |> ManticoreQL.highlight()
      |> ManticoreQL.send()

      iex> ManticoreQL.new()
      |> ManticoreQL.from("articles")
      |> ManticoreQL.match("elixir")
      |> ManticoreQL.highlight(before_match: "<em>", after_match: "</em>", limit: 200)
      |> ManticoreQL.send()
  """
  def highlight(%SphinxqlQuery{} = query), do: highlight(query, [])

  def highlight(%SphinxqlQuery{} = query, opts) when is_list(opts) do
    %{query | select: query.select ++ [build_highlight_expr(opts)]}
  end

  @doc """
  Sets a KNN (k-nearest-neighbour) vector search clause in WHERE. Requires the table to
  have a `float_vector` attribute with an HNSW index.

  Typically combine with `select/2` to also retrieve `knn_dist()` in results.

  ## Examples

      iex> ManticoreQL.new()
      |> ManticoreQL.select(["id", "title", "knn_dist()"])
      |> ManticoreQL.from("articles")
      |> ManticoreQL.knn("embedding", 5, [0.1, 0.2, 0.3, 0.4])
      |> Giza.send()
  """
  def knn(%SphinxqlQuery{} = query, field, k, vector)
      when is_binary(field) and is_integer(k) and is_list(vector) do
    vector_str = Enum.map_join(vector, ", ", &to_string/1)
    %{query | where: "KNN(#{field}, #{k}, (#{vector_str}))"}
  end

  @doc """
  Executes a percolate (reverse search) query — matches stored queries in a percolate table
  against one or more incoming documents.

  `doc` is a JSON string. `docs` is a list of JSON strings that will be wrapped in a JSON
  array.

  ## Examples

      iex> ManticoreQL.percolate("pq_alerts", ~s({"title": "breaking news"}))
      {:ok, %SphinxqlResponse{}}

      iex> ManticoreQL.percolate("pq_alerts", [~s({"title": "foo"}), ~s({"title": "bar"})])
      {:ok, %SphinxqlResponse{}}
  """
  def percolate(table, doc) when is_binary(table) and is_binary(doc) do
    run_query("CALL PQ('#{table}', '#{doc}')")
  end

  def percolate(table, docs) when is_binary(table) and is_list(docs) do
    docs_json = "[" <> Enum.join(docs, ", ") <> "]"
    run_query("CALL PQ('#{table}', '#{docs_json}')")
  end

  @doc """
  Word-level autocomplete via `CALL SUGGEST`. Returns candidate completions for the given
  partial word against the specified index dictionary.

  Options:
    - `:limit` - max suggestions (default: 5)
    - `:max_edits` - Levenshtein distance tolerance (default: 4)

  ## Examples

      iex> ManticoreQL.autocomplete("elxi", "posts_index")
      {:ok, %SphinxqlResponse{}}

      iex> ManticoreQL.autocomplete("elxi", "posts_index", limit: 3, max_edits: 2)
      {:ok, %SphinxqlResponse{}}
  """
  def autocomplete(word, index) when is_binary(word) and is_binary(index) do
    autocomplete(word, index, [])
  end

  def autocomplete(word, index, opts) when is_binary(word) and is_binary(index) and is_list(opts) do
    opts_str = Enum.map_join(opts, "", fn {k, v} -> ", #{v} as #{k}" end)
    run_query("CALL SUGGEST('#{word}', '#{index}'#{opts_str})")
  end

  # PRIVATE FUNCTIONS
  ###################
  defp run_query(query_string) do
    alias Giza.Structs.SphinxqlResponse
    adapter = Application.get_env(:giza_sphinxsearch, :query_adapter, Giza.QueryAdapter.MyXQL)

    case adapter.execute(query_string) do
      {:ok, %{columns: columns, rows: rows, num_rows: num_rows}} ->
        {:ok, %SphinxqlResponse{matches: rows, fields: columns, total: num_rows}}

      {:error, %{mariadb: %{message: message}}} ->
        {:error, message}

      {:error, %{message: message}} ->
        {:error, message}
    end
  end

  defp build_facet_string(expr, opts) do
    order = Keyword.get(opts, :order)
    limit = Keyword.get(opts, :limit)

    "FACET #{expr}"
    |> maybe_append(order && "ORDER BY #{order}")
    |> maybe_append(limit && "LIMIT #{limit}")
  end

  defp maybe_append(str, nil), do: str
  defp maybe_append(str, suffix), do: str <> " " <> suffix

  defp build_highlight_expr([]), do: "HIGHLIGHT()"
  defp build_highlight_expr(opts) do
    opts_str = Enum.map_join(opts, ", ", fn {k, v} -> "#{k}='#{v}'" end)
    "HIGHLIGHT({#{opts_str}})"
  end
end
