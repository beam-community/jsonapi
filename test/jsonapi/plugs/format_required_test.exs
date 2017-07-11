defmodule JSONAPI.FormatRequiredTest do
  use ExUnit.Case
  use Plug.Test

  alias JSONAPI.FormatRequired

  test "halts and returns an error for missing data param" do
    conn =
      :post
      |> conn("/example", Poison.encode!(%{}))
      |> call_plug

    assert conn.halted
    assert 400 == conn.status

    %{"errors" => [error]} = Poison.decode!(conn.resp_body)

    assert %{"source" => %{"pointer" => "/data"}, "title" => "Missing data parameter"} = error
  end

  test "halts and returns an error for missing attributes in data param" do
    conn =
      :post
      |> conn("/example", Poison.encode!(%{data: %{}}))
      |> call_plug

    assert conn.halted
    assert 400 == conn.status

    %{"errors" => [error]} = Poison.decode!(conn.resp_body)

    assert %{"source" => %{"pointer" => "/data/attributes"}, "title" => "Missing attributes in data parameter"} = error
  end

  test "passes request through" do
    conn =
      :post
      |> conn("/example", Poison.encode!(%{data: %{attributes: %{}}}))
      |> call_plug

    refute conn.halted
  end

  defp call_plug(conn) do
    parser_opts = Plug.Parsers.init(parsers: [:json], pass: ["text/*"], json_decoder: Poison)

    conn
    |> Plug.Conn.put_req_header("content-type", "application/json")
    |> Plug.Parsers.call(parser_opts)
    |> FormatRequired.call([])
  end
end
