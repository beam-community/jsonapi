defmodule JSONAPI.Serializer do
  @moduledoc """
  Serialize a map of data into a properly formatted JSON API response object
  """

  import JSONAPI.Ecto, only: [assoc_loaded?: 1]

  alias JSONAPI.{Config, Utils}
  alias Utils.String, as: JString

  require Logger

  @typep serialized_doc :: map()

  @doc """
  Takes a view, data and a optional plug connection and returns a fully JSONAPI Serialized document.
  This assumes you are using the JSONAPI.View and have data in maps or structs.

  Please refer to `JSONAPI.View` for more information. If you are in interested in relationships
  and includes you may also want to reference the `JSONAPI.QueryParser`.
  """
  @spec serialize(module(), term(), Plug.Conn.t() | nil, map() | nil, map() | nil) :: serialized_doc()
  def serialize(view, data, conn \\ nil, meta \\ nil, page \\ nil) do
    {query_includes, query_page} =
      case conn do
        %Plug.Conn{assigns: %{jsonapi_query: %Config{include: include, page: page}}} ->
          {include, page}

        _ ->
          {[], nil}
      end

    {to_include, encoded_data} = encode_data(view, data, conn, query_includes)

    encoded_data = %{
      data: encoded_data,
      included: flatten_included(to_include)
    }

    encoded_data =
      if is_map(meta) do
        Map.put(encoded_data, :meta, meta)
      else
        encoded_data
      end

    merge_links(encoded_data, data, view, conn, query_page, remove_links?())
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
      attributes: transform_fields(view.attributes(data, conn)),
      relationships: %{}
    }

    doc = merge_links(encoded_data, data, view, conn, nil, remove_links?())

    doc =
      case view.meta(data, conn) do
        nil -> doc
        meta -> Map.put(doc, :meta, meta)
      end

    encode_relationships(conn, doc, {view, data, query_includes, valid_includes})
  end

  @spec encode_relationships(Plug.Conn.t(), serialized_doc(), tuple()) :: tuple()
  def encode_relationships(conn, doc, {view, data, _, _} = view_info) do
    view.relationships()
    |> Enum.filter(&data_loaded?(Map.get(data, elem(&1, 0))))
    |> Enum.map_reduce(doc, &build_relationships(conn, view_info, &1, &2))
  end

  @spec build_relationships(Plug.Conn.t(), tuple(), tuple(), tuple()) :: tuple()
  def build_relationships(
        conn,
        {view, data, query_includes, valid_includes},
        {key, include_view},
        acc
      ) do
    rel_view =
      case include_view do
        {view, :include} -> view
        view -> view
      end

    rel_data = Map.get(data, key)

    # Build the relationship url
    rel_key = transform_fields(key)
    rel_url = view.url_for_rel(data, rel_key, conn)

    # Build the relationship
    acc =
      put_in(
        acc,
        [:relationships, rel_key],
        encode_relation({rel_view, rel_data, rel_url, conn})
      )

    valid_include_view = include_view(valid_includes, key)

    if {rel_view, :include} == valid_include_view && data_loaded?(rel_data) do
      rel_query_includes =
        if is_list(query_includes) do
          query_includes
          |> Enum.reduce([], fn
            {^key, value}, acc -> acc ++ [value]
            _, acc -> acc
          end)
          |> List.flatten()
        else
          []
        end

      {rel_included, encoded_rel} = encode_data(rel_view, rel_data, conn, rel_query_includes)
      {rel_included ++ [encoded_rel], acc}
    else
      {nil, acc}
    end
  end

  defp include_view(valid_includes, key) when is_list(valid_includes) do
    valid_includes
    |> Keyword.get(key)
    |> generate_view_tuple
  end

  defp include_view(view, _key), do: generate_view_tuple(view)

  defp generate_view_tuple({view, :include}), do: {view, :include}
  defp generate_view_tuple(view) when is_atom(view), do: {view, :include}

  @spec data_loaded?(map() | list()) :: boolean()
  def data_loaded?(rel_data) do
    assoc_loaded?(rel_data) && (is_map(rel_data) || is_list(rel_data))
  end

  @spec encode_relation(tuple()) :: map()
  def encode_relation({rel_view, rel_data, _rel_url, _conn} = info) do
    data = %{
      data: encode_rel_data(rel_view, rel_data)
    }

    merge_related_links(data, info, remove_links?())
  end

  defp merge_base_links(%{links: links} = doc, data, view, conn) do
    view_links =
      data
      |> view.links(conn)
      |> Map.merge(links)
      |> Map.merge(%{self: view.url_for(data, conn)})

    Map.merge(doc, %{links: view_links})
  end

  defp merge_links(doc, data, view, conn, nil, false) do
    doc
    |> Map.merge(%{links: %{}})
    |> merge_base_links(data, view, conn)
  end

  defp merge_links(doc, data, view, conn, page, false) do
    doc
    |> Map.merge(%{links: view.pagination_links(data, conn, page)})
    |> merge_base_links(data, view, conn)
  end

  defp merge_links(doc, _data, _view, _conn, _page, _remove_links), do: doc

  defp merge_related_links(
         encoded_data,
         {rel_view, rel_data, rel_url, conn},
         false = _remove_links
       ) do
    Map.merge(encoded_data, %{links: %{self: rel_url, related: rel_view.url_for(rel_data, conn)}})
  end

  defp merge_related_links(encoded_rel_data, _info, _remove_links), do: encoded_rel_data

  @spec encode_rel_data(module(), map() | list()) :: map() | nil
  def encode_rel_data(_view, nil), do: nil

  def encode_rel_data(view, data) when is_list(data) do
    Enum.map(data, &encode_rel_data(view, &1))
  end

  def encode_rel_data(view, data) do
    %{
      type: view.type(),
      id: view.id(data)
    }
  end

  # Flatten and unique all the included objects
  @spec flatten_included(keyword()) :: keyword()
  def flatten_included(included) do
    included
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp get_includes(view, query_includes) do
    includes = get_default_includes(view) ++ get_query_includes(view, query_includes)
    Enum.uniq(includes)
  end

  defp get_default_includes(view) do
    rels = view.relationships()

    Enum.filter(rels, fn
      {_k, {_v, :include}} -> true
      _ -> false
    end)
  end

  defp get_query_includes(view, query_includes) do
    rels = view.relationships()

    query_includes
    |> Enum.map(fn
      {include, _} -> Keyword.take(rels, [include])
      include -> Keyword.take(rels, [include])
    end)
    |> List.flatten()
  end

  defp remove_links?, do: Application.get_env(:jsonapi, :remove_links, false)

  defp transform_fields(fields) do
    case JString.field_transformation() do
      :camelize -> JString.expand_fields(fields, &JString.camelize/1)
      :dasherize -> JString.expand_fields(fields, &JString.dasherize/1)
      _ -> fields
    end
  end
end
