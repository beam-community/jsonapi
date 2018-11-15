defmodule JSONAPI.Utils.Underscore do
  @moduledoc """
  Helpers for replacing underscores with dashes.
  """

  def underscore?, do: Application.get_env(:jsonapi, :underscore_to_dash, false) != false

  @doc """
  Replace dashes between words in `value` with underscores

  Ignores dashes that are not between letters/numbers

  ## Examples

      iex> dash("top-posts")
      "top_posts"

      iex> dash("-top-posts")
      "-top_posts"

      iex> dash("-top--posts-")
      "-top--posts-"
  """
  def dash(value) when is_binary(value) do
    String.replace(value, ~r/([a-zA-Z0-9])-([a-zA-Z0-9])/, "\\1_\\2")
  end

  @doc """
  Replace underscores between words in `value` with dashes

  Ignores underscores that are not between letters/numbers

  ## Examples

      iex> underscore("top_posts")
      "top-posts"

      iex> underscore("_top_posts")
      "_top-posts"

      iex> underscore("_top__posts_")
      "_top__posts_"
  """
  def underscore(value) when is_atom(value) do
    if underscore?(value) do
      value
      |> to_string()
      |> underscore()
    else
      to_string(value)
    end
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
    if underscore?(key) and is_map(value) do
      {underscore(key), underscore(value)}
    else
      {underscore(key), value}
    end
  end

  defp underscore?(key) do
    config = Application.get_env(:jsonapi, :underscore_to_dash)
    config_specifies_underscore?(config, key)
  end

  defp config_specifies_underscore?(true, _), do: true
  defp config_specifies_underscore?(false, _), do: false

  defp config_specifies_underscore?(config, key) when is_list(config) do
    cond do
      Keyword.has_key?(config, :only) -> key in Keyword.get(config, :only, [])
      Keyword.has_key?(config, :except) -> key not in Keyword.get(config, :except, [])
      true -> false
    end
  end

end
