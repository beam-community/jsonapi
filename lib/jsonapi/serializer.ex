defmodule JSONAPI.Serializer do
  @moduledoc """
  Serialize a map of data into a properly formatted JSON API response object
  """

  import JSONAPI.Ecto, only: [assoc_loaded?: 1]
  alias JSONAPI.Utils.Underscore

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

    encoded_data = %{
      data: encoded_data,
      included: flatten_included(to_include)
    }
    merge_links(encoded_data, data, view, conn, remove_links?())
  end

  def encode_data(view, data, conn, query_includes) when is_list(data) do
    Enum.map_reduce(data, [], fn d, acc ->
      {to_include, encoded_data} = encode_data(view, d, conn, query_includes)
      {to_include, acc ++ [encoded_data]}
    end)
  end

  def encode_data(view, data, conn, query_includes) do
    valid_includes = get_includes(view, query_includes)

    encoded_data = %{
      id: view.id(data),
      type: view.type(),
      attributes: underscore(view.attributes(data, conn)),
      relationships: %{}
    }

    doc = merge_links(encoded_data, data, view, conn, remove_links?())

    doc =
      case view.meta(data, conn) do
        nil -> doc
        meta -> Map.put(doc, :meta, meta)
      end

    encode_relationships(conn, doc, {view, data, query_includes, valid_includes})
  end

  def encode_relationships(conn, doc, {view, _, _, _} = view_info) do
    rels = view.relationships()
    Enum.map_reduce(rels, doc, &build_relationships(conn, view_info, &1, &2))
  end

  def build_relationships(conn, {view, data, query_includes, valid_includes}, {key, include_view}, acc) do
    rel_view =
      case include_view do
        {view, :include} -> view
        view -> view
      end

    rel_data = Map.get(data, key)

    only_rel_view = get_view(rel_view)
    # Build the relationship url
    rel_url = view.url_for_rel(data, key, conn)
    # Build the relationship
    acc = put_in(acc, [:relationships, underscore(key)], encode_relation({only_rel_view, rel_data, rel_url, conn}))

    valid_include_view = include_view(valid_includes, key)

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
  end

  defp include_view(valid_includes, key) when is_list(valid_includes) do
    case Keyword.get(valid_includes, key) do
      {view, :include} -> {view, :include}
      _view -> false
    end
  end
  defp include_view({view, :include}, _key), do: {view, :include}
  defp include_view(_view, _key), do: false

  def is_data_loaded?(rel_data) do
    assoc_loaded?(rel_data) && (is_map(rel_data) || (is_list(rel_data) && !Enum.empty?(rel_data)))
  end

  def encode_relation({rel_view, rel_data, _rel_url, _conn} = info) do
    data = %{
      data: encode_rel_data(rel_view, rel_data)
    }
    merge_related_links(data, info, remove_links?())
  end

  defp merge_links(doc, data, view, conn, false) do
    Map.merge(doc, %{links: %{self: view.url_for(data, conn)}})
  end
  defp merge_links(doc, _data, _view, _conn, _remove_links), do: doc

  defp merge_related_links(encoded_data, {rel_view, rel_data, rel_url, conn}, false = _remove_links) do
    Map.merge(encoded_data, %{links: %{self: rel_url, related: rel_view.url_for(rel_data, conn)}})
  end
  defp merge_related_links(encoded_rel_data, _info, _remove_links), do: encoded_rel_data

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

  def underscore(data) do
    if Underscore.underscore?() do
      Underscore.underscore(data)
    else
      data
    end
  end

  defp remove_links?, do: Application.get_env(:jsonapi, :remove_links, false)
end