defmodule JSONAPI.Utils.Underscore do
  @moduledoc """
  Helpers for replacing underscores with dashes.
  """

  def underscore?, do: Application.get_env(:jsonapi, :underscore_to_dash, false)

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

      iex> dash(%{"foo-bar" => "baz"})
      %{"foo_bar" => "baz"}

      iex> dash({"foo-bar", "dollar-sol"})
      {"foo_bar", "dollar-sol"}

      iex> dash({"foo-bar", %{"a-d" => "z-8"}})
      {"foo_bar", %{"a_d" => "z-8"}}

      iex> dash(%{"f-b" => %{"a-d" => "z"}, "c-d" => "e"})
      %{"f_b" => %{"a_d" => "z"}, "c_d" => "e"}

      iex> dash(:"foo-bar")
      :foo_bar

      iex> dash(%{"f-b" => "a-d"})
      %{"f_b" => "a-d"}
  """
  def dash(value) when is_binary(value) do
    String.replace(value, ~r/([a-zA-Z0-9])-([a-zA-Z0-9])/, "\\1_\\2")
  end

  def dash(map) when is_map(map) do
    Enum.into(map, %{}, &dash/1)
  end

  def dash({key, value}) when is_map(value) do
    {dash(key), dash(value)}
  end

  def dash({key, value}) do
    {dash(key), value}
  end

  def dash(value) when is_atom(value) do
    value
    |> to_string()
    |> dash()
    |> String.to_atom()
  end

  def dash(value) do
    value
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
