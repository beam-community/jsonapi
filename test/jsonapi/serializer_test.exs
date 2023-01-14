defmodule JSONAPI.SerializerTest do
  use ExUnit.Case, async: false

  alias JSONAPI.{Config, QueryParser, Serializer}

  defmodule PostView do
    use JSONAPI.View

    def fields, do: [:text, :body, :full_description, :inserted_at]
    def meta(data, _conn), do: %{meta_text: "meta_#{data[:text]}"}
    def type, do: "mytype"

    def relationships do
      [
        author: {JSONAPI.SerializerTest.UserView, :include},
        best_comments: {JSONAPI.SerializerTest.CommentView, :include}
      ]
    end
  end

  defmodule PageBasedPaginator do
    @moduledoc """
    Page based pagination strategy
    """

    @behaviour JSONAPI.Paginator

    @impl true
    def paginate(data, view, conn, page, options) do
      number =
        page
        |> Map.get("page", "0")
        |> String.to_integer()

      size =
        page
        |> Map.get("size", "0")
        |> String.to_integer()

      total_pages =
        options
        |> Keyword.get(:total_pages, 0)

      %{
        first: view.url_for_pagination(data, conn, %{page | "page" => "1"}),
        last: view.url_for_pagination(data, conn, %{page | "page" => total_pages}),
        next: next_link(data, view, conn, number, size, total_pages),
        prev: previous_link(data, view, conn, number, size),
        self: view.url_for_pagination(data, conn, %{size: size, page: number})
      }
    end

    defp next_link(data, view, conn, page, size, total_pages)
         when page < total_pages,
         do: view.url_for_pagination(data, conn, %{size: size, page: page + 1})

    defp next_link(_data, _view, _conn, _page, _size, _total_pages),
      do: nil

    defp previous_link(data, view, conn, page, size)
         when page > 1,
         do: view.url_for_pagination(data, conn, %{size: size, page: page - 1})

    defp previous_link(_data, _view, _conn, _page, _size),
      do: nil
  end

  defmodule PaginatedPostView do
    use JSONAPI.View, paginator: PageBasedPaginator

    def fields, do: [:text, :body, :full_description, :inserted_at]
    def type, do: "mytype"
  end

  defmodule UserView do
    use JSONAPI.View

    def fields, do: [:username, :first_name, :last_name]
    def type, do: "user"

    def relationships do
      [company: JSONAPI.SerializerTest.CompanyView]
    end
  end

  defmodule CompanyView do
    use JSONAPI.View

    def fields, do: [:name]
    def type, do: "company"

    def relationships do
      [industry: JSONAPI.SerializerTest.IndustryView]
    end
  end

  defmodule IndustryView do
    use JSONAPI.View

    def fields, do: [:name]
    def type, do: "industry"

    def relationships do
      [tags: JSONAPI.SerializerTest.TagView]
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
      [user: {JSONAPI.SerializerTest.UserView, :include}]
    end
  end

  defmodule CommentaryView do
    use JSONAPI.View, type: "comment"

    def fields, do: [:text]

    def relationships do
      # renames "user1" data property to "commenter" JSON:API relationship (and specifies default inclusion)
      # renames "user2" to "witness"
      # leaves "user3" name alone
      [
        commenter: {:user1, JSONAPI.SerializerTest.UserView, :include},
        witness: {:user2, JSONAPI.SerializerTest.UserView},
        user3: JSONAPI.SerializerTest.UserView
      ]
    end
  end

  defmodule NotIncludedView do
    use JSONAPI.View

    def fields, do: [:foo]
    def type, do: "not-included"

    def relationships do
      [author: JSONAPI.SerializerTest.UserView, best_comments: JSONAPI.SerializerTest.CommentView]
    end
  end

  defmodule ExpensiveResourceView do
    use JSONAPI.View

    def fields, do: [:name]

    def type, do: "expensive-resource"

    def links(nil, _conn), do: %{}

    def links(data, _conn) do
      %{
        queue: "/expensive-resource/queue/#{data.id}",
        promotions: %{
          href: "/promotions?rel=#{data.id}",
          meta: %{
            title: "Stuff you might be interested in"
          }
        }
      }
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

    conn = Plug.Conn.fetch_query_params(%Plug.Conn{})

    encoded = Serializer.serialize(PostView, data_list, conn)

    assert Enum.count(encoded[:data]) == 3

    Enum.each(encoded[:data], fn enc ->
      assert enc[:id] == PostView.id(data)
      assert enc[:type] == PostView.type()

      attributes = enc[:attributes]
      assert attributes[:text] == data[:text]
      assert attributes[:body] == data[:body]

      assert enc[:links][:self] == PostView.url_for(data, conn)
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
    encoded = Serializer.serialize(PostView, [], Plug.Conn.fetch_query_params(%Plug.Conn{}))

    assert encoded[:links][:self] == "http://www.example.com/mytype"
  end

  test "serialize will rename relationships" do
    data = %{
      id: 1,
      text: "hello world",
      user1: %{
        id: 2,
        username: "hi",
        first_name: "hello",
        last_name: "world"
      },
      user2: %{
        id: 3,
        username: "hi",
        first_name: "hello",
        last_name: "world"
      },
      user3: %{
        id: 4,
        username: "hi",
        first_name: "hello",
        last_name: "world"
      }
    }

    conn =
      %Plug.Conn{
        assigns: %{
          jsonapi_query: %Config{}
        }
      }
      |> Plug.Conn.fetch_query_params()

    encoded = Serializer.serialize(CommentaryView, data, conn)

    assert encoded.data.relationships.commenter != nil
    assert encoded.data.relationships.witness != nil
    assert encoded.data.relationships.user3 != nil
    refute Map.has_key?(encoded.data.relationships, :user1)
    refute Map.has_key?(encoded.data.relationships, :user2)

    assert Enum.count(encoded.included) == 1
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

    conn =
      %Plug.Conn{
        assigns: %{
          jsonapi_query: %Config{
            include: [best_comments: :user]
          }
        }
      }
      |> Plug.Conn.fetch_query_params()

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

    conn =
      %Plug.Conn{
        assigns: %{
          jsonapi_query: %Config{
            include: [:company]
          }
        }
      }
      |> Plug.Conn.fetch_query_params()

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

    conn =
      %Plug.Conn{
        assigns: %{
          jsonapi_query: %Config{
            include: [company: :industry]
          }
        }
      }
      |> Plug.Conn.fetch_query_params()

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

    conn =
      %Plug.Conn{
        assigns: %{
          jsonapi_query: %Config{
            include: [company: [industry: :tags]]
          }
        }
      }
      |> Plug.Conn.fetch_query_params()

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

  test "serialize includes pagination links if page-based pagination is requested" do
    data = [%{id: 1}]
    view = PaginatedPostView

    conn =
      :get
      |> Plug.Test.conn("/mytype?page[page]=2&page[size]=1")
      |> QueryParser.call(%Config{view: view, opts: []})
      |> Plug.Conn.fetch_query_params()

    encoded =
      Serializer.serialize(PaginatedPostView, data, conn, nil, total_pages: 3, total_items: 3)

    page = conn.assigns.jsonapi_query.page
    first = view.url_for_pagination(data, conn, %{page | "page" => 1})
    last = view.url_for_pagination(data, conn, %{page | "page" => 3})
    self = view.url_for_pagination(data, conn, page)

    assert encoded[:links][:first] == first
    assert encoded[:links][:last] == last
    assert encoded[:links][:next] == last
    assert encoded[:links][:prev] == first
    assert encoded[:links][:self] == self
  end

  test "serialize does not include pagination links if they are not defined" do
    data = [%{id: 1}]

    encoded = Serializer.serialize(UserView, data, Plug.Conn.fetch_query_params(%Plug.Conn{}))
    refute encoded[:links][:first]
    refute encoded[:links][:last]
    refute encoded[:links][:next]
    refute encoded[:links][:prev]
  end

  test "serialize can include arbitrary, user-defined, links" do
    data = %{id: 1}

    assert %{
             links: links
           } = Serializer.serialize(ExpensiveResourceView, data, nil)

    expected_links = %{
      self: "/expensive-resource/#{data.id}",
      queue: "/expensive-resource/queue/#{data.id}",
      promotions: %{
        href: "/promotions?rel=#{data.id}",
        meta: %{
          title: "Stuff you might be interested in"
        }
      }
    }

    assert expected_links == links
  end

  test "serialize returns a null data if it receives a null data" do
    assert %{
             data: data,
             links: links
           } = Serializer.serialize(ExpensiveResourceView, nil, nil)

    assert nil == data
    assert %{self: "/expensive-resource"} == links
  end

  test "serialize handles query parameters in self links" do
    data = [%{id: 1}]
    view = PaginatedPostView

    conn =
      :get
      |> Plug.Test.conn("/mytype?page[page]=2&page[size]=1")
      |> QueryParser.call(%Config{view: view, opts: []})
      |> Plug.Conn.fetch_query_params()

    encoded =
      Serializer.serialize(PaginatedPostView, data, conn, nil, total_pages: 3, total_items: 3)

    assert encoded[:links][:self] ==
             "http://www.example.com/mytype?page%5Bpage%5D=2&page%5Bsize%5D=1"

    assert List.first(encoded[:data])[:links][:self] ==
             "http://www.example.com/mytype/1"
  end

  test "extrapolates relationship config simplest case" do
    config =
      IndustryView.relationships()
      |> List.first()
      |> Serializer.extrapolate_relationship_config()

    assert config == {:tags, :tags, JSONAPI.SerializerTest.TagView, false}
  end

  test "extrapolates relationship config with default include" do
    configs =
      PostView.relationships()
      |> Enum.map(&Serializer.extrapolate_relationship_config/1)

    assert configs == [
             {:author, :author, JSONAPI.SerializerTest.UserView, true},
             {:best_comments, :best_comments, JSONAPI.SerializerTest.CommentView, true}
           ]
  end

  test "extrapolates relationship config with rewritten name" do
    configs =
      CommentaryView.relationships()
      |> Enum.map(&Serializer.extrapolate_relationship_config/1)

    assert configs == [
             {:commenter, :user1, JSONAPI.SerializerTest.UserView, true},
             {:witness, :user2, JSONAPI.SerializerTest.UserView, false},
             {:user3, :user3, JSONAPI.SerializerTest.UserView, false}
           ]
  end
end
