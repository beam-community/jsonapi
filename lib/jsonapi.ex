defmodule JSONAPI do
  @moduledoc """
  This module is designed to work with a Phoenix application. You give it a view,
  an Ecto model, and a Plug.Conn or an Endpoint from your Phoenix application and it will spit
  out a map to be rendered by Poison.

  """
  import Ecto, only: [assoc_loaded?: 1]

  @doc """
  Encodes a single map and its associations according to the view module's callbacks.

    JSONAPI.show(UserView, user_model, conn)

  will return a map formatted in the JSONAPI Spec, which then can be encoded using
  your prefered JSON encoder.
  """
  @spec show(module, Map, Plug.Conn.t, Map) :: Map
  def show(mod, data, conn, _params) do
    base_doc()
    |> data_one(data, mod, conn)
    |> handle_includes()
  end

  @doc """
  Encodes a single map and its associations according to the view module's callbacks.

    JSONAPI.index(UserView, user_model)

  will return a map formatted in the JSONAPI Spec, which then can be encoded using
  your prefered JSON encoder.
  """
  @spec index(module, Map, Module.t | Plug.Conn.t, Map) :: Map
  def index(mod, data, conn_or_endpoint, params) do

    base_doc()
    |> data_many(data, params, mod)
    |> handle_includes()
  end

  defp data_many(doc, data, _params, mod) do
    {encoded_data, to_include} = Enum.reduce(data, {[], []}, fn(d, {a_data, a_included}) ->
      {encoded_doc, include} = encode(d, mod)
      {nil, {a_data ++ [encoded_doc], a_included ++ include}}
    end)

    doc = Map.put(doc, :data, encoded_data)

    {doc, to_include}
  end

  defp data_one(doc, data, mod, conn) do
    {encoded_data, included} = encode(data, mod)

    doc = doc
    |> Map.put(:data, encoded_data)
    |> Map.put(:links, %{self: mod.url_for(data, conn)})

    {doc, included}
  end



  @spec encode(Map, module) :: {Map, list(Map)}
  defp encode(data, mod) do
    %{rel: rel, include: included} = handle_relationships(data, mod)

    {%{
        id: mod.id(data),
        type: mod.type(),
        attributes: mod.attributes(data),
        relationships: rel,
        links: %{}
      }, included}
  end

  @spec handle_relationships(Map, module) :: Map | no_return
  @spec handle_relationships(Map, module, list) :: Map | no_return
  defp handle_relationships(data, mod), do: handle_relationships(data, mod, [])
  defp handle_relationships(data, mod, included) do
    Enum.reduce(mod.relationships(), %{rel: %{}, include: included}, fn({key, val}, acc) ->
      view = Map.get(val, :view, nil)
      unless view do
        raise "View is a required relationship parameter"
      end

      assoc_data = Map.get(data, key)
      rel_data = nil

      rel_data = if assoc_loaded?(assoc_data) do
        as_relationship(assoc_data, view)
      else
        map_key = String.to_atom("#{key}_id")

        if Map.has_key?(data, map_key) do
          id = Map.get(data, map_key)
          as_relationship(id, view)
        else
          []
        end
      end

      acc = put_in(acc, [:rel, key],%{
        links: %{},  #todo figure out params here ¯\_(ツ)_/¯
        data: rel_data
      })

      if assoc_loaded?(assoc_data) && rel_data do
        data = Map.put(val, :data, assoc_data)
        Map.update!(acc, :include, fn(v) -> v ++ [data] end)
      else
        acc
      end
    end)
  end

  @spec handle_includes({Map, list(Map)}) :: Map
  @spec handle_includes({Map, list(Map)}, HashSet.t) :: Map
  defp handle_includes(data), do: handle_includes(data, HashSet.new)
  # Done processing
  defp handle_includes({document, []}, _processed_includes), do: document
  defp handle_includes({document, [%{:data => []} | includes] }, processed_includes) do
    handle_includes({document, includes}, processed_includes)
  end
  defp handle_includes({document, [%{:data => nil} | includes] }, processed_includes) do
    handle_includes({document, includes}, processed_includes)
  end
  defp handle_includes({document, [include_to_process | includes] }, processed_includes) do
    # Get the data element from the list. Process it's first item if a list
    data = Map.get(include_to_process, :data)

    unless is_list(data) do
      data = [data]
    end
    [data | rest] = data

    # since we took the first element off data, we need to make sure that the rest have the metadata they need
    rest = Enum.map(rest, &(Dict.put(include_to_process, :data, &1)))

    # Generate a key based on type and id to be used to check unique
    view = Map.get(include_to_process, :view)
    type = view.type()
    id = Map.get(data, :id)
    key = "#{type}_#{id}"

    # Check if processed already.
    if Set.member?(processed_includes, key) do
      # Recurse through the list. Adding the "rest" of the current includes first
      handle_includes({document, rest ++ includes}, processed_includes)
    else
      # Not been processed. Lets encode the data and recurse through the west.
      {doc, included} = encode(data, view)
      document = Map.update!(document, :included, fn(val) -> val ++ [doc] end)
      includes = rest ++ includes ++ included

      handle_includes({document, includes}, Set.put(processed_includes, key))
    end
  end


  defp base_doc() do
  end

  defp as_relationship(nil, mod), do: nil
  defp as_relationship([], _mod), do: %{}
  defp as_relationship(data, mod) when is_list(data) do
    Enum.map(data, &(as_relationship(&1, mod)))
  end
  defp as_relationship(d, mod) when is_integer(d) do
    as_relationship(Integer.to_string(d), mod)
  end
  defp as_relationship(d, mod) when is_binary(d) do
    %{
      type: mod.type(),
      id: d
    }
  end
  defp as_relationship(d, mod) do
    %{
      type: mod.type(),
      id: mod.id(d)
    }
  end
end
