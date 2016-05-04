defmodule JSONAPI.Serializer do
  import JSONAPI.Ecto, only: [assoc_loaded?: 1]

  @doc """
  Takes a view, data and a optional plug connection and returns a fully JSONAPI Serialized document.
  This assumes you are using the JSONAPI.View and have data in maps or structs.

  Please refer to `JSONAPI.View` for more information. If you are in interested in relationships
  and includes you may also want to reference the `JSONAPI.QueryParser`.
  """
  def serialize(view, data, conn \\ nil) do
    query_includes = case conn do
      %Plug.Conn{assigns: %{jsonapi_query: %{includes: includes}}} -> includes
      _ -> []
    end

    {to_include, encoded_data} = encode_data(view, data, conn, query_includes)
    
    %{
      links: %{},
      data: encoded_data,
      included: flatten_included(to_include)
    }
  end

  def encode_data(view, data, conn, query_includes) when is_list(data) do
    Enum.map_reduce(data, [], fn d, acc ->
      {to_include, encoded_data} = encode_data(view, d, conn, query_includes)
      {to_include, acc ++ [encoded_data]}
    end)
  end

  def encode_data(view, data, conn, query_includes) do
    valid_includes = get_includes(view, query_includes)

    # Encode the data
    doc = %{
      id: view.id(data),
      type: view.type(),
      attributes: view.attributes(data, conn),
      relationships: %{},
      links: %{
        self: view.url_for(data, conn)
      }
    }

    # Handle all the relationships
    Enum.map_reduce(view.relationships(), doc, fn({key, include_view}, acc) ->

      rel_view = case include_view do
        {view, :include} -> view
        view -> view
      end

      rel_data = Map.get(data, key)

      only_rel_view = get_view(rel_view)
      # Build the relationship url
      rel_url = view.url_for_rel(data, key, conn)
      # Build the relationship
      acc = put_in(acc, [:relationships, key], encode_relation(only_rel_view, rel_data, rel_url, conn))

      valid_include_view =
        case valid_includes do
          list when is_list(list) ->
            case Keyword.get(valid_includes, key) do
              {view, :include} -> {view, :include}
              view -> {view, :include}
            end
          {view, :include} -> {view, :include}
          view -> {view, :include}
        end

      if {rel_view, :include} == valid_include_view && is_data_loaded?(rel_data) do
        rel_query_includes = 
          if is_list(query_includes) do
            Keyword.get(query_includes, key, [])
          else
            []
          end
        #TODO Possibly only return a list of data + view, and encode it after the fact once instead of N times.
        {rel_included, encoded_rel} = encode_data(rel_view, rel_data, conn, rel_query_includes)
        {rel_included ++ [encoded_rel], acc}
      else
        {nil, acc}
      end
    end)
  end

  def is_data_loaded?(rel_data) do
    assoc_loaded?(rel_data) && (is_map(rel_data) || (is_list(rel_data) && !Enum.empty?(rel_data)))
  end

  def encode_relation(rel_view, rel_data, rel_url, conn) do
    %{
      links: %{
        self: rel_url,
        related: rel_view.url_for(rel_data, conn)
      },
      data: encode_rel_data(rel_view, rel_data)
    }
  end

  def encode_rel_data(_view, nil), do: nil
  def encode_rel_data(view, data) when is_list(data) do
    Enum.map data, &(encode_rel_data(view, &1))
  end
  def encode_rel_data(view, data) do
    %{
      type: view.type(),
      id: view.id(data)
    }
  end

  # Flatten and unique all the included objects
  def flatten_included(included) do
    included
    |> List.flatten
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq
  end

  # This makes a mapping between includes from the query parser and includes in the view.
  defp get_includes(view, nil), do: view.relationships()
  defp get_includes(view, []), do: view.relationships()
  defp get_includes(view, query_includes) when is_list(query_includes) do
    base = view.relationships()
    Enum.reduce(query_includes, [], &(handle_include(base, &1, &2)))
  end
  defp get_includes(view, include) do
    base = view.relationships()
    Keyword.get(base, include)
  end

  defp handle_include(base, {parent, child}, acc) do
    view = Keyword.get(base, parent)
    acc = Keyword.put(acc, parent, view)
    handle_include(view, child, acc)
  end
  defp handle_include({base, :include}, child, acc) do
    handle_include(base.relationships(), child, acc)
  end
  defp handle_include(base, child, acc) do
    view = if is_list(base), do: Keyword.get(base, child), else: base
    Keyword.put(acc, child, view)
  end

  def get_view({view, :include}), do: view
  def get_view(view), do: view
end
