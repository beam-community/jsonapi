defmodule JSONAPI.Deserializer do
  @moduledoc """
  Based on - https://github.com/vt-elixir/ja_serializer/blob/20ff32279cab00e81eba0d035951c470fdfbf82d/lib/ja_serializer/param_parser.ex

  This plug "deserializes" params for ease of use when casting to changesets.
  As a result, you are able to pattern match specific attributes in your controller
  actions.

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
  """

  alias JSONAPI.Utils.DataToAttributes

  @spec init(Keyword.t) :: Keyword.t
  def init(opts), do: opts

  @spec call(Conn.t, Keyword.t) :: Plug.Conn.t
  def call(conn, _opts) do
    Map.put(conn, :params, DataToAttributes.parse_data(conn.params))
  end
end
