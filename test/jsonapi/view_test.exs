defmodule JSONAPI.ViewTest do
  use ExUnit.Case, async: true

  defmodule PostView do
    use JSONAPI.View, type: "posts", namespace: "/api"
  end

  test "type/0 when specified via using macro" do
    assert PostView.type == "posts"
  end

  test "url_for/2 with namespace" do
    assert PostView.url_for(nil, nil) == "/api/posts"
    assert PostView.url_for([], nil) == "/api/posts"
    assert PostView.url_for(%{id: 1}, nil) == "/api/posts/1"
    assert PostView.url_for([], %Plug.Conn{}) == "http://www.example.com/api/posts"
    assert PostView.url_for(%{id: 1}, %Plug.Conn{}) == "http://www.example.com/api/posts/1"
    assert PostView.url_for_rel([], "comments", %Plug.Conn{}) == "http://www.example.com/api/posts/relationships/comments"
    assert PostView.url_for_rel(%{id: 1}, "comments", %Plug.Conn{}) == "http://www.example.com/api/posts/1/relationships/comments"
  end
end
