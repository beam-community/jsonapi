defmodule JSONAPISerializerTest do
  use ExUnit.Case, async: false
  alias JSONAPI.Serializer

  import ExUnit.CaptureLog

  defmodule PostView do
    use JSONAPI.View

    def fields, do: [:text, :body, :full_description, :inserted_at]
    def meta(data, _conn), do: %{meta_text: "meta_#{data[:text]}"}
    def type, do: "mytype"

    def relationships do
      [
        author: {JSONAPISerializerTest.UserView, :include},
        best_comments: {JSONAPISerializerTest.CommentView, :include}
      ]
    end

    def links(data, conn) do
      %{
        next: url_for_pagination(data, conn, %{cursor: "some-string"})
      }
    end
  end

  defmodule UserView do
    use JSONAPI.View

    def fields, do: [:username, :first_name, :last_name]
    def type, do: "user"

    def relationships do
      [company: JSONAPISerializerTest.CompanyView]
    end
  end

  defmodule CompanyView do
    use JSONAPI.View

    def fields, do: [:name]
    def type, do: "company"

    def relationships do
      [industry: JSONAPISerializerTest.IndustryView]
    end
  end

  defmodule IndustryView do
    use JSONAPI.View

    def fields, do: [:name]
    def type, do: "industry"

    def relationships do
      [tags: JSONAPISerializerTest.TagView]
    end
  end

  defmodule TagView do
    use JSONAPI.View

    def fields, do: [:name]
    def type, do: "tag"
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
      [author: JSONAPISerializerTest.UserView, best_comments: JSONAPISerializerTest.CommentView]
    end
  end

  setup do
    Application.put_env(:jsonapi, :field_transformation, :underscore)

    on_exit(fn ->
      Application.delete_env(:jsonapi, :field_transformation)
    end)

    {:ok, []}
  end

  test "serialize includes meta as top level member" do
    meta = %{total_pages: 10}
    encoded = Serializer.serialize(PostView, %{id: 1, text: "Hello"}, nil, meta)
    assert %{total_pages: 10} = encoded[:meta]

    encoded = Serializer.serialize(CommentView, %{id: 1}, nil, nil)
    assert encoded[:meta] == nil
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
      author: %{id: 2, username: "jason"},
      best_comments: [
        %{id: 5, text: "greatest comment ever", user: %{id: 4, username: "jack"}},
        %{id: 6, text: "not so great", user: %{id: 2, username: "jason"}}
      ]
    }

    encoded = Serializer.serialize(PostView, data, nil)
    assert encoded[:links][:self] == PostView.url_for(data, nil)

    encoded_data = encoded[:data]
    assert encoded_data[:id] == PostView.id(data)
    assert encoded_data[:type] == PostView.type()
    assert encoded_data[:links][:self] == PostView.url_for(data, nil)

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
      author: %{id: 2, username: "jason"},
      best_comments: [
        %{id: 5, text: "greatest comment ever", user: %{id: 4, username: "jack"}},
        %{id: 6, text: "not so great", user: %{id: 2, username: "jason"}}
      ]
    }

    data_list = [data, data, data]

    encoded = Serializer.serialize(PostView, data_list, nil)

    assert Enum.count(encoded[:data]) == 3

    Enum.each(encoded[:data], fn enc ->
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
      author: %{id: 2, username: "jason"},
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
    assert encoded_data[:relationships][:best_comments][:data] == []

    assert Enum.count(encoded[:included]) == 1
  end

  test "serialize handles a nil relationship" do
    data = %{
      id: 1,
      text: "Hello",
      body: "Hello world",
      author: %{id: 2, username: "jason"},
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
    assert map_size(encoded_data[:relationships]) == 1

    assert Enum.count(encoded[:included]) == 1
  end

  test "serialize handles a relationship self link on a show request" do
    data = %{
      id: 1,
      text: "Hello",
      body: "Hello world",
      author: %{id: 2, username: "jason"},
      best_comments: []
    }

    encoded = Serializer.serialize(PostView, data, nil)

    encoded_data = encoded[:data]

    assert encoded_data[:relationships][:author][:links][:self] ==
             "/mytype/1/relationships/author"
  end

  test "serialize handles a relationship self link on an index request" do
    encoded = Serializer.serialize(PostView, [], nil)

    assert encoded[:links][:self] == "/mytype"
  end

  test "serialize handles including from the query" do
    data = %{
      id: 1,
      text: "Hello",
      body: "Hello world",
      author: %{id: 2, username: "jason"},
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

    assert encoded.data.relationships.author.links.self ==
             "http://www.example.com/mytype/1/relationships/author"

    assert Enum.count(encoded.included) == 4
  end

  test "includes from the query when not included by default" do
    data = %{
      id: 1,
      username: "jim",
      first_name: "Jimmy",
      last_name: "Beam",
      company: %{id: 2, name: "acme"}
    }

    conn = %Plug.Conn{
      assigns: %{
        jsonapi_query: %{
          includes: [:company]
        }
      }
    }

    encoded = Serializer.serialize(UserView, data, conn)

    assert encoded.data.relationships.company.links.self ==
             "http://www.example.com/user/1/relationships/company"

    assert Enum.count(encoded.included) == 1
  end

  test "includes nested items from the query when not included by default" do
    data = %{
      id: 1,
      username: "jim",
      first_name: "Jimmy",
      last_name: "Beam",
      company: %{id: 2, name: "acme", industry: %{id: 4, name: "stuff"}}
    }

    conn = %Plug.Conn{
      assigns: %{
        jsonapi_query: %{
          includes: [company: :industry]
        }
      }
    }

    encoded = Serializer.serialize(UserView, data, conn)

    assert encoded.data.relationships.company.links.self ==
             "http://www.example.com/user/1/relationships/company"

    assert Enum.count(encoded.included) == 2
  end

  test "includes items nested 2 layers deep from the query when not included by default" do
    data = %{
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

    conn = %Plug.Conn{
      assigns: %{
        jsonapi_query: %{
          includes: [company: [industry: :tags]]
        }
      }
    }

    encoded = Serializer.serialize(UserView, data, conn)

    assert encoded.data.relationships.company.links.self ==
             "http://www.example.com/user/1/relationships/company"

    assert Enum.count(encoded.included) == 4
  end

  describe "when configured to camelize fields" do
    setup do
      Application.put_env(:jsonapi, :field_transformation, :camelize)

      on_exit(fn ->
        Application.delete_env(:jsonapi, :field_transformation)
      end)

      {:ok, []}
    end

    test "serialize properly camelizes both attributes and relationships" do
      data = %{
        id: 1,
        text: "Hello",
        inserted_at: NaiveDateTime.utc_now(),
        body: "Hello world",
        full_description: "This_is_my_description",
        author: %{id: 2, username: "jbonds", first_name: "jerry", last_name: "bonds"},
        best_comments: [
          %{
            id: 5,
            text: "greatest comment ever",
            user: %{id: 4, username: "jack", last_name: "bronds"}
          }
        ]
      }

      encoded = Serializer.serialize(PostView, data, nil)

      attributes = encoded[:data][:attributes]
      relationships = encoded[:data][:relationships]
      included = encoded[:included]

      assert attributes["fullDescription"] == data[:full_description]
      assert attributes["insertedAt"] == data[:inserted_at]

      assert Enum.find(included, fn i -> i[:type] == "user" && i[:id] == "2" end)[:attributes][
               "lastName"
             ] == "bonds"

      assert Enum.find(included, fn i -> i[:type] == "user" && i[:id] == "4" end)[:attributes][
               "lastName"
             ] == "bronds"

      assert List.first(relationships["bestComments"][:data])[:id] == "5"

      assert relationships["bestComments"][:links][:self] ==
               "/mytype/1/relationships/bestComments"
    end
  end

  describe "when configured to dasherize fields" do
    setup do
      Application.put_env(:jsonapi, :field_transformation, :dasherize)

      on_exit(fn ->
        Application.delete_env(:jsonapi, :field_transformation)
      end)

      {:ok, []}
    end

    test "serialize properly dasherizes both attributes and relationships" do
      data = %{
        id: 1,
        text: "Hello",
        inserted_at: NaiveDateTime.utc_now(),
        body: "Hello world",
        full_description: "This_is_my_description",
        author: %{id: 2, username: "jbonds", first_name: "jerry", last_name: "bonds"},
        best_comments: [
          %{
            id: 5,
            text: "greatest comment ever",
            user: %{id: 4, username: "jack", last_name: "bronds"}
          }
        ]
      }

      encoded = Serializer.serialize(PostView, data, nil)

      attributes = encoded[:data][:attributes]
      relationships = encoded[:data][:relationships]
      included = encoded[:included]

      assert attributes["full-description"] == data[:full_description]
      assert attributes["inserted-at"] == data[:inserted_at]

      assert Enum.find(included, fn i -> i[:type] == "user" && i[:id] == "2" end)[:attributes][
               "last-name"
             ] == "bonds"

      assert Enum.find(included, fn i -> i[:type] == "user" && i[:id] == "4" end)[:attributes][
               "last-name"
             ] == "bronds"

      assert List.first(relationships["best-comments"][:data])[:id] == "5"

      assert relationships["best-comments"][:links][:self] ==
               "/mytype/1/relationships/best-comments"
    end
  end

  test "serialize does not merge `included` if not configured" do
    data = %{
      id: 1,
      foo: "Hello",
      author: %{id: 2, username: "jbonds", first_name: "jerry", last_name: "bonds"}
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
      author: %{id: 2, username: "jbonds", first_name: "jerry", last_name: "bonds"},
      best_comments: [
        %{
          id: 5,
          text: "greatest comment ever",
          user: %{id: 4, username: "jack", last_name: "bronds"}
        }
      ]
    }

    Application.put_env(:jsonapi, :remove_links, true)

    encoded = Serializer.serialize(PostView, data, nil)

    relationships = encoded[:data][:relationships]

    refute relationships[:links]
    refute encoded[:data][:links]
    refute encoded[:links]

    Application.delete_env(:jsonapi, :remove_links)
  end

  test "serialize includes pagination links if they are defined and with_pagination is configured" do
    data = %{id: 1}
    Application.put_env(:jsonapi, :with_pagination, true)

    encoded = Serializer.serialize(PostView, data, nil)

    assert encoded[:links][:next] ==
             PostView.url_for_pagination(data, nil, %{cursor: "some-string"})

    Application.delete_env(:jsonapi, :with_pagination)
  end

  test "serialize does not include pagination links if they are not defined even with with_pagination is configured" do
    data = %{id: 1}
    Application.put_env(:jsonapi, :with_pagination, true)

    output =
      capture_log(fn ->
        encoded = Serializer.serialize(UserView, data, nil)

        refute encoded[:links][:next]
      end)

    assert Regex.match?(~r/info.*with_pagination/, output)
    Application.delete_env(:jsonapi, :with_pagination)
  end

  test "serialize does not include pagination links if with_pagination is not configure" do
    data = %{id: 1}

    encoded = Serializer.serialize(UserView, data, nil)

    refute encoded[:links][:next]
  end
end
