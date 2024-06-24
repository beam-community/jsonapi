defmodule JSONAPI.DataToParamsTest do
  use ExUnit.Case

  alias JSONAPI.Utils.DataToParams

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

    result = DataToParams.process(incoming)

    assert result == %{
             "id" => "1",
             "type" => "user",
             "foo-bar" => true,
             "baz-id" => "2",
             "boo-id" => nil
           }
  end

  test "converts to many relationship" do
    incoming = %{
      "data" => %{
        "id" => "1",
        "type" => "user",
        "attributes" => %{
          "foo-bar" => true
        },
        "relationships" => %{
          "baz" => %{
            "data" => [
              %{"id" => "2", "type" => "baz"},
              %{"id" => "3", "type" => "baz"}
            ]
          }
        }
      }
    }

    result = DataToParams.process(incoming)

    assert result == %{
             "id" => "1",
             "type" => "user",
             "foo-bar" => true,
             "baz-id" => ["2", "3"]
           }
  end

  test "converts polymorphic" do
    incoming = %{
      "data" => %{
        "id" => "1",
        "type" => "user",
        "attributes" => %{
          "foo-bar" => true
        },
        "relationships" => %{
          "baz" => %{
            "data" => [
              %{"id" => "2", "type" => "baz"},
              %{"id" => "3", "type" => "yooper"}
            ]
          }
        }
      }
    }

    result = DataToParams.process(incoming)

    assert result == %{
             "id" => "1",
             "type" => "user",
             "foo-bar" => true,
             "baz-id" => "2",
             "yooper-id" => "3"
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

    result = DataToParams.process(incoming)

    assert result == %{
             "friend" => [
               %{
                 "name" => "Tara",
                 "id" => "234",
                 "type" => "friend"
               }
             ],
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
            "id" => "234",
            "type" => "friend",
            "attributes" => %{
              "name" => "Tara"
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

    result = DataToParams.process(incoming)

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
                 "type" => "friend",
                 "baz-id" => "2",
                 "boo-id" => nil
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

  test "processes simple array of data" do
    incoming = %{
      "data" => [
        %{"id" => "1", "type" => "user"},
        %{"id" => "2", "type" => "user"}
      ]
    }

    result = DataToParams.process(incoming)

    assert result == [
             %{"id" => "1", "type" => "user"},
             %{"id" => "2", "type" => "user"}
           ]
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

    result = DataToParams.process(incoming)

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

    result = DataToParams.process(incoming)

    assert result == %{
             "id" => "1",
             "type" => "user"
           }
  end

  test "processes nil data" do
    incoming = %{
      "data" => nil
    }

    result = DataToParams.process(incoming)

    assert result == nil
  end
end
