defmodule JSONAPI.QueryParserTest do
  use ExUnit.Case
  import JSONAPI.QueryParser
  alias JSONAPI.Config

  defmodule MyView do
    use JSONAPI.View

    def fields(), do: [:id, :text, :body]
    def type(), do: "mytype"
  end

  test "parse_sort\2 turns sorts into valid ecto sorts"
  test "parse_sort\2 raises on invalid sorts"

  test "parse_filter\2 turns filters into valid anon functions"
  test "parse_filter\2 raises on invalid filters"

  test "parse_include\2 turns an include string into a keyword list" do
    config = struct(Config, opts: [include: [:author, comments: :author]])
    assert parse_include(config, "author,comments.author").include == config.opts[:include]
    assert parse_include(config, "author").include == [:author]
    assert parse_include(config, "comments,author").include == [:comments, :author]
    assert parse_include(config, "comments.author").include == [comments: :author]
  end

  test "parse_include\2 errors with invalid includes" do
    config = struct(Config, opts: [include: [:author]])
    assert_raise RuntimeError, "400 bad Request", fn ->
      parse_include(config, "author,comments.author") 
    end
  end

  test "parse_fields\2 turns a fields map into a map of validated fields" do
    config = struct(Config, view: JSONAPI.QueryParserTest.MyView)
    assert parse_fields(config, %{"mytype" => "id,text"}).fields == %{"mytype" => [:id, :text]}
  end

  test "parse_fields\2 raises on invalid parsing"
  
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
