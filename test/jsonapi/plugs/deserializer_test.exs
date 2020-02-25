defmodule JSONAPI.DeserializerTest do
  use ExUnit.Case
  use Plug.Test

  defmodule ExamplePlug do
    use Plug.Builder
    plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
    plug(JSONAPI.Deserializer)
    plug(:return)

    def return(conn, _opts) do
      send_resp(conn, 200, "success")
    end
  end

  @ct "application/vnd.api+json"

  test "Ignores bodyless requests" do
    conn =
      Plug.Test.conn("GET", "/")
      |> put_req_header("content-type", @ct)
      |> put_req_header("accept", @ct)

    result = ExamplePlug.call(conn, [])
    assert result.params == %{}
  end

  test "converts non-jsonapi.org format params" do
    req_body = Jason.encode!(%{"some-nonsense" => "yup"})

    conn =
      Plug.Test.conn("POST", "/", req_body)
      |> put_req_header("content-type", @ct)
      |> put_req_header("accept", @ct)

    result = ExamplePlug.call(conn, [])
    assert result.params == %{"some_nonsense" => "yup"}
  end

  test "converts attribute key names" do
    req_body =
      Jason.encode!(%{
        "data" => %{
          "attributes" => %{
            "some-nonsense" => true,
            "foo-bar" => true,
            "some-map" => %{
              "nested-key" => "unaffected-values"
            }
          }
        }
      })

    conn =
      Plug.Test.conn("POST", "/", req_body)
      |> put_req_header("content-type", @ct)
      |> put_req_header("accept", @ct)

    result = ExamplePlug.call(conn, [])
    assert result.params["data"]["attributes"]["some_nonsense"]
    assert result.params["data"]["attributes"]["foo_bar"]
    assert result.params["data"]["attributes"]["some_map"]["nested_key"]
  end

  test "converts query param key names - dasherized" do
    req_body = Jason.encode!(%{"data" => %{}})

    conn =
      Plug.Test.conn("POST", "/?page[page-size]=2", req_body)
      |> put_req_header("content-type", @ct)
      |> put_req_header("accept", @ct)

    result = ExamplePlug.call(conn, [])
    assert result.params["page"]["page_size"] == "2"
  end

  test "converts query param key names - underscored" do
    req_body = Jason.encode!(%{"data" => %{}})

    conn =
      Plug.Test.conn("POST", "/?page[page_size]=2", req_body)
      |> put_req_header("content-type", @ct)
      |> put_req_header("accept", @ct)

    result = ExamplePlug.call(conn, [])
    assert result.query_params["page"]["page_size"] == "2"
  end

  test "retains payload type" do
    req_body =
      Jason.encode!(%{
        "data" => %{
          "type" => "foo-bar"
        }
      })

    conn =
      Plug.Test.conn("POST", "/", req_body)
      |> put_req_header("content-type", @ct)
      |> put_req_header("accept", @ct)

    result = ExamplePlug.call(conn, [])
    assert result.params["data"]["type"] == "foo-bar"
  end
end
