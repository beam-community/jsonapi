defmodule JSONAPI.UnderscoreParameters do
  @moduledoc """
  Takes dasherized JSON:API params and turns them into underscored params. Add
  this to your API's pipeline to aid in dealing with incoming parameters.

  Note that this Plug will only underscore parameters when the request's content
  type is for a JSON:API request (i.e. "application/vnd.api+json"). All other
  content types will be ignored.

  ## Example

  Given a request like:

      GET /example?filters[dog-breed]=Corgi

  **Without** this Plug your index action would look like:

      def index(conn, %{"filters" => %{"dog-breed" => "Corgi"}})

  And **with** this Plug:

      def index(conn, %{"filters" => %{"dog_breed" => "Corgi"}})

  Your API's pipeline might look something like this:

      # e.g. a Phoenix app

      pipeline :api do
        plug(JSONAPI.EnforceSpec)
        plug(JSONAPI.UnderscoreParameters)
      end
  """

  import Plug.Conn

  alias JSONAPI.Utils.String, as: JString

  @doc false
  def init(_opts) do
  end

  @doc false
  def call(%Plug.Conn{params: params} = conn, _opts) do
    content_type = get_req_header(conn, "content-type")

    if JSONAPI.mime_type() in content_type do
      new_params = JString.expand_fields(params, &JString.underscore/1)

      Map.put(conn, :params, new_params)
    else
      conn
    end
  end
end
