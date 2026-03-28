defmodule ManticoreQLTest do
  use ExUnit.Case, async: false

  alias Giza.QueryAdapter.Sandbox
  alias Giza.Structs.{SphinxqlQuery, SphinxqlResponse}

  setup do
    Sandbox.reset()
    :ok
  end

  # Helper to build QSUGGEST expected strings without confusing the tokenizer
  defp qsuggest_query(word, index, limit, max_edits) do
    "CALL QSUGGEST(" <>
      "'" <> word <> "'" <>
      ",'" <> index <> "'" <>
      ", " <> Integer.to_string(limit) <> " as limit" <>
      ", " <> Integer.to_string(max_edits) <> " as max_edits)"
  end

  # ==========================================================================
  # RT table lifecycle -- create, insert, query, teardown
  # ==========================================================================

  describe "RT table lifecycle" do
    test "create table, insert documents, search, drop" do
      # 1. Create the RT table
      {:ok, _} = SearchTables.create_table("products", "title text, price uint, brand_id uint")
      assert Sandbox.last_query() == "CREATE TABLE products (title text, price uint, brand_id uint)"

      # 2. Insert documents
      {:ok, _} = SearchTables.insert("products", ["id", "title", "price", "brand_id"], [1, "Elixir in Action", 40, 10])
      {:ok, _} = SearchTables.insert("products", ["id", "title", "price", "brand_id"], [2, "Programming Elixir", 35, 10])
      {:ok, _} = SearchTables.insert("products", ["id", "title", "price", "brand_id"], [3, "Rust in Action", 45, 20])

      # 3. Full-text search
      Sandbox.set_response({:ok, %{
        columns: ["id", "title", "price", "brand_id"],
        rows: [[1, "Elixir in Action", 40, 10], [2, "Programming Elixir", 35, 10]],
        num_rows: 2
      }})

      {:ok, result} =
        ManticoreQL.new()
        |> ManticoreQL.select(["id", "title", "price", "brand_id"])
        |> ManticoreQL.from("products")
        |> ManticoreQL.match("elixir")
        |> ManticoreQL.limit(10)
        |> Giza.send()

      assert Sandbox.last_query() ==
        "SELECT id, title, price, brand_id FROM products WHERE MATCH('elixir') LIMIT 0, 10"

      assert result.total == 2
      assert length(result.matches) == 2

      # 4. Drop table
      Sandbox.set_response({:ok, %{columns: [], rows: [], num_rows: 0}})
      {:ok, _} = SearchTables.drop_table("products")
      assert Sandbox.last_query() == "DROP TABLE products"
    end

    test "replace and update documents in an RT table" do
      {:ok, _} = SearchTables.replace("products", ["id", "title", "price"], [1, "Elixir in Action 2nd Ed", 50])
      assert Sandbox.last_query() == "REPLACE INTO products (id, title, price) VALUES (1, 'Elixir in Action 2nd Ed', 50)"

      {:ok, _} = SearchTables.update("products", [price: 42], "id = 1")
      assert Sandbox.last_query() == "UPDATE products SET price = 42 WHERE id = 1"
    end
  end

  # ==========================================================================
  # Delegated query builders -- composing queries via ManticoreQL
  # ==========================================================================

  describe "query composition (delegated)" do
    test "new/0 returns default query struct" do
      query = ManticoreQL.new()
      assert %SphinxqlQuery{select: ["*"], from: nil, where: nil, limit: 20, offset: 0} = query
    end

    test "select/from/match/limit/offset pipeline" do
      {:ok, _} =
        ManticoreQL.new()
        |> ManticoreQL.select(["id", "WEIGHT() as w"])
        |> ManticoreQL.from("posts")
        |> ManticoreQL.match("tengri")
        |> ManticoreQL.limit(5)
        |> ManticoreQL.offset(10)
        |> Giza.send()

      assert Sandbox.last_query() ==
        "SELECT id, WEIGHT() as w FROM posts WHERE MATCH('tengri') LIMIT 10, 5"
    end

    test "select with comma-separated string" do
      {:ok, _} =
        ManticoreQL.new()
        |> ManticoreQL.select("id, title, body")
        |> ManticoreQL.from("articles")
        |> ManticoreQL.match("search")
        |> Giza.send()

      assert Sandbox.last_query() ==
        "SELECT id, title, body FROM articles WHERE MATCH('search') LIMIT 0, 20"
    end

    test "match with list of terms" do
      {:ok, _} =
        ManticoreQL.new()
        |> ManticoreQL.from("posts")
        |> ManticoreQL.match(["subetei", "the", "swift"])
        |> Giza.send()

      assert Sandbox.last_query() ==
        "SELECT * FROM posts WHERE MATCH('subetei the swift') LIMIT 0, 20"
    end

    test "where with raw clause" do
      {:ok, _} =
        ManticoreQL.new()
        |> ManticoreQL.from("products")
        |> ManticoreQL.where("MATCH('laptop') AND price > 500")
        |> Giza.send()

      assert Sandbox.last_query() ==
        "SELECT * FROM products WHERE MATCH('laptop') AND price > 500 LIMIT 0, 20"
    end

    test "order_by clause" do
      {:ok, _} =
        ManticoreQL.new()
        |> ManticoreQL.from("posts")
        |> ManticoreQL.match("elixir")
        |> ManticoreQL.order_by("@relevance DESC, updated_at DESC")
        |> Giza.send()

      assert Sandbox.last_query() ==
        "SELECT * FROM posts WHERE MATCH('elixir') ORDER BY @relevance DESC, updated_at DESC LIMIT 0, 20"
    end

    test "option clause (expression ranker)" do
      {:ok, _} =
        ManticoreQL.new()
        |> ManticoreQL.from("posts")
        |> ManticoreQL.match("elixir")
        |> ManticoreQL.option("ranker=expr('sum(lcs*user_weight)*1000+bm25')")
        |> Giza.send()

      assert Sandbox.last_query() ==
        "SELECT * FROM posts WHERE MATCH('elixir') LIMIT 0, 20 OPTION ranker=expr('sum(lcs*user_weight)*1000+bm25')"
    end

    test "raw query bypasses builder" do
      {:ok, _} =
        ManticoreQL.new()
        |> ManticoreQL.raw("SELECT id, WEIGHT() as w FROM posts WHERE MATCH('subetei')")
        |> Giza.send()

      assert Sandbox.last_query() ==
        "SELECT id, WEIGHT() as w FROM posts WHERE MATCH('subetei')"
    end
  end

  # ==========================================================================
  # Manticore-specific -- facet
  # ==========================================================================

  describe "facet/2,3" do
    test "single facet" do
      {:ok, _} =
        ManticoreQL.new()
        |> ManticoreQL.from("products")
        |> ManticoreQL.match("phone")
        |> ManticoreQL.facet("brand_id")
        |> Giza.send()

      assert Sandbox.last_query() ==
        "SELECT * FROM products WHERE MATCH('phone') LIMIT 0, 20 FACET brand_id"
    end

    test "facet with order and limit" do
      {:ok, _} =
        ManticoreQL.new()
        |> ManticoreQL.from("products")
        |> ManticoreQL.match("phone")
        |> ManticoreQL.facet("price", order: "COUNT(*) DESC", limit: 10)
        |> Giza.send()

      assert Sandbox.last_query() ==
        "SELECT * FROM products WHERE MATCH('phone') LIMIT 0, 20 FACET price ORDER BY COUNT(*) DESC LIMIT 10"
    end

    test "multiple chained facets" do
      {:ok, _} =
        ManticoreQL.new()
        |> ManticoreQL.from("products")
        |> ManticoreQL.match("phone")
        |> ManticoreQL.facet("brand_id")
        |> ManticoreQL.facet("category_id", limit: 5)
        |> Giza.send()

      assert Sandbox.last_query() ==
        "SELECT * FROM products WHERE MATCH('phone') LIMIT 0, 20 FACET brand_id FACET category_id LIMIT 5"
    end
  end

  # ==========================================================================
  # Manticore-specific -- highlight
  # ==========================================================================

  describe "highlight/1,2" do
    test "bare highlight appends HIGHLIGHT() to select" do
      {:ok, _} =
        ManticoreQL.new()
        |> ManticoreQL.from("articles")
        |> ManticoreQL.match("elixir")
        |> ManticoreQL.highlight()
        |> Giza.send()

      assert Sandbox.last_query() ==
        "SELECT *, HIGHLIGHT() FROM articles WHERE MATCH('elixir') LIMIT 0, 20"
    end

    test "highlight with options" do
      {:ok, _} =
        ManticoreQL.new()
        |> ManticoreQL.from("articles")
        |> ManticoreQL.match("elixir")
        |> ManticoreQL.highlight(before_match: "<em>", after_match: "</em>", limit: 200)
        |> Giza.send()

      query = Sandbox.last_query()
      assert query =~ "HIGHLIGHT({"
      assert query =~ "before_match='<em>'"
      assert query =~ "after_match='</em>'"
      assert query =~ "limit='200'"
    end

    test "highlight combined with explicit select" do
      {:ok, _} =
        ManticoreQL.new()
        |> ManticoreQL.select(["id", "title"])
        |> ManticoreQL.from("articles")
        |> ManticoreQL.match("elixir")
        |> ManticoreQL.highlight()
        |> Giza.send()

      assert Sandbox.last_query() ==
        "SELECT id, title, HIGHLIGHT() FROM articles WHERE MATCH('elixir') LIMIT 0, 20"
    end
  end

  # ==========================================================================
  # Manticore-specific -- KNN vector search
  # ==========================================================================

  describe "knn/4" do
    test "generates KNN WHERE clause" do
      {:ok, _} =
        ManticoreQL.new()
        |> ManticoreQL.select(["id", "title", "knn_dist()"])
        |> ManticoreQL.from("articles")
        |> ManticoreQL.knn("embedding", 5, [0.1, 0.2, 0.3, 0.4])
        |> Giza.send()

      assert Sandbox.last_query() ==
        "SELECT id, title, knn_dist() FROM articles WHERE KNN(embedding, 5, (0.1, 0.2, 0.3, 0.4)) LIMIT 0, 20"
    end

    test "KNN with integer vector components" do
      {:ok, _} =
        ManticoreQL.new()
        |> ManticoreQL.select(["id", "knn_dist()"])
        |> ManticoreQL.from("docs")
        |> ManticoreQL.knn("vec", 3, [1, 2, 3])
        |> Giza.send()

      assert Sandbox.last_query() ==
        "SELECT id, knn_dist() FROM docs WHERE KNN(vec, 3, (1, 2, 3)) LIMIT 0, 20"
    end
  end

  # ==========================================================================
  # Manticore-specific -- percolate (reverse search)
  # ==========================================================================

  describe "percolate/2" do
    test "single document" do
      Sandbox.set_response({:ok, %{
        columns: ["id", "query"],
        rows: [[1, "breaking"]],
        num_rows: 1
      }})

      {:ok, result} = ManticoreQL.percolate("pq_alerts", ~s({"title": "breaking news"}))

      expected = "CALL PQ(" <> "'pq_alerts', " <> "'{\"title\": \"breaking news\"}" <> "')"
      assert Sandbox.last_query() == expected
      assert result.total == 1
    end

    test "multiple documents" do
      Sandbox.set_response({:ok, %{columns: ["id", "query"], rows: [], num_rows: 0}})

      {:ok, _} = ManticoreQL.percolate("pq_alerts", [
        ~s({"title": "foo"}),
        ~s({"title": "bar"})
      ])

      expected =
        "CALL PQ(" <>
        "'pq_alerts', " <>
        "'[{\"title\": \"foo\"}, {\"title\": \"bar\"}]" <>
        "')"
      assert Sandbox.last_query() == expected
    end
  end

  # ==========================================================================
  # Manticore-specific -- autocomplete / suggest
  # ==========================================================================

  describe "autocomplete/2,3" do
    test "basic autocomplete" do
      Sandbox.set_response({:ok, %{
        columns: ["suggest", "distance", "docs"],
        rows: [["elixir", 1, 120]],
        num_rows: 1
      }})

      {:ok, result} = ManticoreQL.autocomplete("elxi", "posts_index")

      expected = "CALL SUGGEST(" <> "'elxi', 'posts_index'" <> ")"
      assert Sandbox.last_query() == expected
      assert result.total == 1
      assert result.matches == [["elixir", 1, 120]]
    end

    test "autocomplete with options" do
      {:ok, _} = ManticoreQL.autocomplete("elxi", "posts_index", limit: 3, max_edits: 2)

      expected = "CALL SUGGEST(" <> "'elxi', 'posts_index'" <> ", 3 as limit, 2 as max_edits)"
      assert Sandbox.last_query() == expected
    end
  end

  describe "suggest/3,4 (delegated)" do
    test "suggest via QSUGGEST" do
      Sandbox.set_response({:ok, %{
        columns: ["suggest", "distance", "docs"],
        rows: [["split", 1, 5]],
        num_rows: 1
      }})

      {:ok, result} =
        ManticoreQL.new()
        |> ManticoreQL.suggest("posts_index", "splt")
        |> Giza.send()

      assert Sandbox.last_query() == qsuggest_query("splt", "posts_index", 5, 4)
      assert result.matches == [["split", 1, 5]]
    end

    test "suggest with custom limit and max_edits" do
      {:ok, _} =
        ManticoreQL.new()
        |> ManticoreQL.suggest("posts_index", "splt", limit: 3, max_edits: 2)
        |> Giza.send()

      assert Sandbox.last_query() == qsuggest_query("splt", "posts_index", 3, 2)
    end
  end

  # ==========================================================================
  # Response mapping & errors
  # ==========================================================================

  describe "response mapping" do
    test "Giza.send maps ok to SphinxqlResponse" do
      Sandbox.set_response({:ok, %{
        columns: ["id", "title"],
        rows: [[1, "Elixir"], [2, "Rust"]],
        num_rows: 2
      }})

      {:ok, result} =
        ManticoreQL.new()
        |> ManticoreQL.from("books")
        |> ManticoreQL.match("programming")
        |> Giza.send()

      assert %SphinxqlResponse{} = result
      assert result.fields == ["id", "title"]
      assert result.matches == [[1, "Elixir"], [2, "Rust"]]
      assert result.total == 2
    end

    test "error from adapter propagates" do
      Sandbox.set_response({:error, %{message: "index books: unknown table"}})

      assert {:error, "index books: unknown table"} =
        ManticoreQL.new()
        |> ManticoreQL.from("books")
        |> ManticoreQL.match("test")
        |> Giza.send()
    end

    test "percolate error propagates" do
      Sandbox.set_response({:error, %{mariadb: %{message: "PQ table not found"}}})

      assert {:error, "PQ table not found"} =
        ManticoreQL.percolate("nonexistent", ~s({"title": "test"}))
    end
  end

  # ==========================================================================
  # Helpers -- get_doc_ids
  # ==========================================================================

  describe "Giza.get_doc_ids/1" do
    test "extracts ids from SphinxqlResponse" do
      response = %SphinxqlResponse{
        fields: ["id", "title"],
        matches: [[1, "Elixir"], [5, "Rust"], [9, "Go"]],
        total: 3
      }

      assert {:ok, [9, 5, 1]} = Giza.get_doc_ids(response)
    end

    test "returns error when no id field" do
      response = %SphinxqlResponse{
        fields: ["title", "body"],
        matches: [["Elixir", "Functional"]],
        total: 1
      }

      assert {:error, _} = Giza.get_doc_ids(response)
    end
  end
end
