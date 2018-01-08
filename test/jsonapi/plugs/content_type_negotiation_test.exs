defmodule JSONAPI.ContentTypeNegotiationTest do
  use ExUnit.Case
  use Plug.Test

  alias JSONAPI.ContentTypeNegotiation

  test "halts and returns an error if content-type header is incorrect" do
    conn =
      :post
      |> conn("/example", "")
      |> ContentTypeNegotiation.call([])

    assert conn.halted
    assert 415 == conn.status
  end

  test "halts and returns an error if content-type header contains other media type params" do
    conn =
      :post
      |> conn("/example", "application/vnd.api+json; charset=utf-8")
      |> ContentTypeNegotiation.call([])

    assert conn.halted
    assert 415 == conn.status
  end

  test "halts and returns an error if accept header contains other media type params" do
    conn =
      :post
      |> conn("/example", "")
      |> Plug.Conn.put_req_header("content-type", "application/vnd.api+json")
      |> Plug.Conn.put_req_header("accept", "application/vnd.api+json; charset=utf-8")
      |> ContentTypeNegotiation.call([])

    assert conn.halted
    assert 406 == conn.status
  end


  test "passes request through if no accept header" do
    conn =
      :post
      |> conn("/example", "")
      |> Plug.Conn.put_req_header("content-type", "application/vnd.api+json")
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end

  test "passes request through" do
    conn =
      :post
      |> conn("/example", "")
      |> Plug.Conn.put_req_header("content-type", "application/vnd.api+json")
      |> Plug.Conn.put_req_header("accept", "application/vnd.api+json")
      |> ContentTypeNegotiation.call([])

    refute conn.halted
  end
end
