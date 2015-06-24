defmodule JSONAPI do
  @moduledoc """
  This module is designed to work with a Phoenix Application. You give it a View,
  an Ecto model, and a Plug.Conn from a phoenix endpoint and it will spit out a map
  to be rendered by Poison. 

  """
  import Ecto.Association, only: [loaded?: 1]

  @doc """
  Encodes a single map and its associations according to the view module's callbacks.

    JSONAPI.show(UserView, user_model, conn)
  
  will return a map formatted in the JSONAPI Spec, which then can be encoded using
  your prefered JSON encoder.
  """
  @spec show(module, Map, Plug.Conn.t, Map) :: Map
  def show(mod, data, _conn, _params) do
    base_doc()
    |> data_one(data, mod)
    |> handle_includes()
  end

  @doc """
  Encodes a single map and its associations according to the view module's callbacks.

    JSONAPI.index(UserView, user_model)
  
  will return a map formatted in the JSONAPI Spec, which then can be encoded using
  your prefered JSON encoder.
  """
  @spec show(module, Map, Plug.Conn.t, Map) :: Map
  def index(mod, data, conn, params) do
    endpoint = Phoenix.Controller.endpoint_module(conn)

    base_doc()
    |> data_many(data, params, mod)
    |> handle_includes()
    |> handle_paging(mod, Map.drop(params, ["format", :sort, "filter"]), endpoint)
  end

  defp data_many(doc, data, _params, mod) do
    {_dc, {total_data, total_included}} = Enum.map_reduce(data, {[], []}, fn(d, {a_data, a_included}) ->
      {encoded_doc, include} = encode(d, mod)
      {nil, {a_data ++ [encoded_doc], a_included ++ include}}
    end)
     
    {Dict.put(doc, :data, total_data), total_included}
  end

  defp data_one(doc, data, mod) do
    {data, included} = encode(data, mod)
    {Dict.put(doc, :data, data), included}
  end

  defp as_relationship(nil, mod), do: nil
  defp as_relationship([], _mod), do: []
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

      rel_data = if loaded?(assoc_data) do
        as_relationship(assoc_data, view)
      else
        map_key = get_assoc_key(key)

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

      if loaded?(assoc_data) && rel_data do
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

  defp handle_paging(doc, mod, params, endpoint) do
    links = %{
      self: mod.url_func().(endpoint, :index, params),
    }

    page_number = get_in(params, [:page, :number])
    page_size  = get_in(params, [:page, :size])
    resources = Map.get(doc, :data, [])

    if page_number && page_size do

      if Enum.count(resources) == page_size do
        next_page = mod.url_func().(endpoint, :index, put_in(params, [:page, :number], page_number+1))
        links = Dict.put(links, :next_page, next_page)
      end

      if page_number > 0 do
        previous_page = mod.url_func().(endpoint, :index, put_in(params, [:page, :number], page_number-1))
        links = Dict.put(links, :previous_page, previous_page)
      end

      links = Map.get(doc, :links, %{}) |> Map.merge(links)
    end

    Map.put(doc, :links, links)
  end

  defp base_doc() do
    %{
      links: %{},
      data: [],
      included: [] 
    }
  end

  defp get_assoc_key(key) do
    map_key = Atom.to_string(key)

    if String.ends_with?(map_key, "s") do
      map_key = String.rstrip(map_key, ?s)
    end

    map_key= String.to_existing_atom("#{map_key}_id")
  end
end

