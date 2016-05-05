defmodule JSONAPI.QueryParserTest do
  use ExUnit.Case
  import JSONAPI.QueryParser
  alias JSONAPI.Exceptions.InvalidQuery
  alias JSONAPI.Config

  defmodule MyView do
    use JSONAPI.View

    def fields, do: [:id, :text, :body]
    def type, do: "mytype"
    def relationships do
      [author: JSONAPI.QueryParserTest.UserView,
       comments: JSONAPI.QueryParserTest.CommentView]
    end
  end

  defmodule UserView do
    use JSONAPI.View

    def fields, do: [:id, :username]
    def type, do: "user"
    def relationships, do: []
  end

  defmodule CommentView do
    use JSONAPI.View

    def fields, do: [:id, :text]
    def type, do: "comment"
    def relationships, do: [user: JSONAPI.QueryParserTest.UserView]
  end

  test "parse_sort/2 turns sorts into valid ecto sorts" do
    config = struct(Config, opts: [sort: ~w(name title)], view: MyView)
    assert parse_sort(config, "name,title").sort == [asc: :name, asc: :title]
    assert parse_sort(config, "name").sort == [asc: :name]
    assert parse_sort(config, "-name").sort == [desc: :name]
    assert parse_sort(config, "name,-title").sort == [asc: :name, desc: :title]
  end

  test "parse_sort/2 raises on invalid sorts" do
    config = struct(Config, opts: [], view: MyView)
    assert_raise InvalidQuery, "invalid sort, name for type mytype", fn ->
      parse_sort(config, "name")
    end
  end

  test "parse_filter/2 turns filters key/val pairs" do
    config = struct(Config, opts: [filter: ~w(name)], view: MyView)
    filter = parse_filter(config, %{"name" => "jason"}).filter
    assert filter[:name] == "jason"
  end

  test "parse_filter/2 raises on invalid filters" do
    config = struct(Config, opts: [], view: MyView)
    assert_raise InvalidQuery, "invalid filter, noop for type mytype", fn ->
      parse_filter(config, %{"noop" => "jason"})
    end
  end

  test "parse_include/2 turns an include string into a keyword list" do
    config = struct(Config, view: MyView)
    assert parse_include(config, "author,comments.user").includes == [:author, comments: :user]
    assert parse_include(config, "author").includes == [:author]
    assert parse_include(config, "comments,author").includes == [:comments, :author]
    assert parse_include(config, "comments.user").includes == [comments: :user]
  end

  test "parse_include/2 errors with invalid includes" do
    config = struct(Config, view: MyView)
    assert_raise InvalidQuery, "invalid include, user for type mytype", fn ->
      parse_include(config, "user,comments.author")
    end

    assert_raise InvalidQuery, "invalid include, comments.author for type mytype", fn ->
      parse_include(config, "comments.author")
    end

    assert_raise InvalidQuery, "invalid include, comments.author.user for type mytype", fn ->
      parse_include(config, "comments.author.user")
    end
  end

  test "parse_fields/2 turns a fields map into a map of validated fields" do
    config = struct(Config, view: MyView)
    assert parse_fields(config, %{"mytype" => "id,text"}).fields == %{"mytype" => [:id, :text]}
  end

  test "parse_fields/2 raises on invalid parsing" do
    config = struct(Config, view: MyView)
    assert_raise InvalidQuery, "invalid fields, blag for type mytype", fn ->
      parse_fields(config, %{"mytype" => "blag"})
    end
  end

  test "get_view_for_type/2" do
    assert get_view_for_type(MyView, "comments") == JSONAPI.QueryParserTest.CommentView
  end

  test "get_view_for_type/2 raises on invalid fiels" do
    assert_raise InvalidQuery, "invalid fields, comment for type mytype", fn ->
      get_view_for_type(MyView, "comment")
    end
  end
end
