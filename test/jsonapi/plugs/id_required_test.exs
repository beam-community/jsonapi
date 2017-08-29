defmodule JSONAPI.IdRequiredTest do
  use ExUnit.Case
  use Plug.Test

  alias JSONAPI.IdRequired

  test "halts and returns an error if id attribute is missing" do
    conn =
      :patch
      |> conn("/example/1", Poison.encode!(%{data: %{}}))
      |> call_plug

    assert conn.halted
    assert 400 == conn.status

    %{"errors" => [error]} = Poison.decode!(conn.resp_body)

    assert %{"source" => %{"pointer" => "/data/id"}, "title" => "Missing id in data parameter"} = error
  end

  test "halts and returns an error if id attribute is not a string" do
    conn =
      :patch
      |> conn("/example/1", Poison.encode!(%{data: %{id: 1}}))
      |> call_plug

    assert conn.halted
    assert 422 == conn.status

    %{"errors" => [error]} = Poison.decode!(conn.resp_body)

    assert %{"source" => %{"pointer" => "/data/id"}, "title" => "Malformed id in data parameter"} = error
  end

  test "halts and returns an error if id attribute and url id are mismatched" do
    conn =
      :patch
      |> conn("/example/1", Poison.encode!(%{data: %{id: "2"}}))
      |> call_plug

    assert conn.halted
    assert 409 == conn.status

    %{"errors" => [error]} = Poison.decode!(conn.resp_body)

    assert %{"source" => %{"pointer" => "/data/id"}, "title" => "Mismatched id parameter"} = error
  end

  test "passes request through" do
    conn =
      :patch
      |> conn("/example/1", Poison.encode!(%{data: %{id: "1"}}))
      |> call_plug

    refute conn.halted
  end

  defp call_plug(%{path_info: [_, id]} = conn) do
    parser_opts = Plug.Parsers.init(parsers: [:json], pass: ["text/*"], json_decoder: Poison)

    conn
    |> Plug.Conn.put_req_header("content-type", "application/json")
    |> Map.put(:path_params, %{"id" => id})
    |> Plug.Parsers.call(parser_opts)
    |> IdRequired.call([])
  end
end
