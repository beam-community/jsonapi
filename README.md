JSONAPI Elixir
=======

A project that will render your data models into [JSONAPI Documents](http://jsonapi.org/format). 

[![Build Status](https://travis-ci.org/jeregrine/jsonapi.svg)](https://travis-ci.org/jeregrine/jsonapi)

## JSONAPI Support
- [X] Basic [JSONAPI Document](http://jsonapi.org/format/#document-top-level) encoding [issue
- [X] Basic support for [compound documents](http://jsonapi.org/format/#document-compound-documents)
- [X] [Links](http://jsonapi.org/format/#document-links), 
- [X] Relationship links 
- [X] Parsing of `sort` query parameter into Ecto Query order_by
- [X] Parsing and limiting of `filter` keywords. )
- [X] Handling of sparse fieldsets
- [X] Handling of includes

## How to use
Simply add `use JSONAPI.PhoenixView` either to the top of your view, or to the web.ex view section and add the
proper functions to your view like so.

```elixir
defmodule PostView do
  use JSONAPI.View

  def fields(), do: [:text, :body]
  def type(), do: "mytype"
  def relationships(), do: [author: {JSONAPISerializerTest.UserView, :include}, comments: {JSONAPISerializerTest.CommentView, :include}]
end
```
is an example of a basic view. You can now call `render` normally in your phoenix application.


## Philosophy

- DSL's are great until you need something a little different. So use [Maps or functions](http://elixir-lang.org/getting-started/meta/domain-specific-languages.html)

## Other

- Feel free to make PR's. I will do my best to respond within a day or two. 
- If you want to take one of the TODO items just create an issue or PR and let me know so we avoid duplication.
- If you need help, I am on irc and twitter. 
