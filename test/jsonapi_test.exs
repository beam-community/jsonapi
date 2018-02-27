defmodule JSONAPITest do
  use ExUnit.Case
  use Plug.Test

  defmodule PostView do
    use JSONAPI.View

    def fields, do: [:text, :body, :excerpt]
    def type, do: "mytype"

    def relationships do
      [author: {JSONAPITest.UserView, :include}, other_user: JSONAPITest.UserView]
    end

    def excerpt(post, _conn) do
      letter = String.slice(post.text, 0..1)
      letter
    end
  end

  defmodule UserView do
    use JSONAPI.View

    def fields, do: [:username]
    def type, do: "user"

    def relationships do
      [company: JSONAPITest.CompanyView]
    end
  end

  defmodule CompanyView do
    use JSONAPI.View

    def fields, do: [:name]
    def type, do: "company"

    def relationships do
      [industry: JSONAPITest.IndustryView]
    end
  end

  defmodule IndustryView do
    use JSONAPI.View

    def fields, do: [:name]
    def type, do: "industry"

    def relationships do
      [tags: JSONAPITest.TagView]
    end
  end

  defmodule TagView do
    use JSONAPI.View

    def fields, do: [:name]
    def type, do: "tag"
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
        |> Poison.encode!()

      Plug.Conn.send_resp(conn, 200, resp)
    end
  end

  test "handles simple requests" do
    conn =
      :get
      |> conn("/posts")
      |> Plug.Conn.assign(:data, [
        %{
          id: 1,
          text: "Hello",
          body: "Hi",
          author: %{username: "jason", id: 2},
          other_user: %{username: "josh", id: 3}
        }
      ])
      |> MyPostPlug.call([])

    json = conn.resp_body |> Poison.decode!()

    assert Map.has_key?(json, "data")
    data_list = Map.get(json, "data")

    assert Enum.count(data_list) == 1
    [data | _] = data_list
    assert Map.get(data["attributes"], "body") == "Hi"
    assert Map.get(data["attributes"], "text") == "Hello"
    assert Map.get(data["attributes"], "excerpt") == "He"
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

    [author | _] = included
    assert Map.get(author, "type") == "user"
    assert Map.get(author, "id") == "2"

    assert Map.has_key?(json, "links")
  end

  test "handles includes properly" do
    conn =
      conn(:get, "/posts?include=other_user")
      |> Plug.Conn.assign(:data, [
        %{
          id: 1,
          text: "Hello",
          body: "Hi",
          author: %{username: "jason", id: 2},
          other_user: %{username: "josh", id: 3}
        }
      ])
      |> Plug.Conn.fetch_query_params()
      |> MyPostPlug.call([])

    json = conn.resp_body |> Poison.decode!()

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

    other_user = Map.get(relationships, "other_user")

    assert get_in(other_user, ["data", "type"]) == "user"
    assert get_in(other_user, ["data", "id"]) == "3"

    assert Map.has_key?(json, "included")
    included = Map.get(json, "included")
    assert is_list(included)
    assert Enum.count(included) == 2

    assert Enum.find(included, fn include ->
             Map.get(include, "type") == "user" && Map.get(include, "id") == "2"
           end)

    assert Enum.find(included, fn include ->
             Map.get(include, "type") == "user" && Map.get(include, "id") == "3"
           end)

    assert Map.has_key?(json, "links")
  end

  test "handles deep nested includes properly" do
    data = [
      %{
        id: 1,
        text: "Hello",
        body: "Hi",
        author: %{username: "jason", id: 2},
        other_user: %{
          id: 1,
          username: "jim",
          first_name: "Jimmy",
          last_name: "Beam",
          company: %{
            id: 2,
            name: "acme",
            industry: %{
              id: 4,
              name: "stuff",
              tags: [
                %{id: 3, name: "a tag"},
                %{id: 4, name: "another tag"}
              ]
            }
          }
        }
      }
    ]

    conn =
      conn(:get, "/posts?include=other_user.company.industry.tags")
      |> Plug.Conn.assign(:data, data)
      |> Plug.Conn.fetch_query_params()
      |> MyPostPlug.call([])

    json = conn.resp_body |> Poison.decode!()

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

    other_user = Map.get(relationships, "other_user")

    assert get_in(other_user, ["data", "type"]) == "user"
    assert get_in(other_user, ["data", "id"]) == "1"

    assert Map.has_key?(json, "included")
    included = Map.get(json, "included")
    assert is_list(included)
    assert Enum.count(included) == 6

    assert Enum.find(included, fn include ->
             Map.get(include, "type") == "user" && Map.get(include, "id") == "2"
           end)

    assert Enum.find(included, fn include ->
             Map.get(include, "type") == "user" && Map.get(include, "id") == "1"
           end)

    assert Enum.find(included, fn include ->
             Map.get(include, "type") == "company" && Map.get(include, "id") == "2"
           end)

    assert Enum.find(included, fn include ->
             Map.get(include, "type") == "industry" && Map.get(include, "id") == "4"
           end)

    assert Enum.find(included, fn include ->
             Map.get(include, "type") == "tag" && Map.get(include, "id") == "3"
           end)

    assert Enum.find(included, fn include ->
             Map.get(include, "type") == "tag" && Map.get(include, "id") == "4"
           end)

    assert Map.has_key?(json, "links")
  end
end
