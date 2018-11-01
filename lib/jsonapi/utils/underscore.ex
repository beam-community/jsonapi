defmodule JSONAPI.Utils.Underscore do
  @moduledoc """
  Helpers for replacing underscores with dashes.
  """

  def underscore?, do: Application.get_env(:jsonapi, :underscore_to_dash, false)

  def dash(value) when is_binary(value) do
    String.replace(value, ~r/([a-zA-Z0-9])-([a-zA-Z0-9])/, "\\1_\\2")
  end

  def underscore(value) when is_atom(value) do
    value
    |> to_string
    |> underscore
  end

  def underscore(value) when is_binary(value) do
    String.replace(value, ~r/([a-zA-Z0-9])_([a-zA-Z0-9])/, "\\1-\\2")
  end

  def underscore(%{__struct__: _} = value) when is_map(value) do
    value
  end

  def underscore(value) when is_map(value) do
    Enum.into(value, %{}, &underscore/1)
  end

  def underscore({key, value}) do
    if is_map(value) do
      {underscore(key), underscore(value)}
    else
      {underscore(key), value}
    end
  end
end
