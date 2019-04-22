defmodule JSONAPI.EctoTest do
  use ExUnit.Case, async: true

  import JSONAPI.Ecto, only: [assoc_loaded?: 1]

  describe "assoc_loaded?/1" do
    test "checks if an Ecto Association is loaded" do
      refute assoc_loaded?(%Ecto.Association.NotLoaded{})

      assert assoc_loaded?(%{})
    end
  end
end
