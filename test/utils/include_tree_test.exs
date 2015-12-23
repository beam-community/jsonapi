defmodule JSONAPI.IncludeTreeTest do
  use ExUnit.Case
  import JSONAPI.Utils.IncludeTree

  test "put_as_tree\3 builds the path" do
    items = [:test, :the, :path]
    assert put_as_tree([], items, :boo) == [test: [the: [path: :boo]]]
  end
end
