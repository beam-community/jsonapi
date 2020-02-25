defmodule JSONAPI.Deserializer do
  @moduledoc """
  Based on - https://github.com/vt-elixir/ja_serializer/blob/20ff32279cab00e81eba0d035951c470fdfbf82d/lib/ja_serializer/param_parser.ex

  This plug "deserializes" params to underscores.
  For example these params:
      %{
        "data" => %{
          "attributes" => %{
            "foo-bar" => true
          }
        }
      }
  are transformed to:
      %{
        "data" => %{
          "attributes" => %{
            "foo_bar" => true
          }
        }
      }

  ## Usage
  Just include in your plug stack _after_ a json parser:
      plug Plug.Parsers, parsers: [:json], json_decoder: Jason
      plug JSONAPI.Deserializer

  or a part of your Controller plug pipeline
      plug JSONAPI.Deserializer
  """

  def init(opts), do: opts

  def call(conn, _opts) do
    Map.put(conn, :params, JSONAPI.Utils.ParamParser.parse(conn.params))
  end
end

