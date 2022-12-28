defmodule JSONAPI.ContentTypeNegotiationTest do
  use ExUnit.Case
  use Plug.Test

  alias JSONAPI.ContentTypeNegotiation

  import JSONAPI, only: [mime_type: 0]

  test "passes request through" do
    conn =
      :post
      |> conn("/example", "")
      |> Plug.Conn.put_req_header("content-type", mime_type())
      |> Plug.Conn.put_req_header("accept", mime_type())
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "halts and returns an error if no content-type or accept header" do
    conn =
      :post
      |> conn("/example", "")
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "passes request through if only content-type header" do
    conn =
      :post
      |> conn("/example", "")
      |> Plug.Conn.put_req_header("content-type", mime_type())
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "passes request through if only accept header" do
    conn =
      :post
      |> conn("/example", "")
      |> Plug.Conn.put_req_header("accept", mime_type())
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "passes request through if multiple accept header" do
    conn =
      :post
      |> conn("/example", "")
      |> Plug.Conn.put_req_header(
        "accept",
        "#{mime_type()}, #{mime_type()}; version=1.0"
      )
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "passes request through if correct content-type header is last" do
    conn =
      :post
      |> conn("/example", "")
      |> Plug.Conn.put_req_header(
        "content-type",
        "#{mime_type()}, #{mime_type()}; version=1.0"
      )
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "passes request through if correct accept header is last" do
    conn =
      :post
      |> conn("/example", "")
      |> Plug.Conn.put_req_header(
        "accept",
        "#{mime_type()}, #{mime_type()}; version=1.0"
      )
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "halts and returns an error if content-type header contains other media type" do
    conn =
      :post
      |> conn("/example", "")
      |> Plug.Conn.put_req_header("content-type", "text/html")
      |> ContentTypeNegotiation.call([])

    assert conn.halted
    assert 415 == conn.status

    assert conn.resp_body =~
             ~s|The content-type header must use the media type 'application/vnd.api+json'|
  end

  test "halts and returns an error if content-type header contains other media type params" do
    conn =
      :post
      |> conn("/example", "")
      |> Plug.Conn.put_req_header("content-type", "#{mime_type()}; version=1.0")
      |> ContentTypeNegotiation.call([])

    assert conn.halted
    assert 415 == conn.status
  end

  test "halts and returns an error if content-type header contains other media type params (multiple)" do
    conn =
      :post
      |> conn("/example", "")
      |> Plug.Conn.put_req_header(
        "content-type",
        "#{mime_type()}; version=1.0, #{mime_type()}; version=1.0"
      )
      |> ContentTypeNegotiation.call([])

    assert conn.halted
    assert 415 == conn.status
  end

  test "halts and returns an error if content-type header contains other media type params with correct accept header" do
    conn =
      :post
      |> conn("/example", "")
      |> Plug.Conn.put_req_header("content-type", "#{mime_type()}; version=1.0")
      |> Plug.Conn.put_req_header("accept", "#{mime_type()}")
      |> ContentTypeNegotiation.call([])

    assert conn.halted
    assert 415 == conn.status
  end

  test "halts and returns an error if accept header contains other media type params" do
    conn =
      :post
      |> conn("/example", "")
      |> Plug.Conn.put_req_header("content-type", mime_type())
      |> Plug.Conn.put_req_header("accept", "#{mime_type()} charset=utf-8")
      |> ContentTypeNegotiation.call([])

    assert conn.halted
    assert 406 == conn.status
  end

  test "halts and returns an error if all accept header media types contain media type params with no content-type" do
    conn =
      :post
      |> conn("/example", "")
      |> Plug.Conn.put_req_header(
        "accept",
        "#{mime_type()}; version=1.0, #{mime_type()}; version=1.0"
      )
      |> ContentTypeNegotiation.call([])

    assert conn.halted
    assert 406 == conn.status
  end

  test "halts and returns an error if all accept header media types contain media type params" do
    conn =
      :post
      |> conn("/example", "")
      |> Plug.Conn.put_req_header("content-type", mime_type())
      |> Plug.Conn.put_req_header(
        "accept",
        "#{mime_type()}; version=1.0, #{mime_type()}; version=1.0"
      )
      |> ContentTypeNegotiation.call([])

    assert conn.halted
    assert 406 == conn.status
  end

  test "returned error has correct content type" do
    conn =
      :post
      |> conn("/example", "")
      |> Plug.Conn.put_req_header(
        "accept",
        "#{mime_type()}; version=1.0, #{mime_type()}; version=1.0"
      )
      |> ContentTypeNegotiation.call([])

    assert conn.halted

    assert Plug.Conn.get_resp_header(conn, "content-type") == [
             "#{mime_type()}; charset=utf-8"
           ]
  end
end
