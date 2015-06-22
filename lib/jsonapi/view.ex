defmodule JSONAPI.View do
  @moduledoc """
  A View is simply a module that define certain callbacks to configure proper rendering of your JSONAPI
  documents. 

      defmodule UserView do
        use JSONAPI.View
        def url_func() do
          &App.Helpers.user_url/3
        end

        def type, do: "user"

        def attributes(model) do
          Map.take(model, [:username, :created_at,])
        end

        def relationships() do
          %{
            image: %{
              view: ImageView
            },
            posts: %{
              view: PostView
              optional: true
            }
          }
        end
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
      import JSONAPI, only: [show: 4, index: 4]
      def url_func(), do: fn(_a, _b, _c) -> raise "url_func/0 needs to be defined" end

      def id(data), do: data.id |> to_string()
      def attributes(data), do: raise "Need to implement attributes/1"
      def relationships(), do: %{}
      def type(), do: raise "Need to implement type/0"

      def show(model, conn, params), do: show(__MODULE__, model, conn, params)
      def index(models, conn, params), do: index(__MODULE__, models, conn, params)

      defoverridable [url_func: 0, attributes: 1,  relationships: 0, id: 1, type: 0]
    end
  end
end
