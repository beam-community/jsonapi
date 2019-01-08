defmodule JSONAPI.Utils.StringTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import JSONAPI.Utils.String

  doctest JSONAPI.Utils.String

  describe "legacy configuration to dasherize fields" do
    setup do
      Application.put_env(:jsonapi, :underscore_to_dash, true)

      on_exit(fn ->
        Application.delete_env(:jsonapi, :underscore_to_dash)
      end)

      {:ok, []}
    end

    test "#field_transformation/0 returns :dasherize" do
      assert field_transformation() == :dasherize
    end
  end

  describe "legacy configuration to underscore fields" do
    setup do
      Application.put_env(:jsonapi, :underscore_to_dash, false)

      on_exit(fn ->
        Application.delete_env(:jsonapi, :underscore_to_dash)
      end)

      {:ok, []}
    end

    test "#field_transformation/0 returns :underscore" do
      assert field_transformation() == :underscore
    end
  end
end
