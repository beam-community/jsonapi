defmodule JSONAPI.ViewTest do
  use ExUnit.Case

  defmodule PostView do
    use JSONAPI.View, type: "posts"

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
