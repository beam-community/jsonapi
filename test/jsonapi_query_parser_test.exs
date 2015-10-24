defmodule JSONAPI.QueryParserTest do
  use ExUnit.Case
  import JSONAPI.QueryParser
  alias JSONAPI.Config

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

  test "parse_include\2 turns an include string into a keyword list" do
    config = struct(Config, opts: [include: [:author, comments: :author]])
    assert parse_include(config, "author,comments.author").include == config.opts[:include]
    assert parse_include(config, "author").include == [:author]
    assert parse_include(config, "comments,author").include == [:comments, :author]
    assert parse_include(config, "comments.author").include == [comments: :author]
  end
end
