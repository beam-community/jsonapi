defmodule JSONAPI.DeserializerTest do
  use ExUnit.Case
  use Plug.Test

  defmodule ExamplePlug do
    use Plug.Builder
    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPI.Deserializer
    plug :return

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

  test "ignores non-jsonapi.org format params" do
    req_body = Jason.encode!(%{"some-nonsense" => "yup"})

    conn =
      Plug.Test.conn("POST", "/", req_body)
      |> put_req_header("content-type", @ct)
      |> put_req_header("accept", @ct)

    result = ExamplePlug.call(conn, [])
    assert result.params == %{"some-nonsense" => "yup"}
  end

  test "deserializes attribute key names" do
    req_body =
      Jason.encode!(%{
        "data" => %{
          "attributes" => %{
            "some-nonsense" => true,
            "foo-bar" => true,
            "some-map" => %{
              "nested-key" => true
            }
          }
        }
      })

    conn =
      Plug.Test.conn("POST", "/", req_body)
      |> put_req_header("content-type", @ct)
      |> put_req_header("accept", @ct)

    result = ExamplePlug.call(conn, [])
    assert result.params["some-nonsense"] == true
    assert result.params["some-map"]["nested-key"] == true
  end

  defmodule ExampleUnderscorePlug do
    use Plug.Builder
    plug Plug.Parsers, parsers: [:json], json_decoder: Jason
    plug JSONAPI.Deserializer
    plug JSONAPI.UnderscoreParameters

    plug :return

    def return(conn, _opts) do
      send_resp(conn, 200, "success")
    end
  end

  test "deserializes attribute key names and underscores them" do
    req_body =
      Jason.encode!(%{
        "data" => %{
          "attributes" => %{
            "some-nonsense" => true,
            "foo-bar" => true,
            "some-map" => %{
              "nested-key" => true
            }
          }
        }
      })

    conn =
      Plug.Test.conn("POST", "/", req_body)
      |> put_req_header("content-type", @ct)
      |> put_req_header("accept", @ct)

    result = ExampleUnderscorePlug.call(conn, [])
    assert result.params["some_nonsense"] == true
    assert result.params["some_map"]["nested_key"] == true
  end
end
