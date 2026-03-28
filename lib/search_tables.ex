defmodule Giza.SearchTables do
  @moduledoc """
  Table management functions for Manticore Search. Covers DDL (table lifecycle),
  DML (writing to RT tables), clustered DML (replication-aware writes),
  replication cluster management, and maintenance operations.

  ## Table Create Options
  @see https://manual.manticoresearch.com/Introduction
  @see https://manual.manticoresearch.com/Searching/Sorting_and_ranking#Ranking-overview
  @see https://manual.manticoresearch.com/Searching/Spell_correction#Fuzzy-Search
  """

  alias Giza.Structs.SphinxqlResponse

  @default_min_infix_len 2

  # ==========================================================================
  # DDL — table lifecycle
  # ==========================================================================

  @doc """
  Create a real-time table with the given schema definition.

  `schema` may be a raw SQL string or a list of `{name, type}` tuples.

  ## Examples

      iex> SearchTables.create_table("products", "title text, price uint")
      {:ok, %SphinxqlResponse{}}

      iex> SearchTables.create_table("products", [{"title", "text"}, {"price", "uint"}])
      {:ok, %SphinxqlResponse{}}

      iex> SearchTables.create_table("products", "title text", "morphology='stem_en'")
      {:ok, %SphinxqlResponse{}}
  """
  def create_table(name, schema) when is_binary(name) do
    run_query("CREATE TABLE #{name} (#{build_schema(schema)})")
  end

  def create_table(name, schema, opts) when is_binary(name) do
    run_query("CREATE TABLE #{name} (#{build_schema(schema)}) #{build_table_opts(opts)}")
  end

  @doc """
  Clone a table's schema.

  ## Examples

      iex> SearchTables.create_table_like("products_copy", "products")
      {:ok, %SphinxqlResponse{}}
  """
  def create_table_like(name, existing) when is_binary(name) and is_binary(existing) do
    run_query("CREATE TABLE #{name} LIKE #{existing}")
  end

  @doc """
  Idempotent table creation — uses `IF NOT EXISTS`.

  Accepts the same arguments as `create_table/2,3`.

  ## Examples

      iex> SearchTables.create_table_if_not_exists("products", "title text, price uint")
      {:ok, %SphinxqlResponse{}}
  """
  def create_table_if_not_exists(name, schema) when is_binary(name) do
    run_query("CREATE TABLE IF NOT EXISTS #{name} (#{build_schema(schema)})")
  end

  def create_table_if_not_exists(name, schema, opts) when is_binary(name) do
    run_query("CREATE TABLE IF NOT EXISTS #{name} (#{build_schema(schema)}) #{build_table_opts(opts)}")
  end

  @doc """
  Create a distributed table that fans queries out to local shards and/or remote agents.

  `parts` is a keyword list whose keys are `:local` or `:agent`:

      [local: "shard1", local: "shard2", agent: "host:port:remote"]

  ## Examples

      iex> SearchTables.create_distributed_table("dist_products",
      ...>   [local: "shard1", local: "shard2", agent: "10.0.0.2:9312:remote_shard"])
      {:ok, %SphinxqlResponse{}}
  """
  def create_distributed_table(name, parts) when is_binary(name) and is_list(parts) do
    create_distributed_table(name, parts, [])
  end

  def create_distributed_table(name, parts, opts) when is_binary(name) and is_list(parts) do
    parts_sql = Enum.map_join(parts, " ", fn
      {:local, v} -> "local='#{v}'"
      {:agent, v} -> "agent='#{v}'"
    end)

    opts_sql = if opts == [], do: "", else: " " <> build_table_opts(opts)
    run_query("CREATE TABLE #{name} type='distributed' #{parts_sql}#{opts_sql}")
  end

  @doc """
  Drop a table. Pass `if_exists: true` to suppress errors when the table doesn't exist.

  ## Examples

      iex> SearchTables.drop_table("products")
      {:ok, %SphinxqlResponse{}}

      iex> SearchTables.drop_table("products", if_exists: true)
      {:ok, %SphinxqlResponse{}}
  """
  def drop_table(name) when is_binary(name) do
    run_query("DROP TABLE #{name}")
  end

  def drop_table(name, opts) when is_binary(name) and is_list(opts) do
    if_exists = if Keyword.get(opts, :if_exists, false), do: "IF EXISTS ", else: ""
    run_query("DROP TABLE #{if_exists}#{name}")
  end

  @doc """
  Wipe all data from a table while preserving its schema.

  ## Examples

      iex> SearchTables.truncate_table("products")
      {:ok, %SphinxqlResponse{}}
  """
  def truncate_table(name) when is_binary(name) do
    run_query("TRUNCATE TABLE #{name}")
  end

  @doc """
  Return the schema of a table.

  ## Examples

      iex> SearchTables.describe_table("products")
      {:ok, %SphinxqlResponse{fields: ["Field", "Type", "Properties"], matches: [...]}}
  """
  def describe_table(name) when is_binary(name) do
    run_query("DESCRIBE #{name}")
  end

  @doc """
  Return the DDL statement that would recreate the table.

  ## Examples

      iex> SearchTables.show_create_table("products")
      {:ok, %SphinxqlResponse{}}
  """
  def show_create_table(name) when is_binary(name) do
    run_query("SHOW CREATE TABLE #{name}")
  end

  # ==========================================================================
  # DML — writing to RT tables
  # ==========================================================================

  @doc """
  Insert a row into a table.

  `columns` is a list of column name strings. `values` is a list of corresponding
  values — strings are automatically single-quoted, numbers are left bare.

  ## Examples

      iex> SearchTables.insert("products", ["id", "title", "price"], [1, "Laptop", 999])
      {:ok, %SphinxqlResponse{}}
  """
  def insert(table, columns, values)
      when is_binary(table) and is_list(columns) and is_list(values) do
    run_query("INSERT INTO #{table} (#{Enum.join(columns, ", ")}) VALUES (#{build_values(values)})")
  end

  @doc """
  Full upsert by document id — replaces the entire row if it exists.

  ## Examples

      iex> SearchTables.replace("products", ["id", "title", "price"], [1, "Updated Laptop", 899])
      {:ok, %SphinxqlResponse{}}
  """
  def replace(table, columns, values)
      when is_binary(table) and is_list(columns) and is_list(values) do
    run_query("REPLACE INTO #{table} (#{Enum.join(columns, ", ")}) VALUES (#{build_values(values)})")
  end

  @doc """
  Partial attribute update. Only attributes (not full-text fields) can be updated.

  `attrs` is a keyword list or map of `{attribute, value}` pairs.

  ## Examples

      iex> SearchTables.update("products", [price: 799], "id = 1")
      {:ok, %SphinxqlResponse{}}

      iex> SearchTables.update("products", %{"price" => 799}, "id = 1")
      {:ok, %SphinxqlResponse{}}
  """
  def update(table, attrs, where_clause)
      when is_binary(table) and is_binary(where_clause) do
    run_query("UPDATE #{table} SET #{build_set_clause(attrs)} WHERE #{where_clause}")
  end

  @doc """
  Delete documents matching a condition.

  ## Examples

      iex> SearchTables.delete("products", "id = 1")
      {:ok, %SphinxqlResponse{}}
  """
  def delete(table, where_clause) when is_binary(table) and is_binary(where_clause) do
    run_query("DELETE FROM #{table} WHERE #{where_clause}")
  end

  # ==========================================================================
  # Clustered DML — writes targeting a replication cluster
  #
  # When a table lives inside a replication cluster, all writes MUST use
  # cluster:table notation or Manticore will reject them.
  # ==========================================================================

  @doc """
  Insert into a replicated table using `cluster:table` notation.

  ## Examples

      iex> SearchTables.cluster_insert("my_cluster", "products", ["id", "title"], [1, "Laptop"])
      {:ok, %SphinxqlResponse{}}
  """
  def cluster_insert(cluster, table, columns, values)
      when is_binary(cluster) and is_binary(table) and is_list(columns) and is_list(values) do
    run_query("INSERT INTO #{cluster}:#{table} (#{Enum.join(columns, ", ")}) VALUES (#{build_values(values)})")
  end

  @doc """
  Full upsert into a replicated table using `cluster:table` notation.

  ## Examples

      iex> SearchTables.cluster_replace("my_cluster", "products", ["id", "title"], [1, "Laptop"])
      {:ok, %SphinxqlResponse{}}
  """
  def cluster_replace(cluster, table, columns, values)
      when is_binary(cluster) and is_binary(table) and is_list(columns) and is_list(values) do
    run_query("REPLACE INTO #{cluster}:#{table} (#{Enum.join(columns, ", ")}) VALUES (#{build_values(values)})")
  end

  @doc """
  Delete from a replicated table using `cluster:table` notation.

  ## Examples

      iex> SearchTables.cluster_delete("my_cluster", "products", "id = 1")
      {:ok, %SphinxqlResponse{}}
  """
  def cluster_delete(cluster, table, where_clause)
      when is_binary(cluster) and is_binary(table) and is_binary(where_clause) do
    run_query("DELETE FROM #{cluster}:#{table} WHERE #{where_clause}")
  end

  # ==========================================================================
  # Replication cluster management
  # ==========================================================================

  @doc """
  Create a replication cluster.

  ## Examples

      iex> SearchTables.create_cluster("my_cluster")
      {:ok, %SphinxqlResponse{}}

      iex> SearchTables.create_cluster("my_cluster", "/var/data/cluster")
      {:ok, %SphinxqlResponse{}}
  """
  def create_cluster(name) when is_binary(name) do
    run_query("CREATE CLUSTER #{name}")
  end

  def create_cluster(name, path) when is_binary(name) and is_binary(path) do
    run_query("CREATE CLUSTER #{name} '#{path}' AS path")
  end

  @doc """
  Join an existing replication cluster at the given host.

  ## Examples

      iex> SearchTables.join_cluster("my_cluster", "10.0.0.1:9312")
      {:ok, %SphinxqlResponse{}}

      iex> SearchTables.join_cluster("my_cluster", "10.0.0.1:9312", "/var/data/cluster")
      {:ok, %SphinxqlResponse{}}
  """
  def join_cluster(name, host) when is_binary(name) and is_binary(host) do
    run_query("JOIN CLUSTER #{name} AT '#{host}'")
  end

  def join_cluster(name, host, path)
      when is_binary(name) and is_binary(host) and is_binary(path) do
    run_query("JOIN CLUSTER #{name} AT '#{host}' '#{path}' AS path")
  end

  @doc """
  Add a table to a replication cluster.

  ## Examples

      iex> SearchTables.cluster_add_table("my_cluster", "products")
      {:ok, %SphinxqlResponse{}}
  """
  def cluster_add_table(cluster, table) when is_binary(cluster) and is_binary(table) do
    run_query("ALTER CLUSTER #{cluster} ADD #{table}")
  end

  @doc """
  Remove a table from a replication cluster. The table survives as a local
  non-replicated table.

  ## Examples

      iex> SearchTables.cluster_drop_table("my_cluster", "products")
      {:ok, %SphinxqlResponse{}}
  """
  def cluster_drop_table(cluster, table) when is_binary(cluster) and is_binary(table) do
    run_query("ALTER CLUSTER #{cluster} DROP #{table}")
  end

  @doc """
  Delete a replication cluster. Tables survive as local non-replicated tables.

  ## Examples

      iex> SearchTables.delete_cluster("my_cluster")
      {:ok, %SphinxqlResponse{}}
  """
  def delete_cluster(name) when is_binary(name) do
    run_query("DELETE CLUSTER #{name}")
  end

  # ==========================================================================
  # Maintenance — keeping RT tables healthy
  # ==========================================================================

  @doc """
  Force the RAM chunk to a new disk chunk. Important before planned shutdowns.

  ## Examples

      iex> SearchTables.flush_table("products")
      {:ok, %SphinxqlResponse{}}
  """
  def flush_table(name) when is_binary(name) do
    run_query("FLUSH RAMCHUNK #{name}")
  end

  @doc """
  Merge disk chunks. Run periodically to avoid read amplification.

  ## Examples

      iex> SearchTables.optimize_table("products")
      {:ok, %SphinxqlResponse{}}
  """
  def optimize_table(name) when is_binary(name) do
    run_query("OPTIMIZE TABLE #{name}")
  end

  @doc """
  Show table status — document count, disk size, chunk count, etc.
  Useful for deciding when to run `optimize_table/1`.

  ## Examples

      iex> SearchTables.show_table_status("products")
      {:ok, %SphinxqlResponse{}}
  """
  def show_table_status(name) when is_binary(name) do
    run_query("SHOW TABLE #{name} STATUS")
  end

  # PRIVATE FUNCTIONS
  ###################
  defp run_query(query_string) do
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

  defp build_schema(schema) when is_binary(schema), do: schema

  defp build_schema(schema) when is_list(schema) do
    Enum.map_join(schema, ", ", fn {name, type} -> "#{name} #{type}" end)
  end

  defp build_table_opts(opts) when is_binary(opts), do: opts

  defp build_table_opts(opts) when is_list(opts), do: build_table_opts(opts, "")

  defp build_table_opts([], opt_str), do: opt_str

  defp build_table_opts([{:fuzzy_match, true} | t], opt_str) do
    build_table_opts(t, "#{opt_str} min_infix_len='#{@default_min_infix_len}'")
  end

  defp build_table_opts([{:fuzzy_match, min_infix_len} | t], opt_str) do
    build_table_opts(t, "#{opt_str} min_infix_len='#{min_infix_len}'")
  end

  defp build_table_opts([{k, v} | t], opt_str) do
    build_table_opts(t, "#{opt_str} #{k}='#{v}'")
  end

  defp build_values(values) do
    Enum.map_join(values, ", ", &quote_value/1)
  end

  defp build_set_clause(attrs) when is_map(attrs) do
    Enum.map_join(attrs, ", ", fn {k, v} -> "#{k} = #{quote_value(v)}" end)
  end

  defp build_set_clause(attrs) when is_list(attrs) do
    Enum.map_join(attrs, ", ", fn {k, v} -> "#{k} = #{quote_value(v)}" end)
  end

  defp quote_value(val) when is_binary(val), do: "'#{val}'"
  defp quote_value(val) when is_integer(val), do: Integer.to_string(val)
  defp quote_value(val) when is_float(val), do: Float.to_string(val)

  defp quote_value(val) when is_list(val) do
    "(" <> Enum.map_join(val, ", ", &quote_value/1) <> ")"
  end
end