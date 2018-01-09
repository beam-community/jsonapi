defmodule JSONAPI.ContentTypeNegotiation do
  @moduledoc """
  Provides content type negotiation by validating the `content-type`
  and `accept` headers.

  The proper jsonapi.org content type is
  `application/vnd.api+json`. As per [the spec](http://jsonapi.org/format/#content-negotiation-servers)

  This plug does three things:

  1. Returns 415 unless the content-type header is correct.
  2. Returns 406 unless the accept header is correct.
  3. Registers a before send hook to set the content-type if not already set.
  """

  import JSONAPI.ErrorView

  import Plug.Conn

  @jsonapi "application/vnd.api+json"

  def init(opts), do: opts

  def call(%{method: method} = conn, _opts) when method in ["DELETE", "GET", "HEAD"], do: conn
  def call(conn, _opts) do
    conn
    |> content_type
    |> accepts
    |> respond
  end

  defp accepts({conn, content_type}) do
    accepts =
      conn
      |> get_req_header("accept")
      |> Enum.flat_map(&(String.split(&1, ",")))
      |> Enum.map(&String.trim/1)
      |> List.first

    {conn, content_type, accepts}
  end

  defp content_type(conn) do
    content_type =
      conn
      |> get_req_header("content-type")
      |> List.first

    {conn, content_type}
  end

  defp respond({conn, nil, nil}), do: add_header_to_resp(conn)
  defp respond({conn, @jsonapi, nil}), do: add_header_to_resp(conn)
  defp respond({conn, nil, @jsonapi}), do: add_header_to_resp(conn)
  defp respond({conn, @jsonapi, @jsonapi}), do: add_header_to_resp(conn)
  defp respond({conn, @jsonapi, _accepts}), do: send_error(conn, 406)
  defp respond({conn, _content_type, _accepts}), do: send_error(conn, 415)

  defp add_header_to_resp(conn) do
    register_before_send(conn, fn conn -> update_resp_header(conn, "content-type", @jsonapi, &(&1)) end)

    conn
  end
end
