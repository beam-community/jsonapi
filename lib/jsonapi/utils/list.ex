defmodule JSONAPI.Utils.List do
  @moduledoc false

  @doc """
  Transforms a Map into a List of Tuples that can be converted into a query string via URI.encode_query/1

  ## Examples

      iex> to_list_of_query_string_components(%{"number" => 5})
      [{"number", 5}]

      iex> to_list_of_query_string_components(%{color: "red"})
      [{:color, "red"}]

      iex> to_list_of_query_string_components(%{"alphabet" => ["a", "b", "c"]})
      [{"alphabet[]", "a"}, {"alphabet[]", "b"}, {"alphabet[]", "c"}]

      iex> to_list_of_query_string_components(%{"filters" => %{"age" => 18, "name" => "John"}})
      [{"filters[age]", 18}, {"filters[name]", "John"}]

  """
  @spec to_list_of_query_string_components(map()) :: list(tuple())
  def to_list_of_query_string_components(map) when is_map(map) do
    Enum.flat_map(map, &do_to_list_of_query_string_components/1)
  end

  defp do_to_list_of_query_string_components({key, value}) when is_list(value) do
    to_list_of_two_elem_tuple(key, value)
  end

  defp do_to_list_of_query_string_components({key, value}) when is_map(value) do
    Enum.flat_map(value, fn {k, v} -> to_list_of_two_elem_tuple("#{key}[#{k}]", v) end)
  end

  defp do_to_list_of_query_string_components({key, value}),
    do: to_list_of_two_elem_tuple(key, value)

  defp to_list_of_two_elem_tuple(key, value) when is_list(value) do
    Enum.map(value, &{"#{key}[]", &1})
  end

  defp to_list_of_two_elem_tuple(key, value) do
    [{key, value}]
  end
end
