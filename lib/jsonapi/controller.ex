defmodule JSONAPI.Controller do
  @moduledoc """
  This module is a grab bag of functions that are useful when parsing query strings for JSONAPI.

  Your goto should be clean_params\2 

      > params = JSONAPI.Query.clean_params(params)
      > %{ filter: %{}, sort: [], include: %{}}

  You might also find `get!(User, id)` to be handy.

  This whole module needs to be cleaned up and standardized.   
  """

  @doc """
  Gets the module from the current `Repo` raises JSONAPI.ResourceNotFound
  otherwise. Can accept a string or an integer for id. Current impl expects
  a integer id.
  """
  @spec get!(module, String.t | Integer.t) :: Map.t | no_return 
  def get!(_m, nil), do: raise Ecto.NoResultsError
  def get!(_m, "null"), do: raise Ecto.NoResultsError
  def get!(_m, ""), do: raise Ecto.NoResultsError
  def get!(module, id) when is_binary(id), do: get!(module, String.to_integer(id))
  def get!(module, id) when is_integer(id) and is_atom(module) do
    Repo.get!(module, id)
  end

  @doc """
  Will take a standards string key => val params map and parse out useful pieces for JSONAPI.

  This function is very much a work in progress, the most useful thing it currently does is 
  call parse_sort/1 and paging/1 and return a atom => val map.
  """
  def clean_params(params) do
    filter = Dict.get(params, "filter", %{})
    include = Dict.get(params, "include", %{})
    sort = Dict.get(params, "sort", "") |> parse_sort

    params
    |> Dict.merge(%{filter: filter, include: include, sort: sort})
    |> paging()
  end

  @doc """
  Takes the sort parameter like `-created_at,+name` and turn it into
  something ecto's `order_by` can use like `[created_at: :desc, name: :asc]`
  """
  def parse_sort(sort_param) do
    sorts = String.split(sort_param, ",")
            |> Enum.filter(fn (x) -> String.starts_with?(x, ["+", "-"]) end)
            |> List.delete("")
    parse_sort(sorts, [])
  end

  @doc """
  Takes the page parameter, converts the strings to ints and returns a new params object.
  """
  def paging(params) do
    page_map = Dict.get(params, "page", %{})

    number = Dict.get(page_map, "number", "0") |> String.to_integer
    size = Dict.get(page_map, "size", "20") |> String.to_integer

    Dict.put(params, :page, %{ number: number, size: size})
  end

  @doc """
  Handy when parsing "null"'s from query strings.
  """
  def parse_null_parameters(nil), do: nil
  def parse_null_parameters(list) do
    Enum.map(list, fn(x) -> if x == "null", do: nil, else: x end)
  end

  @doc """
  Makes sure we don't have nulls before spliting a filter list
  """
  def split_filter_list(nil), do: nil
  def split_filter_list(value) when is_binary(value) do
    String.split(value, ",")
  end
  defp parse_sort([], []), do: [desc: :created_at]
  defp parse_sort([], acc), do: acc

  defp parse_sort([s | rest], acc) do
    parse_sort(rest, acc ++ parse_sort_piece(s))
  end

  defp parse_sort_piece("-" <> sort), do: [desc: String.to_atom(sort)]
  defp parse_sort_piece("+" <> sort), do: [asc: String.to_atom(sort)]
end

