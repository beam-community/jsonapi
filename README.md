# JSONAPI Elixir

A project that will render your data models into [JSONAPI Documents](http://jsonapi.org/format) and parse/verify JSONAPI query strings.

[![Build Status](https://travis-ci.org/jeregrine/jsonapi.svg)](https://travis-ci.org/jeregrine/jsonapi)

## JSONAPI Support

This library implements [version 1.1](https://jsonapi.org/format/1.1/)
of the JSON:API spec.

- [x] Basic [JSONAPI Document](http://jsonapi.org/format/#document-top-level) encoding
- [x] Basic support for [compound documents](http://jsonapi.org/format/#document-compound-documents)
- [x] [Links](http://jsonapi.org/format/#document-links)
- [x] Relationship links
- [x] Parsing of `sort` query parameter into Ecto Query order_by
- [x] Parsing and limiting of `filter` keywords.
- [x] Handling of sparse fieldsets
- [x] Handling of includes
- [x] Handling of pagination
- [x] Handling of top level meta data

## Documentation

* [Full docs here](https://hexdocs.pm/jsonapi)
* [JSON API Spec (v1.1)](https://jsonapi.org/format/1.1/)

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

  def meta(data, _conn) do
    # this will add meta to each record
    # To add meta as a top level property, pass as argument to render function (shown below)
    %{meta_text: "meta_#{data[:text]}"}
  end

  def relationships do
    # The post's author will be included by default
    [author: {MyApp.UserView, :include},
     comments: MyApp.CommentView]
  end
end
```

You can now call `render(conn, MyApp.PostView, "show.json", %{data: my_data, meta: meta})`
or `"index.json"` normally.

If you'd like to use this without Phoenix simply use the `JSONAPI.View` and call
`JSONAPI.Serializer.serialize(MyApp.PostView, data, conn, meta)`.

## Parsing and validating a JSONAPI Request

In your controller you may add

```elixir
plug JSONAPI.QueryParser,
  filter: ~w(name),
  sort: ~w(name title inserted_at),
  view: PostView
```

This will add a `JSONAPI.Config` struct called `jsonapi_config` to your
`conn.assigns`. If a user tries to sort, filter, include, or requests an
invalid fieldset it will raise a `Plug` error that shows the proper error
message.

The config holds the values parsed into things that are easy to pass into an Ecto
query, for example `sort=-name` will be parsed into `sort: [desc: :name]` which
can be passed directly to the `order_by` in Ecto.

This sort of behavior is consistent for includes.

The `JSONAPI.QueryParser` plug also supports [sparse fieldsets](https://jsonapi.org/format/#fetching-sparse-fieldsets).
Please see its documentation for details.

## Camelized or Dasherized Fields

JSONAPI has recommended in the past the use of dashes (`-`) in place of underscore (`_`) as a
word separator for document member keys. However, as of [JSON API Spec (v1.1)](https://jsonapi.org/format/1.1/), it is now recommended that member names
are camelCased. This library provides various configuration options for maximum flexibility.

Transforming fields requires two steps:

1. camelCase *outgoing* fields requires you to set the `:field_transformation`
   configuration option. Example:

   ```elixir
   config :jsonapi,
     field_transformation: :camelize # or dasherize
   ```

2. Underscoring *incoming* params (both query and body) requires you add the
   `JSONAPI.UnderscoreParameters` Plug to your API's pipeline. Your pipeline in a
   Phoenix app might look something like this:

   ```elixir
   pipeline :api do
     plug(JSONAPI.EnsureSpec)
     plug(JSONAPI.UnderscoreParameters)
   end
   ```

## Spec Enforcement

We include a set of Plugs to make enforcing the JSONAPI spec for requests easy. To add spec enforcement to your application, add `JSONAPI.EnsureSpec` to your pipeline:

```elixir
plug JSONAPI.EnsureSpec
```

Under-the-hood `JSONAPI.EnsureSpec` relies on four individual plugs:

- `JSONAPI.ContentTypeNegotiation` — Requires the `Content-Type` and `Accept` headers are set correctly.

- `JSONAPI.FormatRequired` — Verifies that the JSON body matches the expected `%{data: %{attributes: attributes}}` format.

- `JSONAPI.IdRequired` — Confirm the `id` key is present in `%{data: data}` and that it matches the resource's `id` in the URI.

- `JSONAPI.ResponseContentType` — Ensures that you return the correct `Content-Type` header.

## Configuration

```elixir
config :jsonapi,
  host: "www.someotherhost.com",
  scheme: "https",
  namespace: "/api",
  field_transformation: :underscore,
  remove_links: false,
  json_library: Jason
```

- **host**, **scheme**. By default these are pulled from the `conn`, but may be
  overridden.
- **namespace**. This optional setting can be used to configure the namespace
  your resources live at (e.g. given "http://example.com/api/cars", `"/api"`
  would be the namespace). See also `JSONAPI.View` for setting on the resource's
  View itself.
- **remove_links**. `links` data can optionally be removed from the payload via
  setting the configuration above to `true`. Defaults to `false`.
- **json_library**. Defaults to [Jason](https://hex.pm/packages/jason).
- **field_transformation**. This option describes how your API's fields word
  boundaries are marked. [JSON API Spec (v1.1)](https://jsonapi.org/format/1.1/) recommends using camelCase (e.g.
  `"favoriteColor": blue`). If your API uses camelCase fields, set this value to
  `:camelize`. JSON:API v1.0 recommended using a dash (e.g.
  `"favorite-color": blue`). If your API uses dashed fields, set this value to
  `:dasherize`. If your API uses underscores (e.g. `"favorite_color": "red"`)
  set to `:underscore`.

## Other

- Feel free to make PR's. I will do my best to respond within a day or two.
- If you want to take one of the TODO items just create an issue or PR and let me know so we avoid duplication.
- If you need help, I am on irc and twitter.
- [Example project](https://github.com/alexjp/jsonapi-testing)
