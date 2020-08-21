defmodule Mix.Tasks.Giza.Sphinx.Config do
  use Mix.Task

  @shortdoc "Generate a Sphinx Search Config file. Uses database credentials + sensible defaults"

  @moduledoc """
  Generate a Sphinx Search Config file. Uses database credentials + sensible defaults.

  Please see Sphinx Docs for more information on your config options:

  http://sphinxsearch.com/docs/current.html#conf-reference
  """

  def run([db_app, db_repo]) do
    db_conf = Application.get_env(String.to_atom(db_app), String.to_atom("Elixir.#{db_repo}"))
    
    conf_map = get_db_conf_map(db_conf)

    sphinx_conf = generate_source(conf_map) <> "\n" <>
      generate_source_example_recent() <> "\n" <>
      generate_source_example() <> "\n" <>
      generate_index() <> "\n" <>
      generate_index_example_recent() <> "\n" <>
      generate_index_example() <> "\n"

    _ = File.mkdir("sphinx")

    _ = File.mkdir("sphinx/data")

    {:ok, file} = File.open "sphinx/sphinx.conf", [:write]

    _ = IO.binwrite file, sphinx_conf

    _ = File.close file

    Mix.shell.info "Config created at sphinx/sphinx.conf.  Edit your SQL queries there before you index your database."
  end

  def run(_), do: Mix.shell.info "Must pass the name of your data app and repo module. Example: mix giza.sphinx.config my_app MyApp.Repo"

  defp generate_source(%{type: type, database: database, username: username, password: password, hostname: hostname}) do
    ~s"""
    source source1
    {
      type = #{type}

      #####################################################################
      ## SQL settings
      #####################################################################

      sql_host = #{hostname}
      sql_user = #{username}
      sql_pass = #{password}
      sql_db   = #{database}
    }
    """
  end

  defp generate_source_example_recent() do
    ~s"""
    source source_example_recent : source1
    {
      sql_query = \\ 
        SELECT id, example_field \\ 
        FROM example_table \\ 
        WHERE updated_at > (CURRENT_TIMESTAMP - INTERVAL '24 HOUR')

      sql_field_string = example_field
    }
    """
  end

  defp generate_source_example() do
    ~s"""
    source source_example : source_example_recent
    {
      sql_query = \\ 
        SELECT id, example_field \\ 
        FROM example_table

      sql_field_string = example_field
    }
    """
  end

  defp generate_index() do
    ~s"""
    index i_defaults
    {
      type = plain

      source = source1

      path = sphinx/data/default

      morphology = none

      min_stemming_len = 1

      min_word_len   = 1
      min_prefix_len = 0
      min_infix_len  = 0

      html_strip = 0

      preopen = 0
    }

    indexer
    {
      # memory limit, in bytes, kiloytes (16384K) or megabytes (256M)
      # optional, default is 128M, max is 2047M, recommended is 256M to 1024M
      mem_limit = 1024M
    }

    searchd
    {
      listen = 9312
      listen = 9306:mysql41

      log = sphinx/data/searchd.log

      query_log = sphinx/data/query.log

      read_timeout = 2

      pid_file = sphinx/data/searchd.pid
    }

    common
    {
    }
    """
  end

  defp generate_index_example_recent() do
    ~s"""
    index i_example_recent : i_defaults
    {
      source = source_example_recent
      path = sphinx/data/example_recent
    }
    """
  end

  defp generate_index_example() do
    ~s"""
    index i_example : i_defaults
    {
      source = source_example
      path = sphinx/data/example
    }
    """
  end

  defp get_db_conf_map(db_conf), do: get_db_conf_map(db_conf, %{})

  defp get_db_conf_map([], acc), do: acc

  defp get_db_conf_map([{:database, database}|db_conf], %{} = acc) do
    get_db_conf_map(db_conf, Map.put(acc, :database, database))
  end

  defp get_db_conf_map([{:username, username}|db_conf], %{} = acc) do
    get_db_conf_map(db_conf, Map.put(acc, :username, username))
  end

  defp get_db_conf_map([{:password, password}|db_conf], %{} = acc) do
    get_db_conf_map(db_conf, Map.put(acc, :password, password))
  end

  defp get_db_conf_map([{:hostname, hostname}|db_conf], %{} = acc) do
    get_db_conf_map(db_conf, Map.put(acc, :hostname, hostname))
  end

  defp get_db_conf_map([{:adapter, Ecto.Adapters.Postgres}|db_conf], %{} = acc) do
    get_db_conf_map(db_conf, Map.put(acc, :type, "pgsql"))
  end

  defp get_db_conf_map([{:adapter, Ecto.Adapters.MySQL}|db_conf], %{} = acc) do
    get_db_conf_map(db_conf, Map.put(acc, :type, "mysql"))
  end

  defp get_db_conf_map([{:adapter, Ecto.Adapters.MyXQL}|db_conf], %{} = acc) do
    get_db_conf_map(db_conf, Map.put(acc, :type, "mysql"))
  end

  defp get_db_conf_map([_|db_conf], %{} = acc) do
    get_db_conf_map(db_conf, acc)
  end
end