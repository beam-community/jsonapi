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
    use JSONAPI.View, type: "comments", namespace: "/api"

    def fields do
      [:body]
    end
  end

  defmodule UserView do
    use JSONAPI.View, type: "users"

    def fields do
      [:age, :first_name, :last_name, :full_name, :password]
    end

    def full_name(user, _conn) do
      "#{user.first_name} #{user.last_name}"
    end

    def hidden(_data) do
      [:password]
    end
  end

  defmodule CarView do
    use JSONAPI.View, type: "cars", namespace: ""
  end

  defmodule DynamicView do
    use JSONAPI.View

    def type, do: "dyns"

    def fields, do: [:static_fun, :static_field, :dynamic_1, :dynamic_2]

    def static_fun(_data, _conn), do: "static_fun/2"

    def get_field(field, _data, _conn), do: "#{field}!"
  end

  setup do
    Application.put_env(:jsonapi, :field_transformation, :underscore)
    Application.put_env(:jsonapi, :namespace, "/other-api")

    on_exit(fn ->
      Application.delete_env(:jsonapi, :field_transformation)
      Application.delete_env(:jsonapi, :namespace)
    end)

    {:ok, []}
  end

  test "type/0 when specified via using macro" do
    assert PostView.type() == "posts"
  end

  describe "namespace/0" do
    setup do
      Application.put_env(:jsonapi, :namespace, "/cake")

      on_exit(fn ->
        Application.delete_env(:jsonapi, :namespace)
      end)

      {:ok, []}
    end

    test "uses macro configuration first" do
      assert PostView.namespace() == "/api"
    end

    test "uses global namespace if available" do
      assert UserView.namespace() == "/cake"
    end

    test "can be blank" do
      assert CarView.namespace() == ""
    end
  end

  describe "url_for/2 when host and scheme not configured" do
    test "url_for/2" do
      assert PostView.url_for(nil, nil) == "/api/posts"
      assert PostView.url_for([], nil) == "/api/posts"
      assert PostView.url_for(%{id: 1}, nil) == "/api/posts/1"
      assert PostView.url_for([], %Plug.Conn{}) == "http://www.example.com/api/posts"
      assert PostView.url_for([], %Plug.Conn{port: 123}) == "http://www.example.com:123/api/posts"
      assert PostView.url_for(%{id: 1}, %Plug.Conn{}) == "http://www.example.com/api/posts/1"

      assert PostView.url_for_rel([], "comments", %Plug.Conn{}) ==
               "http://www.example.com/api/posts/relationships/comments"

      assert PostView.url_for_rel(%{id: 1}, "comments", %Plug.Conn{}) ==
               "http://www.example.com/api/posts/1/relationships/comments"
    end
  end

  describe "url_for/2 when host configured" do
    setup do
      Application.put_env(:jsonapi, :host, "www.otherhost.com")

      on_exit(fn ->
        Application.delete_env(:jsonapi, :host)
      end)

      {:ok, []}
    end

    test "uses configured host instead of that on Conn" do
      assert PostView.url_for_rel([], "comments", %Plug.Conn{}) ==
               "http://www.otherhost.com/api/posts/relationships/comments"

      assert PostView.url_for_rel(%{id: 1}, "comments", %Plug.Conn{}) ==
               "http://www.otherhost.com/api/posts/1/relationships/comments"

      assert PostView.url_for([], %Plug.Conn{}) == "http://www.otherhost.com/api/posts"
      assert PostView.url_for(%{id: 1}, %Plug.Conn{}) == "http://www.otherhost.com/api/posts/1"
    end
  end

  describe "url_for/2 when scheme configured" do
    setup do
      Application.put_env(:jsonapi, :scheme, "ftp")

      on_exit(fn ->
        Application.delete_env(:jsonapi, :scheme)
      end)

      {:ok, []}
    end

    test "uses configured scheme instead of that on Conn" do
      assert PostView.url_for([], %Plug.Conn{}) == "ftp://www.example.com/api/posts"
      assert PostView.url_for(%{id: 1}, %Plug.Conn{}) == "ftp://www.example.com/api/posts/1"

      assert PostView.url_for_rel([], "comments", %Plug.Conn{}) ==
               "ftp://www.example.com/api/posts/relationships/comments"

      assert PostView.url_for_rel(%{id: 1}, "comments", %Plug.Conn{}) ==
               "ftp://www.example.com/api/posts/1/relationships/comments"
    end
  end

  describe "url_for/2 when port configured" do
    setup do
      Application.put_env(:jsonapi, :port, 42)

      on_exit(fn ->
        Application.delete_env(:jsonapi, :port)
      end)

      {:ok, []}
    end

    test "uses configured port instead of that on Conn" do
      assert PostView.url_for([], %Plug.Conn{}) == "http://www.example.com:42/api/posts"
      assert PostView.url_for(%{id: 1}, %Plug.Conn{}) == "http://www.example.com:42/api/posts/1"

      assert PostView.url_for_rel([], "comments", %Plug.Conn{}) ==
               "http://www.example.com:42/api/posts/relationships/comments"

      assert PostView.url_for_rel(%{id: 1}, "comments", %Plug.Conn{}) ==
               "http://www.example.com:42/api/posts/1/relationships/comments"
    end
  end

  describe "url_for_pagination/3" do
    setup do
      {:ok, conn: Plug.Conn.fetch_query_params(%Plug.Conn{})}
    end

    test "with pagination information", %{conn: conn} do
      assert PostView.url_for_pagination(nil, conn, %{}) == "http://www.example.com/api/posts"

      assert PostView.url_for_pagination(nil, conn, %{number: 1, size: 10}) ==
               "http://www.example.com/api/posts?page%5Bnumber%5D=1&page%5Bsize%5D=10"
    end

    test "with query parameters", %{conn: conn} do
      conn_with_query_params =
        Kernel.update_in(conn.query_params, &Map.put(&1, "comments", [5, 2]))

      assert PostView.url_for_pagination(nil, conn_with_query_params, %{number: 1, size: 10}) ==
               "http://www.example.com/api/posts?comments%5B%5D=5&comments%5B%5D=2&page%5Bnumber%5D=1&page%5Bsize%5D=10"

      assert PostView.url_for_pagination(nil, conn_with_query_params, %{}) ==
               "http://www.example.com/api/posts?comments%5B%5D=5&comments%5B%5D=2"
    end
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
    data =
      CommentView.render("index.json", %{
        data: [%{id: 1, body: "hi"}],
        conn: Plug.Conn.fetch_query_params(%Plug.Conn{})
      })

    data = Enum.at(data.data, 0)
    assert data.attributes.body == "hi"
  end

  test "index renders with data, conn, meta" do
    data =
      CommentView.render("index.json", %{
        data: [%{id: 1, body: "hi"}],
        conn: Plug.Conn.fetch_query_params(%Plug.Conn{}),
        meta: %{total_pages: 100}
      })

    assert data.meta.total_pages == 100
  end

  test "visible_fields/2 returns all field names by default" do
    data = %{age: 100, first_name: "Jason", last_name: "S", password: "securepw"}

    assert [:age, :first_name, :last_name, :full_name] ==
             UserView.visible_fields(data, %Plug.Conn{})
  end

  test "visible_fields/2 removes any hidden field names" do
    data = %{title: "Hidden body", body: "Something"}

    assert [:title] == PostView.visible_fields(data, %Plug.Conn{})
  end

  test "visible_fields/2 trims returned field names to only those requested" do
    data = %{body: "Chunky", title: "Bacon"}
    config = %JSONAPI.Config{fields: %{PostView.type() => [:body]}}
    conn = %Plug.Conn{assigns: %{jsonapi_query: config}}

    assert [:body] == PostView.visible_fields(data, conn)
  end

  test "attributes/2 does not display hidden fields" do
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

  test "attributes/2 can return only requested fields" do
    data = %{body: "Chunky", title: "Bacon"}
    config = %JSONAPI.Config{fields: %{PostView.type() => [:body]}}
    conn = %Plug.Conn{assigns: %{jsonapi_query: config}}

    assert %{body: "Chunky"} == PostView.attributes(data, conn)
  end

  test "attributes/2 can return dynamic fields" do
    data = %{static_field: "static_field from the map"}
    conn = %Plug.Conn{assigns: %{jsonapi_query: %JSONAPI.Config{}}}

    assert %{
             dynamic_1: "dynamic_1!",
             dynamic_2: "dynamic_2!",
             static_field: "static_field!",
             static_fun: "static_fun/2"
           } == DynamicView.attributes(data, conn)
  end
end
