Giza Sphinx Search
======
Revived the old Giza erlang client for sphinx full text search, for Elixir. Sphinx is quality software and a great choice for elixir programmers as a full text search engine.  It is simple, highly configurable, lightweight and FAST.  Most elixir developers are used to the idea of a little learning early paying off later. Sphinx is like, exposing many search fundamentals that you should know even if more interested in elastic search.  And yet Sphinx remains easy to use, has great default settings and many options for scale.  Most of all it is enjoyable and can tank a server fire without going down.

This project wraps the older Giza project's erlang calls with Elixir calls and mappings. As implementing newer Sphinx features, Elixir will start to take over as the primary language of interaction with Sphinx protocol.  All of the original Erlang calls are also still available via :giza_query, :giza_response etc.


## Installation

Add `giza_sphinxsearch` to your list of dependencies in `mix.exs` and add to your application list:

```elixir
def deps do
  [{:giza_sphinxsearch, "~> 0.0.1"}]
end
```

```elixir
def application do
  [applications: [..., :giza_sphinxsearch]]
end
```

## Settings

Giza wants to know where your sphinx host is and what port to use.  It will default to localhost and 9312.

```elixir
  config :giza_sphinxsearch,
  	host: 'localhost',
  	port: 9312
```

## Examples

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


## Documentation

