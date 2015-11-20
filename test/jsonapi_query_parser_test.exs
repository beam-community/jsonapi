defmodule JSONAPI.QueryParserTest do
  use ExUnit.Case
  import JSONAPI.QueryParser
  alias JSONAPI.Exceptions.InvalidQuery
  alias JSONAPI.Config

  defmodule MyView do
    use JSONAPI.View

    def fields(), do: [:id, :text, :body]
    def type(), do: "mytype"
    def includes(), do: [authors: MyView]
  end

  test "parse_sort\2 turns sorts into valid ecto sorts" do
    config = struct(Config, opts: [sort: [:name, :title]])
    assert parse_sort(config, "name,title").sort == [asc: :name, asc: :title]
    assert parse_sort(config, "name").sort == [asc: :name]
    assert parse_sort(config, "-name").sort == [desc: :name]
    assert parse_sort(config, "name,-title").sort == [asc: :name, desc: :title]
  end

  test "parse_sort\2 raises on invalid sorts" do
    config = struct(Config, opts: [], view: MyView)
    assert_raise InvalidQuery, "invalid sort, name for type mytype", fn ->
      parse_sort(config, "name")
    end
  end

  test "parse_filter\2 turns filters into valid anon functions" do
    config = struct(Config, opts: [filter: [name: fn (key, val, ds, conn) -> {key, val, ds, conn} end]])
    %{name: fun} = parse_filter(config, %{name: "jason"}).filter
    assert is_function(fun)
    assert fun.(:x, :conn) == {:name, "jason", :x, :conn}
  end

  test "parse_filter\2 raises on invalid filters" do
    config = struct(Config, opts: [], view: MyView)
    assert_raise InvalidQuery, "invalid filter, name for type mytype", fn ->
      parse_filter(config, %{name: "jason"})
    end
  end

  test "parse_include\2 turns an include string into a keyword list" do
    config = struct(Config, opts: [include: [:author, comments: :author]])
    assert parse_include(config, "author,comments.author").include == config.opts[:include]
    assert parse_include(config, "author").include == [:author]
    assert parse_include(config, "comments,author").include == [:comments, :author]
    assert parse_include(config, "comments.author").include == [comments: :author]
  end

  test "parse_include\2 errors with invalid includes" do
    config = struct(Config, opts: [include: [:author]], view: MyView)
    assert_raise InvalidQuery, "invalid include, comments.author for type mytype", fn ->
      parse_include(config, "author,comments.author") 
    end
  end

  test "parse_fields\2 turns a fields map into a map of validated fields" do
    config = struct(Config, view: JSONAPI.QueryParserTest.MyView)
    assert parse_fields(config, %{"mytype" => "id,text"}).fields == %{"mytype" => [:id, :text]}
  end

  test "parse_fields\2 raises on invalid parsing" do
    config = struct(Config, view: JSONAPI.QueryParserTest.MyView)
    assert_raise InvalidQuery, "invalid fields, blag for type mytype", fn ->
      parse_fields(config, %{"mytype" => "blag"})
    end
  end
  
  test "member_of_tree?\2 traverses the tree" do
    include = [test: [the: :path]]
    assert member_of_tree?([:test, :the], include) == true
    assert member_of_tree?([:test], include) == true

    assert member_of_tree?([:blah], include) == false
    assert member_of_tree?([:test, :not], include) == false
  end
  test "put_as_tree\3 builds the path" do
    items = [:test, :the, :path]
    assert put_as_tree([], items, :boo) == [test: [the: [path: :boo]]]
  end
  test "get_view_for_type\2" do
    mod = MyApp.MyView
    type = "post"
    assert get_view_for_type(mod, type) == MyApp.PostView
  end

end
