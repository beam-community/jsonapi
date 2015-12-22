defmodule JSONAPISerializerTest do
  use ExUnit.Case
  alias JSONAPI.Serializer

  defmodule PostView do
    use JSONAPI.View

    def fields(), do: [:text, :body]
    def type(), do: "mytype"
    def relationships(), do: [author: {JSONAPISerializerTest.UserView, :include}, comments: {JSONAPISerializerTest.CommentView, :include}]
  end

  defmodule UserView do
    use JSONAPI.View

    def fields(), do: [:username]
    def type(), do: "user"
    def relationships(), do: []
  end

  defmodule CommentView do
    use JSONAPI.View

    def fields(), do: [:text]
    def type(), do: "comment"
    def relationships(), do: [user: {JSONAPISerializerTest.UserView, :include}]
  end

  test "serialize handles singular objects" do
    data = %{
      id: 1,
      text: "Hello", 
      body: "Hello world",
      author: %{ id: 2, username: "jason"},
      comments: [
        %{ id: 5, text: "greatest comment ever", user: %{id: 4, username: "jack"}},
        %{ id: 6, text: "not so great", user: %{id: 2, username: "jason"}}
      ]
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

    assert Enum.count(encoded[:included]) == 4
  end

  test "serialize handles a list " do
    data = %{
      id: 1,
      text: "Hello", 
      body: "Hello world",
      author: %{ id: 2, username: "jason"},
      comments: [
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
end
