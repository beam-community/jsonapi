JSONAPI Elixir
=======

A project that will render your data models into [JSONAPI Documents](http://jsonapi.org/format) and parse/verify JSONAPI query strings.

[![Build Status](https://travis-ci.org/jeregrine/jsonapi.svg)](https://travis-ci.org/jeregrine/jsonapi)

## JSONAPI Support
- [X] Basic [JSONAPI Document](http://jsonapi.org/format/#document-top-level) encoding
- [X] Basic support for [compound documents](http://jsonapi.org/format/#document-compound-documents)
- [X] [Links](http://jsonapi.org/format/#document-links)
- [X] Relationship links
- [X] Parsing of `sort` query parameter into Ecto Query order_by
- [X] Parsing and limiting of `filter` keywords.
- [X] Handling of sparse fieldsets
- [X] Handling of includes
- [X] Handling of pagination

## How to use with Phoenix

Simply add `use JSONAPI.View` either to the top of your view, or to the web.ex view section and add the
proper functions to your view like so.

```elixir
defmodule MyApp.PostView do
  use JSONAPI.View, type: "posts"

  def fields do
    [:text, :body, :excerpt]
  end

  def excerpt(post, _conn) do
    String.slice(post.body, 0..5)
  end

  def relationships do
    # The post's author will be included by default
    [author: {MyApp.UserView, :include},
     comments: MyApp.CommentView]
  end
end
```
is an example of a basic view. You can now call `render(conn, MyApp.PostView, "show.json", %{data: my_data})` or `'index.json` normally.

If you'd like to use this without phoenix simply use the `JSONAPI.View` and call `JSONAPI.Serializer.serialize(MyApp.PostView, data, conn)`.

## Parsing and validating a JSONAPI Request

```elixir
plug JSONAPI.QueryParser,
  filter: ~w(name),
  sort: ~w(name title inserted_at),
  view: PostView
```

This will add a `JSONAPI.Config` struct called `jsonapi_config` to your conn.assigns. If a user tries to
sort, filter, include, or sparse fieldset an invalid field it will raise a plug error that shows the
proper error message.

The config holds the values parsed into things that are easy to pass into an Ecto query, for example

`sort=-name` will be parsed into `sort: [desc: :name]` which can be passed directly to the order_by in ecto.

This sort of behavior is consistent for includes. Sparse fieldsets happen in the view using Map.take but
when Ecto gets more complex field selection support we will go further to only query the data we need.

You will need to handle filtering yourself, the filter is just a map with key=value.

## Spec Enforcement

We include a set of Plugs to make enforcing the JSONAPI spec for requests easy.  To add spec enforcement to your application, add `JSONAPI.EnsureSpec` to your pipeline:


```elixir
plug JSONAPI.EnsureSpec
```

Under-the-hood `JSONAPI.EnsureSpec` relies on three individual plugs:

+ `JSONAPI.ContentTypeNegotiation` — Requires the `Content-Type` and `Accept` headers are set correctly.

+ `JSONAPI.FormatRequired` — Verifies that the JSON body matches the expected `%{data: %{attributes: attributes}}` format.

+ `JSONAPI.IdRequired` — Confirm the `id` key is present in `%{data: data}` and that it matches the resource's `id` in the URI.

## Configuration

By default host and scheme are pulled from the provided conn but can be overridden via configuration like so:

```elixir
config :jsonapi,
  host: "www.someotherhost.com",
  scheme: "https",
  underscore_to_dash: true,
  remove_links: false
```

* **underscore_to_dash**

Additionally, JSONAPI now recommends the use of dashes (`-`) in place of underscore (`_`) as a word separator. Enabling this change is easy with the `underscore_to_dash` option, which handles the conversion for you.  Defaults to `false`.

* **remove_links**

`links` data can optionally be removed from the payload via setting the configuration above to `true`.  Defaults to `false`.

## Other

- Feel free to make PR's. I will do my best to respond within a day or two.
- If you want to take one of the TODO items just create an issue or PR and let me know so we avoid duplication.
- If you need help, I am on irc and twitter.
- [Example project](https://github.com/alexjp/jsonapi-testing)
