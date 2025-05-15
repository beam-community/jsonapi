defmodule JSONAPI.IncludeTreeTest do
  use ExUnit.Case
  import JSONAPI.Utils.IncludeTree

  test "put_as_tree\3 builds the path" do
    items = [:test, :the, :path]
    assert put_as_tree([], items, :boo) == [test: [the: [path: :boo]]]
  end

  test "deep_merge/2 handles string/keyword conflict by choosing second value" do
    # one direction
    assert [other: "thing", hi: [hello: "there"]] = deep_merge([other: "thing", hi: "there"], hi: [hello: "there"])
    # the other direction
    assert [hi: "there", other: "thing"] = deep_merge([hi: [hello: "there"]], other: "thing", hi: "there")
  end

  test "deep_merge/2 handles string/string conflict by choosing second value" do
    # one direction
    assert [hi: "there"] = deep_merge([hi: "hello"], hi: "there")
    # the other direction
    assert [hi: "hello"] = deep_merge([hi: "there"], hi: "hello")
  end
end
