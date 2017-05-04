# Giza

Reviving the old Giza erlang client for sphinx full text search in Elixir. Sphinx is quality software and this writers preferred full text search engine.  It is simple, highly configurable, lightweight and FAST.  This project wraps the older Giza project's erlang calls and as implementing newer Sphinx features, will start to take over as a fully elixir based project.

## Installation

Add `giza_sphinxsearch` to your list of dependencies in `mix.exs` and add to your application list:

```elixir
def deps do
  [{:giza_sphinxsearch, "~> 0.1.0"}]
end
```

```elixir
def application do
  [applications: [..., :giza_sphinxsearch]]
end
```
Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/giza_sphinxsearch](https://hexdocs.pm/giza_sphinxsearch).

