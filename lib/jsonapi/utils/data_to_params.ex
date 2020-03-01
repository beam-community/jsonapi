defmodule JSONAPI.Utils.DataToParams do
  @moduledoc ~S"""
  Converts params in the JSON api format into flat params convenient for
  changeset casting.
  """
  @spec process(map) :: map
  def process(%{"data" => _} = incoming) do
    incoming
    |> flatten_incoming()
    |> process_included()
    |> process_relationships()
    |> process_attributes()
  end
  def process(incoming) do
    incoming
  end

  defp flatten_incoming(%{"data" => data} = incoming) do
    Map.merge(incoming, data)
    |> Map.drop(["data"])
  end

  ## Attributes

  defp process_attributes(%{"attributes" => nil} = data) do
    Map.drop(data, ["attributes"])
  end
  defp process_attributes(%{"attributes" => attributes} = data) do
    Map.merge(data, attributes)
    |> Map.drop(["attributes"])
  end
  defp process_attributes(data), do: data

  ## Relationships

  defp process_relationships(%{"relationships" => nil} = data) do
    Map.drop(data, ["relationships"])
  end
  defp process_relationships(%{"relationships" => relationships} = data) do
    result =
      Enum.reduce(relationships, %{}, fn
        {key, %{"data" => nil}}, acc ->
          Map.put(acc, "#{key}-id", nil)

        {key, %{"data" => %{"id" => id}}}, acc ->
          Map.put(acc, "#{key}-id", id)
      end)

    Map.merge(data, result)
    |> Map.drop(["relationships"])
  end
  defp process_relationships(data), do: data

  ## Included

  defp process_included(%{"included" => nil} = incoming) do
    Map.drop(incoming, ["included"])
  end
  defp process_included(%{"included" => included} = incoming) do
    result =
      Enum.reduce(
        included,
        incoming,
        fn (%{"data" => %{"type" => type}} = params, acc) ->
          flattened = process(params)
          case Map.has_key?(acc, type) do
            false -> Map.put(acc, type, [flattened])
            true -> Map.update(acc, type, flattened, &([flattened | &1]))
          end
      end)

    Map.drop(result, ["included"])
  end
  defp process_included(incoming), do: incoming
end
