defmodule JSONAPI.UnderscoreParameters do
  @moduledoc """
  Takes dasherized JSON:API params and turns them into underscored params. Add
  this to your API's pipeline to aid in dealing with incoming parameters.

  ## Example

  Given a request like:

      GET /example?filters[dog-breed]=Corgi

  You could implement your corresponding `index` method like:

      def index(conn, %{"filters" => %{"dog_breed" => "Corgi"}})

  Without this Plug your index action would look like:

      def index(conn, %{"filters" => %{"dog-breed" => "Corgi"}})
  """

  import Plug.Conn

  import JSONAPI.Utils.Underscore, only: [dash: 1]

  @doc false
  def init(_opts) do
  end

  @doc false
  def call(%Plug.Conn{params: params} = conn, _opts) do
    content_type = get_req_header(conn, "content-type")

    if JSONAPI.mime_type() in content_type do
      new_params = dash(params)

      Map.put(conn, :params, new_params)
    else
      conn
    end
  end
end
