Giza Sphinx Search
======
A client for Sphinx Search engine for Elixir.  Sphinx is a fast, robust and highly customizable search solution.  This client now supports all of it's functionality and connection methods and can be used in an OTP application.


## Installation

Add `giza_sphinxsearch` to your list of dependencies in `mix.exs` and add to your application list:

```elixir
def deps do
  [{:giza_sphinxsearch, "~> 0.1.4"}]
end
```

## Settings

Giza wants to know where your sphinx host is and what port to use.  It will default to localhost and 9312/9308/9306. Only the ports of the connection
methods you wish to use should be defined.  The defaults are a common setup and most people will only need configure their production host.

```elixir
  config :giza_sphinxsearch,
  	host: 'localhost',
  	port: 9312
```

### Phoenix Setup Example

In your application.ex file add the Giza supervisor to query Giza (note this setup is not unique to Phoenix and works with most OTP setups):

```elixir
...
children = [
      ...

      supervisor(Giza.Endpoint, [Keyword.new([
        {:host, Application.get_env(:giza_sphinxsearch, :host)},
        {:port, Application.get_env(:giza_sphinxsearch, :port)},
        {:sql_port, Application.get_env(:giza_sphinxsearch, :sql_port)}
      ])])
    ]
...
```
Adding the sql port will initialize the Mariaex mysql client, which is used to query Sphinx using SphinxQL, the recommended way to query. All Sphinx functionality is available this way with the fastest possible client speed.


## Querying Sphinx!

### SphinxQL (Recommended)

SphinxQL is the recommended engine to query with and supports all features. You can send a raw query or build a supported query using similar pipe friendly methods as Ecto.

```elixir
# Must have Sphinx beta 2.3.2 (or 3+ when released) to use suggest
Giza.SphinxQL.new() 
  |> Giza.SphinxQL.suggest('posts_index', 'splt')
  |> Giza.Service.sphinxql_send()

%SphinxqlResponse{fields: ['suggest', 'distance', 'docs'], matches: [['split', 1, 5]...]}
```
Note for non-OTP apps the last line would be Giza.SphinxQL.send().

There are many examples in the documentation: https://hexdocs.pm/giza_sphinxsearch/0.1.4


### Native protocol

The native protocol can be easy to use as well with Giza's helpers and provides your query meta all at once.  For most needs this works well; for query Suggestions (such as for autocomplete), you should use SphinxQL however.

Examples:

```elixir
Giza.query('blog_index', 'subetei the swift')
  |> Giza.Query.limit(5)
  |> Giza.Query.offset(5)
  |> Giza.Query.filter_exclude('user_age', 1, 17)
  |> Giza.send()

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

https://hexdocs.pm/giza_sphinxsearch/0.1.0/Giza.Query.html


### Sphinx HTTP REST API (experimental)

This is simply there to support the infrastructure but not recommended for production use yet.  If you have sphinx 2.3.2+ installed feel free to try this out if you prefer to use HTTP for whichever reason.

More documentation and testing to follow.


## Documentation

https://hexdocs.pm/giza_sphinxsearch/0.1.1
