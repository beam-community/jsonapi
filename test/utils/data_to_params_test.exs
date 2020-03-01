defmodule JSONAPI.DataToParamsTest do
  use ExUnit.Case

  test "converts attributes and relationships to flattened data structure" do
    incoming = %{
      "data" => %{
        "id" => "1",
        "type" => "user",
        "attributes" => %{
          "foo-bar" => true
        },
        "relationships" => %{
          "baz" => %{
            "data" => %{
              "id" => "2",
              "type" => "baz"
            }
          },
          "boo" => %{
            "data" => nil
          }
        }
      }
    }

    result = JSONAPI.Utils.DataToParams.process(incoming)

    assert result == %{
      "id" => "1",
      "type" => "user",
      "foo-bar" => true,
      "baz-id" => "2",
      "boo-id" => nil
    }
  end

  test "processes single includes" do
    incoming = %{
      "data" => %{
        "id" => "1",
        "type" => "user",
        "attributes" => %{
          "name" => "Jerome"
        }
      },
      "included" => [
        %{
          "data" => %{
            "attributes" => %{
              "name" => "Tara"
            },
            "id" => "234",
            "type" => "friend"
          }
        }
      ]
    }

    result = JSONAPI.Utils.DataToParams.process(incoming)

    assert result == %{
      "friend" => [%{
        "name" => "Tara",
        "id" => "234",
        "type" => "friend"
      }],
      "id" => "1",
      "type" => "user",
      "name" => "Jerome"
    }
  end

  test "processes has many includes" do
    incoming = %{
      "data" => %{
        "id" => "1",
        "type" => "user",
        "attributes" => %{
          "name" => "Jerome"
        }
      },
      "included" => [
        %{
          "data" => %{
            "attributes" => %{
              "name" => "Tara"
            },
            "id" => "234",
            "type" => "friend"
          }
        },
        %{
          "data" => %{
            "attributes" => %{
              "name" => "Wild Bill"
            },
            "id" => "0012",
            "type" => "friend"
          }
        },
        %{
          "data" => %{
            "attributes" => %{
              "title" => "Sr"
            },
            "id" => "456",
            "type" => "organization"
          }
        }
      ]
    }

    result = JSONAPI.Utils.DataToParams.process(incoming)

    assert result == %{
      "friend" => [
        %{
          "name" => "Wild Bill",
          "id" => "0012",
          "type" => "friend"
        },
        %{
          "name" => "Tara",
          "id" => "234",
          "type" => "friend"
        }
      ],
      "organization" => [
        %{
          "title" => "Sr",
          "id" => "456",
          "type" => "organization"
        }
      ],
      "id" => "1",
      "type" => "user",
      "name" => "Jerome"
    }
  end

  test "processes empty keys" do
    incoming = %{
      "data" => %{
        "id" => "1",
        "type" => "user",
        "attributes" => nil
      },
      "relationships" => nil,
      "included" => nil
    }

    result = JSONAPI.Utils.DataToParams.process(incoming)

    assert result == %{
      "id" => "1",
      "type" => "user"
    }
  end

  test "processes empty data" do
    incoming = %{
      "data" => %{
        "id" => "1",
        "type" => "user"
      }
    }

    result = JSONAPI.Utils.DataToParams.process(incoming)

    assert result == %{
      "id" => "1",
      "type" => "user"
    }
  end
end
