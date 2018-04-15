defmodule JSONAPI.Utils.Dash do
  @moduledoc """
  Helpers for replacing underscores with dashes.
  """

  def dash?, do: Application.get_env(:jsonapi, :underscore_to_dash, false)

  def dash(value) when is_binary(value) do
    String.replace(value, "-", "_")
  end

  def dash(%{__struct__: _} = value) when is_map(value) do
    value
  end

  def dash(value) when is_map(value) do
    value
    |> Enum.map(&dash/1)
    |> Enum.into(%{})
  end

  def dash({key, value}) do
    if is_map(value) do
      {dash(key), dash(value)}
    else
      {dash(key), value}
    end
  end
end
