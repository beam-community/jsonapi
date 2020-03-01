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
          },
          "relationships" => %{
            "baz" => %{
              "data" => %{
                "id" => "2",
                "type" => "baz"
              }
            }
          }
        },
        "filter" => %{
          "dog-breed" => "Corgi"
        }
      })

    conn =
      Plug.Test.conn("POST", "/", req_body)
      |> put_req_header("content-type", @ct)
      |> put_req_header("accept", @ct)

    result = ExamplePlug.call(conn, [])
    assert result.params["some-nonsense"] == true
    assert result.params["some-map"]["nested-key"] == true
    assert result.params["baz-id"] == "2"

    # Preserves query params
    assert result.params["filter"]["dog-breed"] == "Corgi"
  end

  describe "underscore" do
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
            },
            "relationships" => %{
              "baz" => %{
                "data" => %{
                  "id" => "2",
                  "type" => "baz"
                }
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
      assert result.params["baz_id"] == "2"
    end
  end

  describe "camelize" do
    setup do
      Application.put_env(:jsonapi, :field_transformation, :camelize)

      on_exit(fn ->
        Application.delete_env(:jsonapi, :field_transformation)
      end)

      {:ok, []}
    end

    defmodule ExampleCamelCasePlug do
      use Plug.Builder
      plug Plug.Parsers, parsers: [:json], json_decoder: Jason
      plug JSONAPI.Deserializer

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
              "someNonsense" => true,
              "fooBar" => true,
              "someMap" => %{
                "nested_key" => true
              }
            },
            "relationships" => %{
              "baz" => %{
                "data" => %{
                  "id" => "2",
                  "type" => "baz"
                }
              }
            }
          }
        })

      conn =
        Plug.Test.conn("POST", "/", req_body)
        |> put_req_header("content-type", @ct)
        |> put_req_header("accept", @ct)

      result = ExampleCamelCasePlug.call(conn, [])
      assert result.params["someNonsense"] == true
      assert result.params["someMap"]["nested_key"] == true
      assert result.params["bazId"] == "2"
    end
  end
end
