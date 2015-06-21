JSONAPI Elixir
=======
A project that will render your data models into [JSONAPI Documents](http://jsonapi.org/format). 

Currently in beta status.

## JSONAPI Support
- [x] Basic [JSONAPI Document](http://jsonapi.org/format/#document-top-level) encoding
- [x] Basic support for [compound documents](http://jsonapi.org/format/#document-compound-documents)
- [ ] [Links](http://jsonapi.org/format/#document-links)
- [ ] Relationship links (specifically handling relationships /user/1/image but only if its in a relationship :()
- [x] Parsing of `sort` query parameter into Ecto Query order_by
- [ ] Parsing and limiting of `filter` keywords into
- [ ] Handling of sparse fieldsets
- [ ] Handling of includes

## JSONAPI Elixir TODO
- [ ] Support full JSONAPI [Spec](http://jsonapi.org/format/)
- [ ] Make dependency on Phoenix optional
- [ ] Make dependency on Ecto optional
- [ ] Tests

## How to use
A View is simply a module that define certain callbacks to configure proper rendering of your JSONAPI
documents. 

```elixir
defmodule UserView do
  use JSONAPI.PhoenixView
  def url_func() do
    &App.Helpers.user_url/3
  end

  def type, do: "user"

  def attributes(model) do
    Map.take(model, [:username, :created_at,])
  end

  def relationships() do
    %{
      image: %{
        view: ImageView
      },
      posts: %{
        view: PostView
        optional: true
      }
    }
  end
end
```
is an example of a basic view. You can now call `render` normally in your phoenix application.


## Philosophy

- Functions are better than Macro's in almost every case
- DSL's are great untill you need something a little different. So use Maps.
- Make it work, worry about fast and pretty later.

## Contributions

- Feel free to make PR's. I will do my best to respond within a day or two. 
- If you want to take one of the TODO items just create an issue or PR and let me know so we avoid duplication.
- If you need help, I am on irc and twitter. 
