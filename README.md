Giza: Sphinx Search Client
======
Elixir Client implementation of the Sphinx Fulltext Search Engine. Sphinx is a (very) fast, light, robust and highly customizable search solution. It's support for concurrency and reputable uptime keeps up with OTP beautifully. Giza supports all connection and querying methods Sphinx offers.

Read the full [docs for many usage examples](https://hexdocs.pm/giza_sphinxsearch/Giza.html#content).

**NEW:** 1.0.1 released. With cleaned up interface, documentation, concurrency model and easy configuration.  To upgrade
from 0.1.4 update your application file with the new simpler Giza.Application as shown below.


## Installation

Add `giza_sphinxsearch` to your list of dependencies in `mix.exs` and add to your application list:

```elixir
def deps do
  [{:giza_sphinxsearch, "~> 1.0"}]
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


## Querying Sphinx!

### SphinxQL (Recommended)

SphinxQL uses an SQL client to send requests to the Sphinx Daemon.  Giza exposes all Sphinx functionality through this
method and is recommended for client speed as well.  Thus this is the officially supported querying for this library.

```elixir
# Must have Sphinx beta 2.3.2 (or 3+ when released) to use suggest
alias Giza.SphinxQL

SphinxQL.new() 
  |> SphinxQL.suggest("posts_index", "splt")
  |> SphinxQL.send()

%SphinxqlResponse{fields: ["suggest", "distance", "docs"], matches: [["split", 1, 5]...]}
```

```elixir
SphinxQL.new()
|> SphinxQL.from("posts")
|> SphinxQL.match("tengri")
|> SphinxQL.send()
|> Giza.get_doc_ids()

[1, 4, 6, 12, ..]

{:ok, %{:total_found => last_query_total_found} = Giza.SphinxQL.meta()

800
```

```elixir
SphinxQL.new()
|> SphinxQL.raw("SELECT id, WEIGHT() as w FROM posts_index WHERE MATCH('subetei the swift')")
|> SphinxQL.send()

%SphinxqlResponse{ .. }
```

#### Recipes!

The recipe library allows you to make use of complex sphinx queries pre-prepared by Giza.  The first such recipe made
available is the ability to weigh your queries toward newer entries:

```elixir
SphinxQL.new()
|> SphinxQL.from("posts")
|> SphinxQL.match("tengri")
|> SphinxQL.Recipe.weigh_by_date("last_updated_timestamp")
|> SphinxQL.send()

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

Creates a sphinx config file with sensible defaults and info to connect to your database:
```elixir
mix giza.sphinx.config your_app YourApp.Repo
```
You can now open the generated file and update the SQL queries to whatever you want to index in your database.

Runs the batch indexer using the Sphinx conf in sphinx/sphinx.conf:
```elixir
mix giza.sphinx.index
```

Starts the search daemon.. after this you are running Sphinx or Manticore with your index and can query!
```elixir
mix giza.sphinx.searchd
```

Run a query over the sql protocol
```elixir
mix giza.sphinx.query "SELECT * FROM i_blog WHERE MATCH('miranda')"
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

https://hexdocs.pm/giza_sphinxsearch/1.0.0/Giza.SphinxProtocol.html#functions


### Sphinx HTTP REST API (experimental)

This is simply there to support the infrastructure but not recommended for production use yet.  If you have sphinx 2.3.2+ installed feel free to try this out if you prefer to use HTTP for any reason.  Please log any issues so this can be supported fully!

https://hexdocs.pm/giza_sphinxsearch/Giza.Http.html#functions


## Documentation

https://hexdocs.pm/giza_sphinxsearch/Giza.html#content

And to learn more about Sphinx from there excellent documentation:

http://sphinxsearch.com/docs/current.html

And to learn more about the recent Sphinx fork Manticore:

https://docs.manticoresearch.com/latest/html/

## Upcoming Development

- Do something about error messages from Maria client (they aren't currently easy to handle/read in Giza)

- Create the ability to download and run the sphinx binary locally so the project can be setup immediately via mix
