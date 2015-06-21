JSONAPI Elixir
=======
A project that will render your data models into [JSONAPI Documents](http://jsonapi.org/format). 

Currently in beta status.

## JSONAPI Support
- [x] Basic [JSONAPI Document](http://jsonapi.org/format/#document-top-level) encoding [issue
- [x] Basic support for [compound documents](http://jsonapi.org/format/#document-compound-documents)
- [ ] [Links](http://jsonapi.org/format/#document-links), [issue#1](https://github.com/jeregrine/jsonapi/issues/1)
- [ ] Relationship links (handling relationships /user/1/image but only if its in a relationship :() [issue#2](https://github.com/jeregrine/jsonapi/issues/2)
- [x] Parsing of `sort` query parameter into Ecto Query order_by
- [ ] Parsing and limiting of `filter` keywords. [issue#3](https://github.com/jeregrine/jsonapi/issues/3)
- [ ] Handling of sparse fieldsets
- [ ] Handling of includes

## JSONAPI Elixir TODO
- [ ] Support full JSONAPI [Spec](http://jsonapi.org/format/)
- [ ] Make dependency on Phoenix optional [issue#4](https://github.com/jeregrine/jsonapi/issues/4)
- [ ] Make dependency on Ecto optional [issue#4](https://github.com/jeregrine/jsonapi/issues/4)
- [ ] Create a plug to handle query param validation and cleanup [issue#3](https://github.com/jeregrine/jsonapi/issues/3)
- [ ] Cleanup query/controller functions 
- [ ] Tests

## How to use
Simply add `use JSONAPI.PhoenixView` either to the top of your view, or to the web.ex view section and add the
proper functions to your view like so.

```elixir
defmodule UserView do
  use App.Web, :view
  use JSONAPI.PhoenixView

  def type, do: "user"

  def attributes(model) do
    Map.take(model, [:username, :created_at])
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
  
  def url_func() do
    &user_url/3
  end
end
```
is an example of a basic view. You can now call `render` normally in your phoenix application.


## Philosophy

- Functions are better than Macro's in almost every case
- DSL's are great until you need something a little different. So use Maps.
- Make it work, worry about the rest later.

## Other

- Feel free to make PR's. I will do my best to respond within a day or two. 
- If you want to take one of the TODO items just create an issue or PR and let me know so we avoid duplication.
- If you need help, I am on irc and twitter. 
