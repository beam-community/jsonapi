defprotocol JSONAPI.Utils.ParamParser do
  @fallback_to_any true
  def parse(params)
end

defimpl JSONAPI.Utils.ParamParser, for: Any do
  def parse(data), do: data
end

defimpl JSONAPI.Utils.ParamParser, for: List do
  def parse(list), do: Enum.map(list, &JSONAPI.Utils.ParamParser.parse/1)
end

defimpl JSONAPI.Utils.ParamParser, for: Map do
  def parse(map) do
    Enum.reduce(map, %{}, fn {key, val}, map ->
      key = JSONAPI.Utils.String.underscore(key)
      Map.put(map, key, JSONAPI.Utils.ParamParser.parse(val))
    end)
  end
end
