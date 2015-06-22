defmodule JSONAPI do
  @moduledoc """
  This module is designed to work with a Phoenix Application. You give it an View,
  a Ecto model, and a Plug.Conn from a phoenix endpoint and it will spit out a map
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
    {Dict.put(doc, :data, [data]), included}
  end

  defp as_relationship(data, mod) when is_list(data) do
    Enum.map(data, &(as_relationship(&1, mod)))
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
      #TODO Here we should check if optional and error if not. Possible to move into its own function
      #TODO Breakout into functions

      if loaded?(assoc_data) && !is_nil(assoc_data) || (is_list(assoc_data) && assoc_data != []) do
        if is_list(assoc_data) do
          rel_data = Enum.map(assoc_data, &(as_relationship(&1, view)))
        else
          rel_data = as_relationship(assoc_data, view)
        end

        put_in(acc, [:rel, key],%{
          links: %{},  #TODO Figure out params here ¯\_(ツ)_/¯
          data: rel_data
        }) |> Map.update!(:include, fn(v) -> v ++ [Map.put(val, :data, assoc_data)] end)
      else
        optional = Map.get(val, :optional, false)
        if optional do
          acc
        else
          put_in(acc, [:rel, key],%{
            links: %{},  #TODO Figure out params here ¯\_(ツ)_/¯
            data: nil
          })
        end
      end
    end)
  end

  @spec handle_includes({Map, list(Map)}) :: Map 
  @spec handle_includes({Map, list(Map)}, HashSet.t) :: Map
  defp handle_includes(data), do: handle_includes(data, HashSet.new) 
  # Done processing
  defp handle_includes({document, []}, _processed_includes), do: document
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

    number = get_in(params, [:page, :number])
    page_size  = get_in(params, [:page, :size])
    resources = Map.get(doc, :data, [])

    if number && page_size do

      if Enum.count(resources) == page_size do
        next_page = mod.url_func().(endpoint, :index, put_in(params, [:page, :number], number+1))
        links = Dict.put(links, :next_page, next_page)
      else
      end

      if number > 0 do
        previous_page = mod.url_func().(endpoint, :index, put_in(params, [:page, :number], number-1))
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
end

