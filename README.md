Giza: Sphinx Search Client
======
Elixir Client implementation of the Sphinx Fulltext Search Engine. Sphinx is a (very) fast, light, robust and highly customizable search solution. It's support for concurrency and reputable uptime pairs with OTP nicely.

Read the full [docs for many usage examples](https://hexdocs.pm/giza_sphinxsearch/Giza.html#content).

Sphinx forked into Sphinxsearch and Manticore Search with each now having some separate functionality but sharing
most core functionality. This library serves both and is designed to keep up with both, focused on the sql style
querying interface.

**NEW:** 2.0.0 released. Focused on real time tables and implementing Manticore specific functionality. Sphinx
specific functions will come soon.

  * Vector Search
  * Real-time Tables
  * Percolate Indexed Tables
  * Clustering
  * Distributed Tables

## Installation

Add `giza_sphinxsearch` to your list of dependencies in `mix.exs` and add to your application list:

```elixir
def deps do
  [{:giza_sphinxsearch, "~> 2.1"}]
end
```

And add Giza to your application tree:

```elixir
# lib/your_app_name/application.ex for Phoenix and most OTP applications
children = [
  ...,
  supervisor(Giza.Application, [])
]
```


## Usage Options

Giza wants to know where your sphinx host is and what ports to use.  It uses sensible defaults based on most setups.  The 3 connection type ports (native sphinx/http/sphinxQL) can be overriden optionally as shown below as well as the host in case you run Sphinx on a separate cluster/machine in production for example.

```elixir
# SQL Port recommened so you can query with SphinxQL
config :giza_sphinxsearch,
  host: 'localhost',
  sql_port: 9306,
  port: 9312,
  http_port: 9308
```


## Querying Sphinx

### ManticoreQL (or SphinxQL)

SphinxQL uses an SQL client to send requests to the Sphinx Daemon.  Giza exposes all Sphinx functionality through this
method and is recommended for client speed as well.  This is the officially supported querying for this library.

```elixir
iex> alias Giza.{SearchTable, ManticoreQL}

iex> SearchTables.create_table(
       "test_table_3",
       [{"title", "text"}, {"price", "uint"}, {"updated_at", "timestamp"}], 
       fuzzy_match: true
     )
      
{:ok, ..}

iex> SearchTables.insert("test_table", ["title", "price", "updated_at"], ["test", 1, 123..])

{:ok, ..}

iex> ManticoreQL.new()
     |> ManticoreQL.suggest("test_table", "tst") 
     |> ManticoreQL.send!()

%SphinxqlResponse{fields: ["suggest", "distance", "docs"], matches: [["split", 1, 5]...]}

iex> result = ManticoreQL.new()
              |> ManticoreQL.from("test_table")
              |> ManticoreQL.match("te*")
              |> Gize.send!()

%SphinxqlResponse{fields: ["id", "title", "price"], total: 1, matches: [[1444.., "test", 1]]

iex> Giza.ids!(result)
[1444809278530519042]

iex> SphinxQL.new()
     |> SphinxQL.raw("SELECT id, WEIGHT() as w FROM test_table WHERE MATCH('test')")
     |> SphinxQL.send()

{:ok, %SphinxqlResponse{ .. }}
```

#### Recipes

The recipe library wraps sphinx/manticore queries that may be difficult to remember.  The first such recipe made
available is the ability to weigh your queries toward newer entries:

```elixir
alias Giza.SphinxQL.Recipe

iex> ManticoreQL.new()
     |> ManticoreQL.from("posts")
     |> ManticoreQL.match("test")
     |> Recipe.weigh_by_date("updated_at")
     |> ManticoreQL.send!()

%SphinxqlResponse{ .. }
```

Here is one that helps you filter on your source attributes:

```elixir
SphinxQL.new()
|> SphinxQL.from("blog_comments")
|> SphinxQL.Recipe.match_and_filter("subetei", post_id: 1, depth: 2)
|> SphinxQL.send()

%SphinxqlResponse{ .. }
```

There are more examples [here in the documentation](https://hexdocs.pm/giza_sphinxsearch/Giza.SphinxQL.html#functions).


### Mix Helpers

There are several mix tasks packaged with Giza to help you get up and running with Sphinx immediately.  These are especially great if you are new to Sphinx and want a headstart learning configuration.

Starts the search daemon
```elixir
mix giza.sphinx.searchd
```

Run a query over the sql protocol
```elixir
mix giza.sphinx.query "SELECT * FROM blog WHERE MATCH('miranda')"
```

### Native protocol

The native protocol can be easy to use as well with Giza's helpers and provides your query meta all at once.  For most needs this works well; for some features like Search Suggestions (such as for autocomplete), you should use SphinxQL. Credit goes to the original Giza author for the Erlang client, as we still route these requests through that code. We wrap the returned value in a more convenient Map.

Examples:

```elixir
alias Giza.SphinxProtocol

SphinxProtocol.query("blog_index", "subetei the swift")
|> SphinxProtocol.limit(5)
|> SphinxProtocol.offset(5)
|> SphinxProtocol.filter_exclude('user_age', 1, 17)
|> SphinxProtocol.send()

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
    total: 5, 
    total_found: 19, 
    warnings: [],
    words: [{"subetei the swift", 5, 8}]
  }
}
```

https://hexdocs.pm/giza_sphinxsearch/2.0.0/Giza.SphinxProtocol.html#functions


### Sphinx HTTP REST API (experimental)

This is simply there to support the infrastructure but not recommended for production use yet.  If you have sphinx 2.3.2+ installed feel free to try this out if you prefer to use HTTP for any reason.  Please log any issues so this can be supported fully!

https://hexdocs.pm/giza_sphinxsearch/Giza.Http.html#functions


## Documentation

https://hexdocs.pm/giza_sphinxsearch/Giza.html#content

And to learn more about Sphinx from there documentation:

http://sphinxsearch.com/docs/current.html

And to learn more about the Sphinx fork Manticore:

https://docs.manticoresearch.com/latest/html/
