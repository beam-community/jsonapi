defmodule JSONAPI.Utils.Underscore do
  @moduledoc """
  Helpers for replacing underscores with dashes.
  """

  def underscore?, do: Application.get_env(:jsonapi, :underscore_to_dash, false)

  def underscore(value) when is_atom(value) do
    value
    |> to_string
    |> underscore
  end

  def underscore(value) when is_binary(value) do
    String.replace(value, "_", "-")
  end

  def underscore(%{__struct__: _} = value) when is_map(value) do
    value
  end

  def underscore(value) when is_map(value) do
    value
    |> Enum.map(&underscore/1)
    |> Enum.into(%{})
  end

  def underscore({key, value}) do
    if is_map(value) do
      {underscore(key), underscore(value)}
    else
      {underscore(key), value}
    end
  end
end
