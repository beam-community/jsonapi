defmodule JSONAPI.Serializer do
  import Ecto.Association, only: [loaded?: 1]

  @doc """
  Takes a view, data and a optional plug connection and returns a fully JSONAPI Serialized document.
  This assumes you are using the JSONAPI.View and have data in maps or structs. 


  """
  def serialize(view, data, conn \\ nil) do
    query_includes = if is_nil(conn) do
      []
    else
      conn.assigns[:jsonapi_query][:includes]
    end

    {to_include, encoded_data} = encode_data(view, data, conn, query_includes)

    included = flatten_included(to_include)
    %{
      links: %{},
      data: encoded_data,
      included: included
    }
  end

  def encode_data(view, data, conn, query_includes) when is_list(data) do
    Enum.map_reduce(data,[], fn(d, acc) ->
      {to_include, encoded_data} = encode_data(view, d, conn, query_includes)
      {to_include, acc ++ [encoded_data]}
    end)
  end

  def encode_data(view, data, conn, query_includes) do
    valid_includes = get_valid_includes(view, query_includes)

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
    Enum.map_reduce(valid_includes, doc, fn({key, rel_view}, acc) ->
      rel_data = Map.get(data, key)   
      if loaded?(rel_data) && (!is_nil(rel_data) || !Enum.empty(rel_data)) do #Check if we can handle this
        # Build the relationship url
        rel_url = view.url_for_rel(data, rel_view.type(), conn) 
        # Build the relationship
        acc = put_in(acc, [:relationships, key], encode_relation(rel_view, rel_data, rel_url, conn)) 

        # Begin handling the relationship recursion for encoding includes
        rel_query_includes = Keyword.get(query_includes, key, []) 
        {rel_included, encoded_rel} = encode_data(rel_view, rel_data, conn, rel_query_includes)
        {rel_included ++ [encoded_rel], acc}
      else
        {nil, acc}
      end
    end)
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

  def encode_rel_data(view, data) when is_list(data) do
    Enum.map(data, fn(d) ->
      encode_rel_data(view, d)
    end)
  end
  def encode_rel_data(view, data) do
    %{
      type: view.type(),
      id: view.id(data)
    }
  end

  # Flatten and unique all the included objects
  def flatten_included(included) do    
    List.flatten(included)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(fn(i) -> "#{i[:type]}-#{i[:id]}" end) #TODO Better way to do this?
  end

  # This makes a mapping between includes from the query parser and includes in the view. 
  def get_valid_includes(view, nil), do: view.includes()
  def get_valid_includes(view, []), do: view.includes()
  def get_valid_includes(view, query_includes) do
    base=view.includes()
    Enum.reduce(query_includes, [], fn({key, _val}, acc) ->
      Keyword.put(acc, key, Keyword.get(base, key))
    end)
  end
end
