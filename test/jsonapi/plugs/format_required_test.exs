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

  test "halts and returns an error for missing type in data param" do
    conn =
      :post
      |> conn("/example", Jason.encode!(%{data: %{attributes: %{}}}))
      |> call_plug

    assert conn.halted
    assert 400 == conn.status

    %{"errors" => [error]} = Jason.decode!(conn.resp_body)

    assert %{
             "source" => %{"pointer" => "/data/type"},
             "title" => "Missing type in data parameter"
           } = error
  end

  test "does not halt if only type member is present on a post" do
    conn =
      :post
      |> conn("/example", Jason.encode!(%{data: %{type: "something"}}))
      |> call_plug

    refute conn.halted
  end

  test "halts and returns an error for missing id in data param on a patch" do
    conn =
      :patch
      |> conn("/example", Jason.encode!(%{data: %{attributes: %{}, type: "something"}}))
      |> call_plug

    assert conn.halted
    assert 400 == conn.status

    %{"errors" => [error]} = Jason.decode!(conn.resp_body)

    assert %{
             "source" => %{"pointer" => "/data/id"},
             "title" => "Missing id in data parameter"
           } = error
  end

  test "halts and returns an error for missing type in data param on a patch" do
    conn =
      :patch
      |> conn("/example", Jason.encode!(%{data: %{attributes: %{}, id: "something"}}))
      |> call_plug

    assert conn.halted
    assert 400 == conn.status

    %{"errors" => [error]} = Jason.decode!(conn.resp_body)

    assert %{
             "source" => %{"pointer" => "/data/type"},
             "title" => "Missing type in data parameter"
           } = error
  end

  test "does not halt if type and id members are present on a patch" do
    conn =
      :patch
      |> conn("/example", Jason.encode!(%{data: %{type: "something", id: "some-identifier"}}))
      |> call_plug

    refute conn.halted
  end

  test "halts with a multi-RIO payload to a non-relationship PATCH endpoint" do
    :patch
    |> conn("/example", Jason.encode!(%{data: [%{type: "something"}]}))
    |> call_plug
    |> assert_improper_use_of_multi_rio()
  end

  test "halts with a multi-RIO payload to a non-relationship POST endpoint" do
    :post
    |> conn("/example", Jason.encode!(%{data: [%{type: "something"}]}))
    |> call_plug
    |> assert_improper_use_of_multi_rio()
  end

  test "accepts a multi-RIO payload for relationship PATCH endpoints" do
    conn =
      :patch
      |> conn("/example/relationships/things", Jason.encode!(%{data: [%{type: "something"}]}))
      |> call_plug

    refute conn.halted
  end

  test "accepts a multi-RIO payload for relationship POST endpoints" do
    conn =
      :post
      |> conn("/example/relationships/things", Jason.encode!(%{data: [%{type: "something"}]}))
      |> call_plug

    refute conn.halted
  end

  test "halts and returns an error for a specified relationships param missing an object value ON POST" do
    conn =
      :post
      |> conn(
        "/example",
        Jason.encode!(%{data: %{type: "example", attributes: %{}, relationships: nil}})
      )
      |> call_plug

    assert conn.halted
    assert 400 == conn.status

    %{"errors" => [error]} = Jason.decode!(conn.resp_body)

    assert %{
             "source" => %{"pointer" => "/data/relationships"},
             "title" => "Relationships parameter is not an object",
             "detail" =>
               "Check out https://jsonapi.org/format/#document-resource-object-relationships for more info."
           } = error
  end

  test "halts and returns an error for a specified relationships param missing an object value ON PATCH" do
    conn =
      :patch
      |> conn(
        "/example/some-id",
        Jason.encode!(%{
          data: %{id: "some-id", type: "example", attributes: %{}, relationships: nil}
        })
      )
      |> call_plug

    assert conn.halted
    assert 400 == conn.status

    %{"errors" => [error]} = Jason.decode!(conn.resp_body)

    assert %{
             "source" => %{"pointer" => "/data/relationships"},
             "title" => "Relationships parameter is not an object",
             "detail" =>
               "Check out https://jsonapi.org/format/#document-resource-object-relationships for more info."
           } = error
  end

  test "halts and returns an error for relationship objects missing a data member on POST" do
    conn =
      :post
      |> conn(
        "/example",
        Jason.encode!(%{
          data: %{
            type: "example",
            attributes: %{},
            relationships: %{comment: %{id: "some-identifier"}}
          }
        })
      )
      |> call_plug

    assert conn.halted
    assert 400 == conn.status

    %{"errors" => [error]} = Jason.decode!(conn.resp_body)

    assert %{
             "source" => %{"pointer" => "/data/relationships/comment/data"},
             "title" => "Missing data member in relationship"
           } = error
  end

  test "halts and returns an error for relationship objects missing a data member on PATCH" do
    conn =
      :patch
      |> conn(
        "/example/some-id",
        Jason.encode!(%{
          data: %{
            id: "some-id",
            type: "example",
            attributes: %{},
            relationships: %{comment: %{id: "some-identifier"}}
          }
        })
      )
      |> call_plug

    assert conn.halted
    assert 400 == conn.status

    %{"errors" => [error]} = Jason.decode!(conn.resp_body)

    assert %{
             "source" => %{"pointer" => "/data/relationships/comment/data"},
             "title" => "Missing data member in relationship"
           } = error
  end

  test "halts and returns an error for relationship objects with a resource linkage missing a type member on POST" do
    conn =
      :post
      |> conn(
        "/example",
        Jason.encode!(%{
          data: %{
            type: "example",
            attributes: %{},
            relationships: %{comment: %{data: %{id: "some-identifier"}}}
          }
        })
      )
      |> call_plug

    assert conn.halted
    assert 400 == conn.status

    %{"errors" => [error]} = Jason.decode!(conn.resp_body)

    assert %{
             "source" => %{"pointer" => "/data/relationships/comment/data/type"},
             "title" => "Missing type in relationship data parameter"
           } = error
  end

  test "halts and returns an error for relationship objects with a resource linkage missing a type member on PATCH" do
    conn =
      :patch
      |> conn(
        "/example/some-id",
        Jason.encode!(%{
          data: %{
            id: "some-id",
            type: "example",
            attributes: %{},
            relationships: %{comment: %{data: %{id: "some-identifier"}}}
          }
        })
      )
      |> call_plug

    assert conn.halted
    assert 400 == conn.status

    %{"errors" => [error]} = Jason.decode!(conn.resp_body)

    assert %{
             "source" => %{"pointer" => "/data/relationships/comment/data/type"},
             "title" => "Missing type in relationship data parameter"
           } = error
  end

  test "halts and returns an error for relationship objects with a resource linkage missing an id member on POST" do
    conn =
      :post
      |> conn(
        "/example",
        Jason.encode!(%{
          data: %{
            type: "example",
            attributes: %{},
            relationships: %{comment: %{data: %{type: "comment"}}}
          }
        })
      )
      |> call_plug

    assert conn.halted
    assert 400 == conn.status

    %{"errors" => [error]} = Jason.decode!(conn.resp_body)

    assert %{
             "source" => %{"pointer" => "/data/relationships/comment/data/id"},
             "title" => "Missing id in relationship data parameter"
           } = error
  end

  test "halts and returns an error for relationship objects with a resource linkage missing an id member on PATCH" do
    conn =
      :patch
      |> conn(
        "/example/some-id",
        Jason.encode!(%{
          data: %{
            id: "some-id",
            type: "example",
            attributes: %{},
            relationships: %{comment: %{data: %{type: "comment"}}}
          }
        })
      )
      |> call_plug

    assert conn.halted
    assert 400 == conn.status

    %{"errors" => [error]} = Jason.decode!(conn.resp_body)

    assert %{
             "source" => %{"pointer" => "/data/relationships/comment/data/id"},
             "title" => "Missing id in relationship data parameter"
           } = error
  end

  test "halts and returns an error for relationship objects with a resource linkage missing both type and id members on POST" do
    conn =
      :post
      |> conn(
        "/example",
        Jason.encode!(%{
          data: %{
            type: "example",
            attributes: %{},
            relationships: %{comment: %{data: %{}}}
          }
        })
      )
      |> call_plug

    assert conn.halted
    assert 400 == conn.status

    %{"errors" => errors} = Jason.decode!(conn.resp_body)

    error_titles = Enum.map(errors, fn error -> Map.fetch!(error, "title") end)
    assert "Missing id in relationship data parameter" in error_titles
    assert "Missing type in relationship data parameter" in error_titles

    error_pointers = Enum.map(errors, fn error -> get_in(error, ["source", "pointer"]) end)
    assert "/data/relationships/comment/data/id" in error_pointers
    assert "/data/relationships/comment/data/type" in error_pointers
  end

  test "halts and returns an error for relationship objects with a resource linkage missing both type and id members on PATCH" do
    conn =
      :patch
      |> conn(
        "/example/some-id",
        Jason.encode!(%{
          data: %{
            id: "some-id",
            type: "example",
            attributes: %{},
            relationships: %{comment: %{data: %{}}}
          }
        })
      )
      |> call_plug

    assert conn.halted
    assert 400 == conn.status

    %{"errors" => errors} = Jason.decode!(conn.resp_body)

    error_titles = Enum.map(errors, fn error -> Map.fetch!(error, "title") end)
    assert "Missing id in relationship data parameter" in error_titles
    assert "Missing type in relationship data parameter" in error_titles

    error_pointers = Enum.map(errors, fn error -> get_in(error, ["source", "pointer"]) end)
    assert "/data/relationships/comment/data/id" in error_pointers
    assert "/data/relationships/comment/data/type" in error_pointers
  end

  test "accepts a relationships object with well-formed resource linkages on POST" do
    conn =
      :post
      |> conn(
        "/example",
        Jason.encode!(%{
          data: %{
            type: "example",
            attributes: %{},
            relationships: %{
              comment: %{data: %{type: "comment", id: "some-identifier"}},
              post: %{data: nil},
              reviews: %{data: []}
            }
          }
        })
      )
      |> call_plug

    refute conn.halted
  end

  test "accepts a relationships object with well-formed resource linkages on PATCH" do
    conn =
      :patch
      |> conn(
        "/example/some-id",
        Jason.encode!(%{
          data: %{
            id: "some-id",
            type: "example",
            attributes: %{},
            relationships: %{
              comment: %{data: %{type: "comment", id: "some-identifier"}},
              post: %{data: nil},
              reviews: %{data: []}
            }
          }
        })
      )
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

  defp assert_improper_use_of_multi_rio(conn) do
    assert conn.halted
    assert 400 == conn.status

    %{"errors" => [error]} = Jason.decode!(conn.resp_body)

    assert %{
             "detail" =>
               "Check out https://jsonapi.org/format/#crud-updating-to-many-relationships for more info.",
             "source" => %{"pointer" => "/data"},
             "status" => "400",
             "title" =>
               "Data parameter has multiple Resource Identifier Objects for a non-relationship endpoint"
           } = error
  end

  defp call_plug(conn) do
    parser_opts = Plug.Parsers.init(parsers: [:json], pass: ["text/*"], json_decoder: Jason)

    conn
    |> Plug.Conn.put_req_header("content-type", "application/json")
    |> Plug.Parsers.call(parser_opts)
    |> FormatRequired.call([])
  end
end
