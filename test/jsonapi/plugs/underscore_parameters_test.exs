defmodule JSONAPI.UnderscoreParametersTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias JSONAPI.UnderscoreParameters

  test "underscores dasherized data parameters" do
    params = %{
      "data" => %{
        "attributes" => %{
          "first-name" => "John",
          "last-name" => "Cleese",
          "stats" => %{
            "age" => 45,
            "dog-name" => "Pedro"
          }
        }
      },
      "filter" => %{
        "dog-breed" => "Corgi"
      }
    }

    conn =
      :get
      |> conn("/hello", params)
      |> put_req_header("content-type", "application/vnd.api+json")

    assert %Plug.Conn{
             params: %{
               "data" => %{
                 "attributes" => %{
                   "first_name" => "John",
                   "last_name" => "Cleese",
                   "stats" => %{
                     "age" => 45,
                     "dog_name" => "Pedro"
                   }
                 }
               },
               "filter" => %{
                 "dog_breed" => "Corgi"
               }
             }
           } = UnderscoreParameters.call(conn, [])

    params = %{
      "data" => %{
        "attributes" => %{
          "math-problem" => "1-1=2"
        }
      }
    }

    conn =
      :get
      |> conn("/example", params)
      |> put_req_header("content-type", JSONAPI.mime_type())

    assert %Plug.Conn{
             params: %{
               "data" => %{
                 "attributes" => %{
                   "math_problem" => "1-1=2"
                 }
               }
             }
           } = UnderscoreParameters.call(conn, [])
  end

  test "does not transform when the content type is not for json:api" do
    params = %{
      "data" => %{
        "attributes" => %{
          "dog-breed" => "Corgi"
        }
      }
    }

    conn = conn(:get, "/hello", params)

    assert %Plug.Conn{
             params: %{
               "data" => %{
                 "attributes" => %{
                   "dog-breed" => "Corgi"
                 }
               }
             }
           } = UnderscoreParameters.call(conn, [])
  end
end
