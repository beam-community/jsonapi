defmodule JSONAPI.Utils.List do
  @moduledoc """
  Utility functions to build a list from a map in a different format than the one returned by Map.to_list/2
  """

  @doc """
  Transform a map es. %{key1: value1, key2: value2} into a list of two element tuple.

  - if values are terms that implements the String.Chars protocol it returns [{key1, value1}, {key2, value2}]
  - if any value is a list es. %{key1: ["a", "b"]} it returns [{key1[], "a"}, {key1[], "b"}]
  - if any value is a map es. %{key1: %{key2: "c", key3: "d"}} it returns [{key1[key2], "c"}, {key1[key3], "d"}]

  ## Examples

      iex> to_custom_list(%{"number" => 5})
      [{"number", 5}]

      iex> to_custom_list(%{color: "red"})
      [{:color, "red"}]

      iex> to_custom_list(%{"alphabet" => ["a", "b", "c"]})
      [{"alphabet[]", "a"}, {"alphabet[]", "b"}, {"alphabet[]", "c"}]

      iex> to_custom_list(%{"filters" => %{"age" => 18, "name" => "John"}})
      [{"filters[age]", 18}, {"filters[name]", "John"}]

  """
  @spec to_custom_list(map()) :: list(tuple())
  def to_custom_list(map) when is_map(map) do
    Enum.flat_map(map, &do_to_custom_list/1)
  end

  defp do_to_custom_list({key, value}) when is_list(value) do
    to_list_of_tuple(key, value)
  end

  defp do_to_custom_list({key, value}) when is_map(value) do
    Enum.flat_map(value, fn {k, v} -> to_list_of_tuple("#{key}[#{k}]", v) end)
  end

  defp do_to_custom_list({key, value}), do: to_list_of_tuple(key, value)

  defp to_list_of_tuple(key, value) when is_list(value) do
    Enum.map(value, &{"#{key}[]", &1})
  end

  defp to_list_of_tuple(key, value) do
    [{key, value}]
  end
end
