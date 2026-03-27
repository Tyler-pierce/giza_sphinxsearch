defmodule SearchTablesTest do
  use ExUnit.Case, async: false

  alias Giza.QueryAdapter.Sandbox
  alias Giza.Structs.SphinxqlResponse

  setup do
    Sandbox.reset()
    :ok
  end

  # ==========================================================================
  # DDL — table lifecycle
  # ==========================================================================

  describe "create_table/2" do
    test "with string schema" do
      {:ok, _} = SearchTables.create_table("products", "title text, price uint")
      assert Sandbox.last_query() == "CREATE TABLE products (title text, price uint)"
    end

    test "with tuple list schema" do
      {:ok, _} = SearchTables.create_table("products", [{"title", "text"}, {"price", "uint"}])
      assert Sandbox.last_query() == "CREATE TABLE products (title text, price uint)"
    end
  end

  describe "create_table/3" do
    test "with string opts" do
      {:ok, _} = SearchTables.create_table("products", "title text", "morphology='stem_en'")
      assert Sandbox.last_query() == "CREATE TABLE products (title text) morphology='stem_en'"
    end

    test "with keyword opts" do
      {:ok, _} = SearchTables.create_table("products", "title text", morphology: "stem_en")
      assert Sandbox.last_query() == "CREATE TABLE products (title text) morphology='stem_en'"
    end
  end

  describe "create_table_like/2" do
    test "generates LIKE clause" do
      {:ok, _} = SearchTables.create_table_like("products_copy", "products")
      assert Sandbox.last_query() == "CREATE TABLE products_copy LIKE products"
    end
  end

  describe "create_table_if_not_exists/2,3" do
    test "without opts" do
      {:ok, _} = SearchTables.create_table_if_not_exists("products", "title text")
      assert Sandbox.last_query() == "CREATE TABLE IF NOT EXISTS products (title text)"
    end

    test "with opts" do
      {:ok, _} = SearchTables.create_table_if_not_exists("products", "title text", "morphology='stem_en'")
      assert Sandbox.last_query() == "CREATE TABLE IF NOT EXISTS products (title text) morphology='stem_en'"
    end
  end

  describe "create_distributed_table/2" do
    test "with local and agent parts" do
      {:ok, _} = SearchTables.create_distributed_table("dist", [
        local: "shard1",
        local: "shard2",
        agent: "10.0.0.2:9312:remote"
      ])

      assert Sandbox.last_query() ==
        "CREATE TABLE dist type='distributed' local='shard1' local='shard2' agent='10.0.0.2:9312:remote'"
    end
  end

  describe "create_distributed_table/3" do
    test "with extra opts" do
      {:ok, _} = SearchTables.create_distributed_table("dist", [local: "shard1"], ha_strategy: "roundrobin")

      assert Sandbox.last_query() ==
        "CREATE TABLE dist type='distributed' local='shard1' ha_strategy='roundrobin'"
    end
  end

  describe "drop_table/1" do
    test "generates DROP TABLE" do
      {:ok, _} = SearchTables.drop_table("products")
      assert Sandbox.last_query() == "DROP TABLE products"
    end
  end

  describe "drop_table/2" do
    test "with if_exists: true" do
      {:ok, _} = SearchTables.drop_table("products", if_exists: true)
      assert Sandbox.last_query() == "DROP TABLE IF EXISTS products"
    end

    test "with if_exists: false" do
      {:ok, _} = SearchTables.drop_table("products", if_exists: false)
      assert Sandbox.last_query() == "DROP TABLE products"
    end
  end

  describe "truncate_table/1" do
    test "generates TRUNCATE TABLE" do
      {:ok, _} = SearchTables.truncate_table("products")
      assert Sandbox.last_query() == "TRUNCATE TABLE products"
    end
  end

  describe "describe_table/1" do
    test "generates DESCRIBE" do
      Sandbox.set_response({:ok, %{
        columns: ["Field", "Type", "Properties"],
        rows: [["id", "bigint", ""], ["title", "text", "indexed stored"]],
        num_rows: 2
      }})

      {:ok, result} = SearchTables.describe_table("products")

      assert Sandbox.last_query() == "DESCRIBE products"
      assert result.fields == ["Field", "Type", "Properties"]
      assert result.total == 2
    end
  end

  describe "show_create_table/1" do
    test "generates SHOW CREATE TABLE" do
      {:ok, _} = SearchTables.show_create_table("products")
      assert Sandbox.last_query() == "SHOW CREATE TABLE products"
    end
  end

  # ==========================================================================
  # DML — writing to RT tables
  # ==========================================================================

  describe "insert/3" do
    test "with string and integer values" do
      {:ok, _} = SearchTables.insert("products", ["id", "title", "price"], [1, "Laptop", 999])
      assert Sandbox.last_query() == "INSERT INTO products (id, title, price) VALUES (1, 'Laptop', 999)"
    end

    test "with float values" do
      {:ok, _} = SearchTables.insert("products", ["id", "score"], [1, 0.95])
      assert Sandbox.last_query() == "INSERT INTO products (id, score) VALUES (1, #{Float.to_string(0.95)})"
    end

    test "with MVA (list) values" do
      {:ok, _} = SearchTables.insert("products", ["id", "tags"], [1, [10, 20, 30]])
      assert Sandbox.last_query() == "INSERT INTO products (id, tags) VALUES (1, (10, 20, 30))"
    end
  end

  describe "replace/3" do
    test "generates REPLACE INTO" do
      {:ok, _} = SearchTables.replace("products", ["id", "title"], [1, "Updated"])
      assert Sandbox.last_query() == "REPLACE INTO products (id, title) VALUES (1, 'Updated')"
    end
  end

  describe "update/3" do
    test "with keyword list attrs" do
      {:ok, _} = SearchTables.update("products", [price: 799], "id = 1")
      assert Sandbox.last_query() == "UPDATE products SET price = 799 WHERE id = 1"
    end

    test "with map attrs" do
      {:ok, _} = SearchTables.update("products", %{"price" => 799}, "id = 1")
      assert Sandbox.last_query() == "UPDATE products SET price = 799 WHERE id = 1"
    end

    test "with string attr value" do
      {:ok, _} = SearchTables.update("products", [status: "active"], "id = 1")
      assert Sandbox.last_query() == "UPDATE products SET status = 'active' WHERE id = 1"
    end
  end

  describe "delete/2" do
    test "generates DELETE FROM with WHERE" do
      {:ok, _} = SearchTables.delete("products", "id = 1")
      assert Sandbox.last_query() == "DELETE FROM products WHERE id = 1"
    end
  end

  # ==========================================================================
  # Clustered DML
  # ==========================================================================

  describe "cluster_insert/4" do
    test "uses cluster:table notation" do
      {:ok, _} = SearchTables.cluster_insert("my_cluster", "products", ["id", "title"], [1, "Laptop"])
      assert Sandbox.last_query() == "INSERT INTO my_cluster:products (id, title) VALUES (1, 'Laptop')"
    end
  end

  describe "cluster_replace/4" do
    test "uses cluster:table notation" do
      {:ok, _} = SearchTables.cluster_replace("my_cluster", "products", ["id", "title"], [1, "Laptop"])
      assert Sandbox.last_query() == "REPLACE INTO my_cluster:products (id, title) VALUES (1, 'Laptop')"
    end
  end

  describe "cluster_delete/3" do
    test "uses cluster:table notation" do
      {:ok, _} = SearchTables.cluster_delete("my_cluster", "products", "id = 1")
      assert Sandbox.last_query() == "DELETE FROM my_cluster:products WHERE id = 1"
    end
  end

  # ==========================================================================
  # Replication cluster management
  # ==========================================================================

  describe "create_cluster/1" do
    test "generates CREATE CLUSTER" do
      {:ok, _} = SearchTables.create_cluster("my_cluster")
      assert Sandbox.last_query() == "CREATE CLUSTER my_cluster"
    end
  end

  describe "create_cluster/2" do
    test "with path" do
      {:ok, _} = SearchTables.create_cluster("my_cluster", "/var/data/cluster")
      assert Sandbox.last_query() == "CREATE CLUSTER my_cluster '/var/data/cluster' AS path"
    end
  end

  describe "join_cluster/2" do
    test "generates JOIN CLUSTER AT" do
      {:ok, _} = SearchTables.join_cluster("my_cluster", "10.0.0.1:9312")
      assert Sandbox.last_query() == "JOIN CLUSTER my_cluster AT '10.0.0.1:9312'"
    end
  end

  describe "join_cluster/3" do
    test "with path" do
      {:ok, _} = SearchTables.join_cluster("my_cluster", "10.0.0.1:9312", "/var/data/cluster")
      assert Sandbox.last_query() == "JOIN CLUSTER my_cluster AT '10.0.0.1:9312' '/var/data/cluster' AS path"
    end
  end

  describe "cluster_add_table/2" do
    test "generates ALTER CLUSTER ADD" do
      {:ok, _} = SearchTables.cluster_add_table("my_cluster", "products")
      assert Sandbox.last_query() == "ALTER CLUSTER my_cluster ADD products"
    end
  end

  describe "cluster_drop_table/2" do
    test "generates ALTER CLUSTER DROP" do
      {:ok, _} = SearchTables.cluster_drop_table("my_cluster", "products")
      assert Sandbox.last_query() == "ALTER CLUSTER my_cluster DROP products"
    end
  end

  describe "delete_cluster/1" do
    test "generates DELETE CLUSTER" do
      {:ok, _} = SearchTables.delete_cluster("my_cluster")
      assert Sandbox.last_query() == "DELETE CLUSTER my_cluster"
    end
  end

  # ==========================================================================
  # Maintenance
  # ==========================================================================

  describe "flush_table/1" do
    test "generates FLUSH RAMCHUNK" do
      {:ok, _} = SearchTables.flush_table("products")
      assert Sandbox.last_query() == "FLUSH RAMCHUNK products"
    end
  end

  describe "optimize_table/1" do
    test "generates OPTIMIZE TABLE" do
      {:ok, _} = SearchTables.optimize_table("products")
      assert Sandbox.last_query() == "OPTIMIZE TABLE products"
    end
  end

  describe "show_table_status/1" do
    test "generates SHOW TABLE STATUS" do
      Sandbox.set_response({:ok, %{
        columns: ["Variable_name", "Value"],
        rows: [["indexed_documents", "15000"], ["disk_bytes", "4096000"]],
        num_rows: 2
      }})

      {:ok, result} = SearchTables.show_table_status("products")

      assert Sandbox.last_query() == "SHOW TABLE products STATUS"
      assert result.total == 2
      assert result.fields == ["Variable_name", "Value"]
    end
  end

  # ==========================================================================
  # Response mapping & error handling
  # ==========================================================================

  describe "response mapping" do
    test "ok response maps to SphinxqlResponse" do
      Sandbox.set_response({:ok, %{columns: ["id", "title"], rows: [[1, "Laptop"]], num_rows: 1}})

      {:ok, result} = SearchTables.describe_table("products")

      assert %SphinxqlResponse{} = result
      assert result.fields == ["id", "title"]
      assert result.matches == [[1, "Laptop"]]
      assert result.total == 1
    end

    test "mariadb error maps to {:error, message}" do
      Sandbox.set_response({:error, %{mariadb: %{message: "index products: table does not exist"}}})

      assert {:error, "index products: table does not exist"} = SearchTables.drop_table("products")
    end

    test "generic error maps to {:error, message}" do
      Sandbox.set_response({:error, %{message: "connection refused"}})

      assert {:error, "connection refused"} = SearchTables.create_table("t", "title text")
    end
  end

  describe "sandbox" do
    test "queries/0 returns all queries in order" do
      SearchTables.create_table("a", "title text")
      SearchTables.create_table("b", "title text")
      SearchTables.drop_table("a")

      queries = Sandbox.queries()
      assert length(queries) == 3
      assert Enum.at(queries, 0) == "CREATE TABLE a (title text)"
      assert Enum.at(queries, 1) == "CREATE TABLE b (title text)"
      assert Enum.at(queries, 2) == "DROP TABLE a"
    end

    test "query_count/0 tracks executed queries" do
      assert Sandbox.query_count() == 0
      SearchTables.truncate_table("t")
      assert Sandbox.query_count() == 1
    end

    test "reset/0 clears queries and restores default response" do
      Sandbox.set_response({:error, %{message: "boom"}})
      SearchTables.truncate_table("t")
      Sandbox.reset()

      assert Sandbox.queries() == []
      {:ok, _} = SearchTables.truncate_table("t")
    end

    test "set_response with {:fn, fun} dispatches per query" do
      Sandbox.set_response({:fn, fn
        "DESCRIBE" <> _ ->
          {:ok, %{columns: ["Field", "Type"], rows: [["title", "text"]], num_rows: 1}}
        _ ->
          {:ok, %{columns: [], rows: [], num_rows: 0}}
      end})

      {:ok, desc} = SearchTables.describe_table("products")
      assert desc.total == 1

      {:ok, other} = SearchTables.truncate_table("products")
      assert other.total == 0
    end
  end
end
