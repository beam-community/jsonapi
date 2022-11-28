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
      |> List.first()

    {conn, content_type, accepts}
  end

  defp content_type(conn) do
    content_type =
      conn
      |> get_req_header("content-type")
      |> List.first()

    {conn, content_type}
  end

  defp respond({conn, content_type, accepts}) do
    cond do
      validate_header(content_type) and validate_header(accepts) == true ->
        add_header_to_resp(conn)

      validate_header(content_type) == false ->
        send_error(conn, incorrect_content_type())

      validate_header(accepts) == false ->
        send_error(conn, 406)
    end
  end

  defp validate_header(string) when is_binary(string) do
    string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.member?(JSONAPI.mime_type())
  end

  defp validate_header(nil), do: true

  defp add_header_to_resp(conn) do
    register_before_send(conn, fn conn ->
      update_resp_header(
        conn,
        "content-type",
        JSONAPI.mime_type(),
        & &1
      )
    end)

    conn
  end
end
