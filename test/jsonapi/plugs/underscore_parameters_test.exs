defmodule JSONAPI.UnderscoreParametersTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias JSONAPI.UnderscoreParameters

  describe "call/2" do
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
        |> put_req_header("content-type", JSONAPI.mime_type())

      assert %Plug.Conn{
               params: %{
                 "data" => %{
                   "attributes" => %{
                     "first_name" => "John",
                     "last_name" => "Cleese",
                     "stats" => %{
                       "age" => "45",
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

    test ":replace_query_params option replaces filter[...] keys in the Conn's query_params" do
      conn =
        :get
        |> conn("?filter[favorite-food]=pizza")
        |> put_req_header("content-type", JSONAPI.mime_type())

      # Before: filter name is dasherized
      assert %{"favorite-food" => _} = fetch_query_params(conn).query_params["filter"]

      # After: filter name is underscored
      updated_conn = UnderscoreParameters.call(conn, replace_query_params: true)
      assert %{"favorite_food" => _} = fetch_query_params(updated_conn).query_params["filter"]

      # After (without option): filter name remains dasherized
      updated_conn = UnderscoreParameters.call(conn, [])
      assert %{"favorite-food" => _} = fetch_query_params(updated_conn).query_params["filter"]
    end

    test ":replace_query_params option replaces fields[...] values in the Conn's query_params" do
      conn =
        :get
        |> conn("?fields[favorite-food]=is-fried")
        |> put_req_header("content-type", JSONAPI.mime_type())

      # Before: key and value are dasherized
      assert %{"favorite-food" => "is-fried"} = fetch_query_params(conn).query_params["fields"]

      # After: key is unchanged and value is underscored
      updated_conn = UnderscoreParameters.call(conn, replace_query_params: true)

      assert %{"favorite-food" => "is_fried"} =
               fetch_query_params(updated_conn).query_params["fields"]

      # After (without option): key and value remain dasherized
      updated_conn = UnderscoreParameters.call(conn, [])

      assert %{"favorite-food" => "is-fried"} =
               fetch_query_params(updated_conn).query_params["fields"]
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

  describe "init/1" do
    test "the replace_query_params option must be a boolean" do
      # These are okay
      assert UnderscoreParameters.init([])
      assert UnderscoreParameters.init(replace_query_params: true)
      assert UnderscoreParameters.init(replace_query_params: false)

      # These are not allowed
      assert_raise ArgumentError, fn ->
        UnderscoreParameters.init(replace_query_params: 1)
      end

      assert_raise ArgumentError, fn ->
        UnderscoreParameters.init(foo: "bar", replace_query_params: 1)
      end
    end
  end
end
