# JSONAPI Elixir

[![Build](https://github.com/beam-community/jsonapi/actions/workflows/ci.yml/badge.svg)](https://github.com/beam-community/jsonapi/actions/workflows/ci.yml)
[![Hex.pm version](https://img.shields.io/hexpm/v/jsonapi.svg)](https://hex.pm/packages/jsonapi)
[![Hex.pm downloads](https://img.shields.io/hexpm/dt/jsonapi.svg)](https://hex.pm/packages/jsonapi)
[![Hex.pm weekly downloads](https://img.shields.io/hexpm/dw/jsonapi.svg)](https://hex.pm/packages/jsonapi)
[![Hex.pm daily downloads](https://img.shields.io/hexpm/dd/jsonapi.svg)](https://hex.pm/packages/jsonapi)

A project that will render your data models into [JSONAPI Documents](http://jsonapi.org/format) and parse/verify JSONAPI query strings.

## JSONAPI Support

This library implements [version 1.1](https://jsonapi.org/format/1.1/)
of the JSON:API spec.

- [x] Basic [JSONAPI Document](http://jsonapi.org/format/#document-top-level) encoding
- [x] Basic support for [compound documents](http://jsonapi.org/format/#document-compound-documents)
- [x] [Links](http://jsonapi.org/format/#document-links)
- [x] Relationship links
- [x] Parsing of `sort` query parameter into Ecto Query order_by
- [x] Parsing and limiting of `filter` keywords.
- [x] Handling of [sparse fieldsets](https://jsonapi.org/format/#fetching-sparse-fieldsets)
- [x] Handling of [includes](https://jsonapi.org/format/#fetching-includes)
- [x] Handling of [pagination](https://jsonapi.org/format/#fetching-pagination)
- [x] Handling of top level meta data

## Documentation

- [Full docs here](https://hexdocs.pm/jsonapi)
- [JSON API Spec (v1.1)](https://jsonapi.org/format/1.1/)

## Badges

![](https://github.com/jeregrine/jsonapi/workflows/Continuous%20Integration/badge.svg)

## How to use with Phoenix

### Installation

Add the following line to your `mix.deps` file with the desired version to install `jsonapi`.

```elixir
defp deps do [
  ...
  {:jsonapi, "~> x.x.x"}
  ...
]
```

### Usage

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

## Renaming relationships
If a relationship has a different name in the backend than you would like it to in your API,
you can rewrite its name in the `JSONAPI.View`. You pair the view with the name of the relationship
used in the data (e.g. Ecto schema) to achieve this. Note that you can use a triple instead 
of a pair to add the instruction to always include the relation if desired.

```elixir
defmodule MyApp.PostView do
  use JSONAPI.View, type: "posts"

  def relationships do
    # The `author` will be exposed as `creator` and the `comments` will be 
    # exposed as `critiques` (for some reason).
    [creator: {:author, MyApp.UserView, :include},
     critiques: {:comments, MyApp.CommentView}]
  end
end
```

## Parsing and validating a JSONAPI Request

In your controller you may add

```elixir
plug JSONAPI.QueryParser,
  filter: ~w(name),
  sort: ~w(name title inserted_at),
  view: PostView
```

This will add a `JSONAPI.Config` struct called `jsonapi_query` to your
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
are camelCased. This library provides various configuration options for maximum flexibility including serializing outgoing parameters and deserializing incoming parameters.

Transforming fields requires two steps:

1. camelCase _outgoing_ fields requires you to set the `:field_transformation`
   configuration option. Example:

   ```elixir
   config :jsonapi,
     field_transformation: :camelize # or dasherize
   ```

2. Underscoring _incoming_ params (both query and body) requires you add the
   `JSONAPI.UnderscoreParameters` Plug to your API's pipeline. This makes it easy to
   work with changeset data.

   ```elixir
   pipeline :api do
     plug JSONAPI.EnsureSpec
     plug JSONAPI.UnderscoreParameters
   end
   ```

3. JSONAPI.Deserializer is a plug designed to make a JSON:API resource object more convenient
   to work with when creating or updating resources. This plug works by taking the resource
   object format and flattening it into an easier to manipulate Map.

   Note that the deserializer expects the same casing for your _outgoing_ params as your
   _incoming_ params.

   Your pipeline in a Phoenix app might look something like this:

   ```elixir
   pipeline :api do
     plug JSONAPI.EnsureSpec
     plug JSONAPI.Deserializer
     plug JSONAPI.UnderscoreParameters
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
  json_library: Jason,
  paginator: nil
```

- **host**, **scheme**. By default these are pulled from the `conn`, but may be
  overridden.
- **namespace**. This optional setting can be used to configure the namespace
  your resources live at (e.g. given "http://example.com/api/cars", `"/api"`
  would be the namespace). See also `JSONAPI.View` for setting on the resource's
  View itself.
- **field_transformation**. This option describes how your API's fields word
  boundaries are marked. [JSON API Spec (v1.1)](https://jsonapi.org/format/1.1/) recommends using camelCase (e.g.
  `"favoriteColor": blue`). If your API uses camelCase fields, set this value to
  `:camelize`. JSON:API v1.0 recommended using a dash (e.g.
  `"favorite-color": blue`). If your API uses dashed fields, set this value to
  `:dasherize`. If your API uses underscores (e.g. `"favorite_color": "red"`)
  set to `:underscore`.
- **remove_links**. `links` data can optionally be removed from the payload via
  setting the configuration above to `true`. Defaults to `false`.
- **json_library**. Defaults to [Jason](https://hex.pm/packages/jason).
- **paginator**. Module implementing pagination links generation. Defaults to `nil`.

## Pagination

Pagination links can be generated by overriding the `JSONAPI.View.pagination_links/4` callback of your view and returning a map containing the links.

```elixir
...

def pagination_links(data, conn, page, options) do
  %{first: nil, last: nil, prev: nil, next: nil}
end
...
```

Alternatively you can define generic pagination strategies by implementing a module
conforming to the `JSONAPI.Paginator` behavior

```elixir
defmodule PageBasedPaginator do
  @moduledoc """
  Page based pagination strategy
  """

  @behaviour JSONAPI.Paginator

  @impl true
  def paginate(data, view, conn, page, options) do
    number =
      page
      |> Map.get("page", "0")
      |> String.to_integer()

    size =
      page
      |> Map.get("size", "0")
      |> String.to_integer()

    total_pages = Keyword.get(options, :total_pages, 0)

    %{
      first: view.url_for_pagination(data, conn, Map.put(page, "page", "1")),
      last: view.url_for_pagination(data, conn, Map.put(page, "page", total_pages)),
      next: next_link(data, view, conn, number, size, total_pages),
      prev: previous_link(data, view, conn, number, size)
    }
  end

  defp next_link(data, view, conn, page, size, total_pages)
       when page < total_pages,
       do: view.url_for_pagination(data, conn, %{size: size, page: page + 1})

  defp next_link(_data, _view, _conn, _page, _size, _total_pages),
    do: nil

  defp previous_link(data, view, conn, page, size)
       when page > 1,
       do: view.url_for_pagination(data, conn, %{size: size, page: page - 1})

  defp previous_link(_data, _view, _conn, _page, _size),
    do: nil
end
```

and configuring it as the global pagination logic in your `mix.config`

```elixir
config :jsonapi, :paginator, PageBasedPaginator
```

or as the view pagination logic when using `JSONAPI.View`

```elixir
use JSONAPI.View, paginator: PageBasedPaginator
```

Links can be generated using the `JSONAPI.Config.page` information stored in the connection assign `jsonapi_query` and by passing additional information to the `pagination_links/4` callback or your paginator module by passing `options` from your controller.

Actual pagination is expected to be handled in your application logic and is outside the scope of this library.

## Other

- Feel free to make PR's. I will do my best to respond within a day or two.
- If you want to take one of the TODO items just create an issue or PR and let me know so we avoid duplication.
- If you need help, I am on irc and twitter.
- [Example project](https://github.com/alexjp/jsonapi-testing)
