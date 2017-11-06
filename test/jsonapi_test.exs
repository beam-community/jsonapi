defmodule JSONAPITest do
  use ExUnit.Case
  use Plug.Test

  defmodule PostView do
    use JSONAPI.View

    def fields, do: [:text, :body]
    def type, do: "mytype"
    def relationships do
      [author: {JSONAPITest.UserView, :include},
       other_user: {JSONAPITest.UserView, :include}]
    end
  end

  defmodule UserView do
    use JSONAPI.View

    def fields, do: [:username]
    def type, do: "user"
    def relationships, do: []
  end

  defmodule MyPostPlug do
    use Plug.Builder

    plug JSONAPI.QueryParser,
      view: JSONAPITest.PostView,
      sort: [:text],
      filter: [:text]

    plug :passthrough

    defp passthrough(conn, _) do
      resp =
        PostView
        |> JSONAPI.Serializer.serialize(conn.assigns[:data], conn)
        |> Poison.encode!

      Plug.Conn.send_resp(conn, 200, resp)
    end
  end

  test "handles simple requests" do
    conn =
      :get
      |> conn("/posts")
      |> Plug.Conn.assign(:data, [%{
        id: 1,
        text: "Hello",
        body: "Hi",
        author: %{username: "jason", id: 2},
        other_user: %{username: "josh", id: 3}}])
      |> MyPostPlug.call([])

    json = conn.resp_body |> Poison.decode!

    assert Map.has_key?(json, "data")
    data_list = Map.get(json, "data")

    assert Enum.count(data_list) == 1
    [data | _] = data_list
    assert Map.get(data, "type") == "mytype"
    assert Map.get(data, "id") == "1"

    relationships = Map.get(data, "relationships")
    assert map_size(relationships) == 2
    assert Enum.sort(Map.keys(relationships)) == ["author", "other_user"]
    author_rel = Map.get(relationships, "author")

    assert get_in(author_rel, ["data", "type"]) == "user"
    assert get_in(author_rel, ["data", "id"]) == "2"

    assert Map.has_key?(json, "included")
    included = Map.get(json, "included")
    assert is_list(included)
    assert Enum.count(included) == 2

    [author | _] = included
    assert Map.get(author, "type") == "user"
    assert Map.get(author, "id") == "2"

    assert Map.has_key?(json, "links")
  end

  test "handles includes properly" do
    conn = conn(:get, "/posts?include=author")
    |> Plug.Conn.assign(:data, [%{
      id: 1,
      text: "Hello",
      body: "Hi",
      author: %{username: "jason", id: 2},
      other_user: %{username: "josh", id: 3}}])
    |> Plug.Conn.fetch_query_params()
    |> MyPostPlug.call([])

    json = conn.resp_body |> Poison.decode!

    assert Map.has_key?(json, "data")
    data_list = Map.get(json, "data")

    assert Enum.count(data_list) == 1
    [data | _] = data_list
    assert Map.get(data, "type") == "mytype"
    assert Map.get(data, "id") == "1"

    relationships = Map.get(data, "relationships")
    assert map_size(relationships) == 2
    assert Enum.sort(Map.keys(relationships)) == ["author", "other_user"]
    author_rel = Map.get(relationships, "author")

    assert get_in(author_rel, ["data", "type"]) == "user"
    assert get_in(author_rel, ["data", "id"]) == "2"

    assert Map.has_key?(json, "included")
    included = Map.get(json, "included")
    assert is_list(included)
    assert Enum.count(included) == 1

    [author] = included
    assert Map.get(author, "type") == "user"
    assert Map.get(author, "id") == "2"

    assert Map.has_key?(json, "links")
  end
end
