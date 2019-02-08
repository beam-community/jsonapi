defmodule JSONAPI.FormatRequiredTest do
  use ExUnit.Case
  use Plug.Test

  alias JSONAPI.FormatRequired

  test "halts and returns an error for missing data param" do
    conn =
      :post
      |> conn("/example", Jason.encode!(%{}))
      |> call_plug

    assert conn.halted
    assert 400 == conn.status

    %{"errors" => [error]} = Jason.decode!(conn.resp_body)

    assert %{"source" => %{"pointer" => "/data"}, "title" => "Missing data parameter"} = error
  end

  test "halts and returns an error for missing attributes in data param" do
    conn =
      :post
      |> conn("/example", Jason.encode!(%{data: %{}}))
      |> call_plug

    assert conn.halted
    assert 400 == conn.status

    %{"errors" => [error]} = Jason.decode!(conn.resp_body)

    assert %{
             "source" => %{"pointer" => "/data/attributes"},
             "title" => "Missing attributes in data parameter"
           } = error
  end

  test "does not halt if only type member is present on a post" do
    conn =
      :post
      |> conn("/example", Jason.encode!(%{data: %{type: "something"}}))
      |> call_plug

    refute conn.halted
  end

  test "halts if only type member is present on a patch" do
    conn =
      :patch
      |> conn("/example", Jason.encode!(%{data: %{type: "something"}}))
      |> call_plug

    assert conn.halted
  end

  test "does not halt if type and id members are present on a patch" do
    conn =
      :patch
      |> conn("/example", Jason.encode!(%{data: %{type: "something", id: "some-identifier"}}))
      |> call_plug

    refute conn.halted
  end

  test "accepts a multi-RIO payload for relationship POST endpoints" do
    # Cf. https://jsonapi.org/format/#crud-updating-to-many-relationships
    conn =
      :post
      |> conn("/example", Jason.encode!(%{data: [%{type: "something"}]}))
      |> call_plug

    refute conn.halted
  end

  test "passes request through" do
    conn =
      :post
      |> conn("/example", Jason.encode!(%{data: %{type: "something"}}))
      |> call_plug

    refute conn.halted
  end

  defp call_plug(conn) do
    parser_opts = Plug.Parsers.init(parsers: [:json], pass: ["text/*"], json_decoder: Jason)

    conn
    |> Plug.Conn.put_req_header("content-type", "application/json")
    |> Plug.Parsers.call(parser_opts)
    |> FormatRequired.call([])
  end
end
