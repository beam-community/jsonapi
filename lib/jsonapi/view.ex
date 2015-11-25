defmodule JSONAPI.View do
  @moduledoc """
  A View is simply a module that define certain callbacks to configure proper rendering of your JSONAPI
  documents. 

      defmodule MyView do
        use JSONAPI.View

        def fields(), do: [:id, :text, :body]
        def type(), do: "mytype"
        def includes(), do: [author: JSONAPI.QueryParserTest.UserView, comments: JSONAPI.QueryParserTest.CommentView]
      end

      defmodule UserView do
        use JSONAPI.View

        def fields(), do: [:id, :username]
        def type(), do: "user"
        def includes(), do: []
      end

      defmodule CommentView do
        use JSONAPI.View

        def fields(), do: [:id, :text]
        def type(), do: "comment"
        def includes(), do: [user: JSONAPI.QueryParserTest.UserView]
      end

  is an example of a basic view. You can now call `UserView.show(user, conn, params)` and it will 
  render a valid jsonapi doc. 

  ## Relationships
  Currently the relationships callback expects that a map is returned configuring the information
  you will need. If you have the following Ecto Model setup

      defmodule User do
        schema "users" do
          field :username
          has_many :posts
          has_one :image
        end
      end

  and the relationships map from above it will always encode an image relationship or leave it as nil
  and it will only encode a posts relationship if it is loaded. Support for the query parameter 
  `includes` is on the todo list. 
  """
  defmacro __using__(_opts) do
    quote do
      import JSONAPI.Serializer, only: [serialize: 3]

      def id(data), do: Map.get(data, :id) |> to_string()

      #TODO Figure out the nesting of fields
      def attributes(data, conn) do
        Map.take(data, fields)
      end

      def includes(), do: []
      def fields(), do: raise "Need to implement fields/0"
      def type(), do: raise "Need to implement type/0"

      def show(model, conn, _params), do: serialize(__MODULE__, model, conn)
      def index(models, conn, _p), do: serialize(__MODULE__, models, conn)

      def url_for(data, nil) when is_list(data) do
        "/#{type()}"
      end

      def url_for(data, nil) do
        "/#{type()}/#{id(data)}"
      end

      def url_for(data, %Plug.Conn{}=conn) when is_list(data) do
        "#{Atom.to_string(conn.scheme)}://#{conn.host}/#{type()}"
      end

      def url_for(data, %Plug.Conn{}=conn) do
        "#{Atom.to_string(conn.scheme)}://#{conn.host}/#{type()}/#{id(data)}"
      end

      def url_for_rel(data, rel_type, conn) do
        "#{url_for(data, conn)}/relationships/#{rel_type}"
      end

      defoverridable [attributes: 2, includes: 0, id: 1, type: 0, fields: 0, url_for: 2, url_for_rel: 3]
    end
  end
end
