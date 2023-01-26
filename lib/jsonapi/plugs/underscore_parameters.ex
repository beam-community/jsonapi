defmodule JSONAPI.UnderscoreParameters do
  @moduledoc """
  Takes dasherized JSON:API params and converts them to underscored params. Add
  this to your API's pipeline to aid in dealing with incoming parameters such as query
  params or data.

  By default the newly underscored params will only replace the existing `params` field
  of the `Plug.Conn` struct, but leave the `query_params` and `body_params` untouched.
  If you are using the `JSONAPI.QueryParser` and need to also have the `query_params` on
  the `Plug.Conn` updated, set the `replace_query_params` option to `true`.

  Note that this Plug will only underscore parameters when the request's content
  type is for a JSON:API request (i.e. "application/vnd.api+json"). All other
  content types will be ignored.

  ## Options

    * `:replace_query_params` - When `true`, it will replace the `query_params` field in
    the `Plug.Conn` struct.  This is useful when you have downstream code which is
    expecting underscored fields in `query_params`, and not just in `params`. Defaults
    to `false`.

  ## Example

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

  Moreover, with a GET request like:

      GET /example?filters[dog-breed]=Corgi

  **Without** this Plug your index action would look like:

      def index(conn, %{"filters" => %{"dog-breed" => "Corgi"}})

  And **with** this Plug:

      def index(conn, %{"filters" => %{"dog_breed" => "Corgi"}})

  Your API's pipeline might look something like this:

      # e.g. a Phoenix app

      pipeline :api do
        plug JSONAPI.EnforceSpec
        plug JSONAPI.UnderscoreParameters
      end
  """

  import Plug.Conn

  alias JSONAPI.Utils.String, as: JString

  @doc false
  def init(opts) do
    opt = Keyword.fetch(opts, :replace_query_params)

    if match?({:ok, b} when not is_boolean(b), opt) do
      raise ArgumentError,
        message: """
        The :replace_query_params option must be a boolean.  Example:

        pipeline :api do
          plug JSONAPI.UnderscoreParameters, replace_query_params: true
        end
        """
    else
      opts
    end
  end

  @doc false
  def call(%Plug.Conn{params: params} = conn, opts) do
    content_type = get_req_header(conn, "content-type")

    if JSONAPI.mime_type() in content_type do
      # In version 2.0, when this block is no longer conditional and applies every time, ensure
      # that we apply the same treatment to the query_params and "regular" params.
      conn =
        if opts[:replace_query_params] do
          query_params = fetch_query_params(conn).query_params
          new_query_params = replace_query_params(query_params)
          Map.put(conn, :query_params, new_query_params)
        else
          conn
        end

      new_params = JString.expand_fields(params, &JString.underscore/1)
      Map.put(conn, :params, new_params)
    else
      conn
    end
  end

  defp replace_query_params(query_params) do
    # Underscore the keys of all of the query parameters
    underscored_query_params = JString.expand_fields(query_params, &JString.underscore/1)

    # If the fields[...] query parameter is present, only underscore its values, but not its keys
    case Map.fetch(query_params, "fields") do
      {:ok, fields} when is_map(fields) ->
        fields = Map.new(fields, fn {k, v} -> {k, JString.underscore(v)} end)
        Map.put(underscored_query_params, "fields", fields)

      _else ->
        underscored_query_params
    end
  end
end
