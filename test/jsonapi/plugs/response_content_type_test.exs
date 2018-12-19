defmodule JSONAPI.ResponseContentTypeTest do
  use ExUnit.Case
  use Plug.Test

  alias JSONAPI.ResponseContentType

  test "sets response content type" do
    conn =
      :get
      |> conn("/example", "")
      |> ResponseContentType.call([])
      |> send_resp(200, "done")

    assert get_resp_header(conn, "content-type") == ["application/vnd.api+json; charset=utf-8"]
  end

  test "can be overridden when in play" do
    conn =
      :get
      |> conn("/example", "")
      |> Plug.Conn.assign(:override_jsonapi, true)
      |> ResponseContentType.call([])
      |> send_resp(200, "done")

    refute get_resp_header(conn, "content-type") == ["application/vnd.api+json; charset=utf-8"]
  end
end
