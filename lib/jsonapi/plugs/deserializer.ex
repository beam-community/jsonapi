defmodule JSONAPI.Deserializer do
  @moduledoc """
  This plug flattens incoming params for ease of use when casting to changesets.
  As a result, you are able to pattern match specific attributes in your controller
  actions.

  Note that this Plug will only deserialize your payload when the request's content
  type is for a JSON:API request (i.e. "application/vnd.api+json"). All other
  content types will be ignored.

  ## Example

  For example these params:
      %{
        "data" => %{
          "id" => "1",
          "type" => "user",
          "attributes" => %{
            "foo-bar" => true
          },
          "relationships" => %{
            "baz" => %{"data" => %{"id" => "2", "type" => "baz"}}
          }
        }
      }

  are transformed to:

      %{
        "id" => "1",
        "type" => "user"
        "foo-bar" => true,
        "baz-id" => "2"
      }

  ## Usage

  Just include in your plug stack _after_ a json parser:
      plug Plug.Parsers, parsers: [:json], json_decoder: Jason
      plug JSONAPI.Deserializer

  or a part of your Controller plug pipeline
      plug JSONAPI.Deserializer

  In addition, if you want to underscore your parameters
      plug JSONAPI.Deserializer
      plug JSONAPI.UnderscoreParameters
  """

  import Plug.Conn
  alias JSONAPI.Utils.DataToParams

  @spec init(Keyword.t) :: Keyword.t
  def init(opts), do: opts

  @spec call(Plug.Conn.t, Keyword.t) :: Plug.Conn.t
  def call(conn, _opts) do
    content_type = get_req_header(conn, "content-type")

    if JSONAPI.mime_type() in content_type do
      Map.put(conn, :params, DataToParams.process(conn.params))
    else
      conn
    end
  end
end
