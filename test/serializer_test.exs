defmodule JSONAPISerializerTest do
  use ExUnit.Case, async: false
  alias JSONAPI.Serializer

  defmodule PostView do
    use JSONAPI.View

    def fields, do: [:text, :body, :full_description]
    def meta(data, _conn), do: %{meta_text: "meta_#{data[:text]}"}
    def type, do: "mytype"
    def relationships do
      [author: {JSONAPISerializerTest.UserView, :include},
       best_comments: {JSONAPISerializerTest.CommentView, :include}
      ]
    end
  end

  defmodule UserView do
    use JSONAPI.View

    def fields, do: [:username, :first_name, :last_name]
    def type, do: "user"
    def relationships, do: []
  end

  defmodule CommentView do
    use JSONAPI.View

    def fields, do: [:text]
    def type, do: "comment"
    def relationships do
      [user: {JSONAPISerializerTest.UserView, :include}]
    end
  end

  defmodule NotIncludedView do
    use JSONAPI.View

    def fields, do: [:foo]
    def type, do: "not-included"
    def relationships do
      [author: JSONAPISerializerTest.UserView,
       best_comments: JSONAPISerializerTest.CommentView
      ]
    end
  end

  test "serialize only includes meta if provided" do
    encoded = Serializer.serialize(PostView, %{id: 1, text: "Hello"}, nil)
    assert %{meta_text: "meta_Hello"} = encoded[:data][:meta]

    encoded = Serializer.serialize(CommentView, %{id: 1}, nil)
    refute Map.has_key?(encoded[:data], :meta)
  end

  test "serialize handles singular objects" do
    data = %{
      id: 1,
      text: "Hello",
      body: "Hello world",
      author: %{ id: 2, username: "jason"},
      best_comments: [
        %{ id: 5, text: "greatest comment ever", user: %{id: 4, username: "jack"}},
        %{ id: 6, text: "not so great", user: %{id: 2, username: "jason"}}
      ]
    }

    encoded = Serializer.serialize(PostView, data, nil)
    encoded_data = encoded[:data]
    assert encoded_data[:id] == PostView.id(data)
    assert encoded_data[:type] == PostView.type()

    assert %{meta_text: "meta_Hello"} = encoded_data[:meta]

    attributes = encoded_data[:attributes]
    assert attributes[:text] == data[:text]
    assert attributes[:body] == data[:body]

    assert encoded_data[:links][:self] == PostView.url_for(data, nil)
    assert map_size(encoded_data[:relationships]) == 2

    assert Enum.count(encoded[:included]) == 4
  end

  test "serialize handles a list" do
    data = %{
      id: 1,
      text: "Hello",
      body: "Hello world",
      author: %{ id: 2, username: "jason"},
      best_comments: [
        %{ id: 5, text: "greatest comment ever", user: %{id: 4, username: "jack"}},
        %{ id: 6, text: "not so great", user: %{id: 2, username: "jason"}}
      ]
    }
    data_list = [data, data, data]

    encoded = Serializer.serialize(PostView, data_list, nil)

    assert Enum.count(encoded[:data]) == 3
    Enum.each(encoded[:data], fn(enc) ->
      assert enc[:id] == PostView.id(data)
      assert enc[:type] == PostView.type()

      attributes = enc[:attributes]
      assert attributes[:text] == data[:text]
      assert attributes[:body] == data[:body]

      assert enc[:links][:self] == PostView.url_for(data, nil)
      assert map_size(enc[:relationships]) == 2
    end)
    assert Enum.count(encoded[:included]) == 4
  end

  test "serialize handles an empty relationship" do
    data = %{
      id: 1,
      text: "Hello",
      body: "Hello world",
      author: %{ id: 2, username: "jason"},
      best_comments: []
    }

    encoded = Serializer.serialize(PostView, data, nil)

    encoded_data = encoded[:data]
    assert encoded_data[:id] == PostView.id(data)
    assert encoded_data[:type] == PostView.type()

    attributes = encoded_data[:attributes]
    assert attributes[:text] == data[:text]
    assert attributes[:body] == data[:body]

    assert encoded_data[:links][:self] == PostView.url_for(data, nil)
    assert map_size(encoded_data[:relationships]) == 2

    assert Enum.count(encoded[:included]) == 1
  end

  test "serialize handles a nil relationship" do
    data = %{
      id: 1,
      text: "Hello",
      body: "Hello world",
      author: %{ id: 2, username: "jason"},
      best_comments: nil
    }

    encoded = Serializer.serialize(PostView, data, nil)

    encoded_data = encoded[:data]
    assert encoded_data[:id] == PostView.id(data)
    assert encoded_data[:type] == PostView.type()

    attributes = encoded_data[:attributes]
    assert attributes[:text] == data[:text]
    assert attributes[:body] == data[:body]

    assert encoded_data[:links][:self] == PostView.url_for(data, nil)
    assert map_size(encoded_data[:relationships]) == 2

    assert Enum.count(encoded[:included]) == 1
  end

  test "serialize handles a relationship self link" do
    data = %{
      id: 1,
      text: "Hello",
      body: "Hello world",
      author: %{ id: 2, username: "jason"},
      best_comments: []
    }

    encoded = Serializer.serialize(PostView, data, nil)

    encoded_data = encoded[:data]
    assert encoded_data[:relationships][:author][:links][:self] == "/mytype/1/relationships/author"
  end

  test "serialize handles including from the query" do
    data = %{
      id: 1,
      text: "Hello",
      body: "Hello world",
      author: %{ id: 2, username: "jason"},
      best_comments: [
        %{id: 5, text: "greatest comment ever", user: %{id: 4, username: "jack"}},
        %{id: 6, text: "not so great", user: %{id: 2, username: "jason"}}
      ]
    }

    conn = %Plug.Conn{
      assigns: %{
        jsonapi_query: %{
          includes: [best_comments: :user]
        }
      }
    }

    encoded = Serializer.serialize(PostView, data, conn)

    assert encoded.data.relationships.author.links.self == "http://www.example.com/mytype/1/relationships/author"
    assert Enum.count(encoded.included) == 4
  end

  test "serialize properly uses underscore_to_dash on both attributes and relationships" do
    data = %{
      id: 1,
      text: "Hello",
      body: "Hello world",
      full_description: "This_is_my_description",
      author: %{ id: 2, username: "jbonds", first_name: "jerry", last_name: "bonds"},
      best_comments: [
        %{id: 5, text: "greatest comment ever", user: %{id: 4, username: "jack", last_name: "bronds"}},
      ]
    }

    Application.put_env(:jsonapi, :underscore_to_dash, true)

    encoded = Serializer.serialize(PostView, data, nil)

    attributes = encoded[:data][:attributes]
    relationships = encoded[:data][:relationships]
    included = encoded[:included]

    assert attributes["full-description"] == data[:full_description]
    assert Enum.find(included, fn(i) -> i[:type] == "user" && i[:id] == "2" end)[:attributes]["last-name"] == "bonds"
    assert Enum.find(included, fn(i) -> i[:type] == "user" && i[:id] == "4" end)[:attributes]["last-name"] == "bronds"
    assert List.first(relationships["best-comments"][:data])[:id] == "5"

    Application.delete_env(:jsonapi, :underscore_to_dash)
  end

  test "serialize does not merge `included` if not configured" do
    data = %{
      id: 1,
      foo: "Hello",
      author: %{ id: 2, username: "jbonds", first_name: "jerry", last_name: "bonds"}
    }

    encoded = Serializer.serialize(NotIncludedView, data, nil)

    included = encoded[:included]

    assert included == []
  end

  test "serialize does not include links if remove_links is configured" do
    data = %{
      id: 1,
      text: "Hello",
      body: "Hello world",
      full_description: "This_is_my_description",
      author: %{ id: 2, username: "jbonds", first_name: "jerry", last_name: "bonds"},
      best_comments: [
        %{id: 5, text: "greatest comment ever", user: %{id: 4, username: "jack", last_name: "bronds"}},
      ]
    }

    Application.put_env(:jsonapi, :remove_links, true)

    encoded = Serializer.serialize(PostView, data, nil)

    relationships = encoded[:data][:relationships]

    refute relationships[:links]
    refute encoded[:data][:links]

    Application.delete_env(:jsonapi, :remove_links)
  end
end
