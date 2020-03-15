defmodule JSONAPI.Utils.DataToParams do
  @moduledoc ~S"""
  Converts a Map representation of the JSON:API resource object format into a flat Map convenient for
  changeset casting.
  """
  alias JSONAPI.Utils.String, as: JString

  @spec process(map) :: map
  def process(%{"data" => nil}), do: nil
  def process(%{"data" => _} = incoming) do
    incoming
    |> flatten_incoming()
    |> process_included()
    |> process_relationships()
    |> process_attributes()
  end
  def process(incoming), do: incoming

  defp flatten_incoming(%{"data" => data}) when is_list(data) do
    data
  end
  defp flatten_incoming(%{"data" => data} = incoming) do
    incoming
    |> Map.merge(data)
    |> Map.drop(["data"])
  end

  ## Attributes

  defp process_attributes(%{"attributes" => nil} = data) do
    Map.drop(data, ["attributes"])
  end
  defp process_attributes(%{"attributes" => attributes} = data) do
    data
    |> Map.merge(attributes)
    |> Map.drop(["attributes"])
  end
  defp process_attributes(data), do: data

  ## Relationships

  defp process_relationships(%{"relationships" => nil} = data) do
    Map.drop(data, ["relationships"])
  end
  defp process_relationships(%{"relationships" => relationships} = data) do
    relationships
    |> Enum.reduce(%{}, fn
      {key, %{"data" => nil}}, acc ->
        Map.put(acc, transform_fields("#{key}-id"), nil)

      {key, %{"data" => %{"id" => id}}}, acc ->
        Map.put(acc, transform_fields("#{key}-id"), id)

      {key, %{"data" => list}}, acc when is_list(list) ->
        Map.put(acc, transform_fields("#{key}-id"), Enum.map(list, &(Map.get(&1, "id"))))
    end)
    |> Map.merge(data)
    |> Map.drop(["relationships"])
  end
  defp process_relationships(data), do: data

  ## Included

  defp process_included(%{"included" => nil} = incoming) do
    Map.drop(incoming, ["included"])
  end
  defp process_included(%{"included" => included} = incoming) do
    included
    |> Enum.reduce(incoming, fn (%{"data" => %{"type" => type}} = params, acc) ->
        flattened = process(params)
        case Map.has_key?(acc, type) do
          false -> Map.put(acc, type, [flattened])
          true -> Map.update(acc, type, flattened, &([flattened | &1]))
        end
    end)
    |> Map.drop(["included"])
  end
  defp process_included(incoming), do: incoming

  defp transform_fields(fields) do
    case JString.field_transformation() do
      :camelize -> JString.expand_fields(fields, &JString.camelize/1)
      :dasherize -> JString.expand_fields(fields, &JString.dasherize/1)
      _ -> fields
    end
  end
end
