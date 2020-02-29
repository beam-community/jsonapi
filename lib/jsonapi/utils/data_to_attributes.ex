defmodule JSONAPI.Utils.DataToAttributes do
  @moduledoc ~S"""
  Converts params in the JSON api format into flat params convient for
  changeset casting.
  """
  @spec parse_data(map) :: map
  def parse_data(%{"data" => data}) do
    # TODO
  end
end
