defmodule JSONAPI.ViewTest do
  use ExUnit.Case

  defmodule PostView do
    use JSONAPI.View, type: "posts", namespace: "/api"

    def fields do
      [:title, :body]
    end

    def hidden(%{title: "Hidden body"}) do
      [:body]
    end

    def hidden(_), do: []
  end

  defmodule CommentView do
    use JSONAPI.View, type: "comments"

    def fields do
      [:body]
    end
  end

  defmodule UserView do
    use JSONAPI.View,
      type: "users",
      namespace: "/api"

    def fields do
      [:age, :first_name, :last_name, :full_name, :password]
    end

    def full_name(user, _conn) do
      "#{user.first_name} #{user.last_name}"
    end

    def hidden do
      [:password]
    end
  end

  alias JSONAPI.ViewTest.CommentView

  test "type/0 when specified via using macro" do
    assert PostView.type() == "posts"
  end

  test "url_for/2" do
    assert PostView.url_for(nil, nil) == "/api/posts"
    assert PostView.url_for([], nil) == "/api/posts"
    assert PostView.url_for(%{id: 1}, nil) == "/api/posts/1"
    assert PostView.url_for([], %Plug.Conn{}) == "http://www.example.com/api/posts"
    assert PostView.url_for(%{id: 1}, %Plug.Conn{}) == "http://www.example.com/api/posts/1"

    assert PostView.url_for_rel([], "comments", %Plug.Conn{}) ==
             "http://www.example.com/api/posts/relationships/comments"

    assert PostView.url_for_rel(%{id: 1}, "comments", %Plug.Conn{}) ==
             "http://www.example.com/api/posts/1/relationships/comments"

    Application.put_env(:jsonapi, :host, "www.otherhost.com")
    assert PostView.url_for([], %Plug.Conn{}) == "http://www.otherhost.com/api/posts"
    assert PostView.url_for(%{id: 1}, %Plug.Conn{}) == "http://www.otherhost.com/api/posts/1"

    assert PostView.url_for_rel([], "comments", %Plug.Conn{}) ==
             "http://www.otherhost.com/api/posts/relationships/comments"

    assert PostView.url_for_rel(%{id: 1}, "comments", %Plug.Conn{}) ==
             "http://www.otherhost.com/api/posts/1/relationships/comments"

    Application.put_env(:jsonapi, :scheme, "ftp")
    assert PostView.url_for([], %Plug.Conn{}) == "ftp://www.otherhost.com/api/posts"
    assert PostView.url_for(%{id: 1}, %Plug.Conn{}) == "ftp://www.otherhost.com/api/posts/1"

    assert PostView.url_for_rel([], "comments", %Plug.Conn{}) ==
             "ftp://www.otherhost.com/api/posts/relationships/comments"

    assert PostView.url_for_rel(%{id: 1}, "comments", %Plug.Conn{}) ==
             "ftp://www.otherhost.com/api/posts/1/relationships/comments"
  end

  test "url_for_pagination/3" do
    assert PostView.url_for_pagination(nil, nil, %{}) == "/api/posts"

    assert PostView.url_for_pagination(nil, nil, %{number: 1, size: 10}) ==
             "/api/posts?page%5Bnumber%5D=1&page%5Bsize%5D=10"
  end

  test "render/2 is defined when 'Phoenix' is loaded" do
    assert {:render, 2} in CommentView.__info__(:functions)
  end

  test "show renders with data, conn" do
    data = CommentView.render("show.json", %{data: %{id: 1, body: "hi"}, conn: %Plug.Conn{}})
    assert data.data.attributes.body == "hi"
  end

  test "show renders with data, conn, meta" do
    data =
      CommentView.render("show.json", %{
        data: %{id: 1, body: "hi"},
        conn: %Plug.Conn{},
        meta: %{total_pages: 100}
      })

    assert data.meta.total_pages == 100
  end

  test "index renders with data, conn" do
    data = CommentView.render("index.json", %{data: [%{id: 1, body: "hi"}], conn: %Plug.Conn{}})
    data = Enum.at(data.data, 0)
    assert data.attributes.body == "hi"
  end

  test "index renders with data, conn, meta" do
    data =
      CommentView.render("index.json", %{
        data: [%{id: 1, body: "hi"}],
        conn: %Plug.Conn{},
        meta: %{total_pages: 100}
      })

    assert data.meta.total_pages == 100
  end

  test "attributes/2 does not display hidden fields with deprecated hidden/0" do
    expected_map = %{age: 100, first_name: "Jason", last_name: "S", full_name: "Jason S"}

    assert expected_map ==
             UserView.attributes(
               %{age: 100, first_name: "Jason", last_name: "S", password: "securepw"},
               nil
             )
  end

  test "attributes/2 does not display hidden fields based on a condition" do
    hidden_expected_map = %{title: "Hidden body"}
    normal_expected_map = %{title: "Other title", body: "Something"}

    assert hidden_expected_map ==
             PostView.attributes(
               %{title: "Hidden body", body: "Something"},
               nil
             )

    assert normal_expected_map ==
             PostView.attributes(
               %{title: "Other title", body: "Something"},
               nil
             )
  end
end
