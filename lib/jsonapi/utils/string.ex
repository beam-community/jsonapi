defmodule JSONAPI.Utils.String do
  @moduledoc """
  String manipulation helpers.
  """

  alias JSONAPI.Deprecation

  @allowed_transformations [:dasherize, :underscore, :camelize]

  @doc """
  Replace dashes between words in `value` with underscores

  Ignores dashes that are not between letters/numbers

  ## Examples

      iex> underscore("top-posts")
      "top_posts"

      iex> underscore("-top-posts")
      "-top_posts"

      iex> underscore("-top--posts-")
      "-top--posts-"

      iex> underscore(%{"foo-bar" => "baz"})
      %{"foo_bar" => "baz"}

      iex> underscore({"foo-bar", "dollar-sol"})
      {"foo_bar", "dollar-sol"}

      iex> underscore({"foo-bar", %{"a-d" => "z-8"}})
      {"foo_bar", %{"a_d" => "z-8"}}

      iex> underscore(%{"f-b" => %{"a-d" => "z"}, "c-d" => "e"})
      %{"f_b" => %{"a_d" => "z"}, "c_d" => "e"}

      iex> underscore(:"foo-bar")
      :foo_bar

      iex> underscore(%{"f-b" => "a-d"})
      %{"f_b" => "a-d"}
  """
  def underscore(value) when is_binary(value) do
    String.replace(value, ~r/([a-zA-Z0-9])-([a-zA-Z0-9])/, "\\1_\\2")
  end

  def underscore(map) when is_map(map) do
    Enum.into(map, %{}, &underscore/1)
  end

  def underscore({key, value}) when is_map(value) do
    {underscore(key), underscore(value)}
  end

  def underscore({key, value}) do
    {underscore(key), value}
  end

  def underscore(value) when is_atom(value) do
    value
    |> to_string()
    |> underscore()
    |> String.to_atom()
  end

  def underscore(value) do
    value
  end

  @doc """
  Replace underscores between words in `value` with dashes

  Ignores underscores that are not between letters/numbers

  ## Examples

      iex> dasherize("top_posts")
      "top-posts"

      iex> dasherize("_top_posts")
      "_top-posts"

      iex> dasherize("_top__posts_")
      "_top__posts_"
  """
  def dasherize(value) when is_atom(value) do
    value
    |> to_string()
    |> dasherize()
  end

  def dasherize(value) when is_binary(value) do
    String.replace(value, ~r/([a-zA-Z0-9])_([a-zA-Z0-9])/, "\\1-\\2")
  end

  def dasherize(%{__struct__: _} = value) when is_map(value) do
    value
  end

  def dasherize(value) when is_map(value) do
    Enum.into(value, %{}, &dasherize/1)
  end

  def dasherize({key, value}) do
    if is_map(value) do
      {dasherize(key), dasherize(value)}
    else
      {dasherize(key), value}
    end
  end

  @doc """
  Replace underscores or dashes between words in `value` with camelCasing

  Ignores underscores or dashes that are not between letters/numbers

  ## Examples

      iex> camelize("top_posts")
      "topPosts"

      iex> camelize("_top_posts")
      "_topPosts"

      iex> camelize("_top__posts_")
      "_top__posts_"
  """
  def camelize(value) when is_atom(value) do
    value
    |> to_string()
    |> camelize()
  end

  def camelize(value) when is_binary(value) do
    case Regex.split(
           ~r{(?<=[a-zA-Z0-9])[-_](?=[a-zA-Z0-9])},
           to_string(value)
         ) do
      words ->
        [h | t] = words |> Enum.filter(&(&1 != ""))

        [String.downcase(h) | camelize_list(t)]
        |> Enum.join()
    end
  end

  defp camelize_list([]), do: []

  defp camelize_list([h | t]) do
    [String.capitalize(h)] ++ camelize_list(t)
  end

  def camelize(%{__struct__: _} = value) when is_map(value) do
    value
  end

  def camelize(value) when is_map(value) do
    Enum.into(value, %{}, &camelize/1)
  end

  def camelize({key, value}) do
    if is_map(value) do
      {camelize(key), camelize(value)}
    else
      {camelize(key), value}
    end
  end

  defp normalized_underscore_to_dash_config(value) when is_boolean(value) do
    Deprecation.warn(:underscore_to_dash)

    if value do
      :dasherize
    else
      :underscore
    end
  end

  defp normalized_underscore_to_dash_config(value) when is_nil(value), do: value

  @doc """
  The configured transformation for the API's fields. JSON:API v1.1 recommends
  using camlized fields (e.g. "goodDog", versus "good_dog").  However, we don't hold a strong
  opinion, so feel free to customize it how you would like (e.g. "good-dog", versus "good_dog").

  This library currently supports camelized, dashed and underscored fields.

  ## Configuration examples

  camelCase fields:

  ```
  config :jsonapi, field_transformation: :camelize
  ```

  Dashed fields:

  ```
  config :jsonapi, field_transformation: :dasherize
  ```

  Underscored fields:

  ```
  config :jsonapi, field_transformation: :underscore
  ```
  """
  def field_transformation do
    normalized_underscore_to_dash_config(Application.get_env(:jsonapi, :underscore_to_dash)) ||
      field_transformation(Application.get_env(:jsonapi, :field_transformation))
  end

  @doc false
  def field_transformation(transformation) when transformation in @allowed_transformations,
    do: transformation
end
