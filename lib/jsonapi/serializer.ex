defmodule JSONAPI.Serializer do
  import Ecto.Association, only: [loaded?: 1]

  def serialize(view, data, conn) do
    {to_include, encoded_data} = encode_data(view, data, conn)
    included = flatten_included(to_include)
    %{
      links: %{},
      data: encoded_data,
      included: included
    }
  end

  def encode_data(view, data, conn) when is_list(data) do
    Enum.map_reduce(data,[], fn(d, acc) ->
      {to_include, encoded_data} = encode_data(view, d, conn)
      {to_include, acc ++ [encoded_data]}
    end)
  end

  def encode_data(view, data, conn) do
    doc = %{
      id: view.id(data),
      type: view.type(),
      attributes: view.attributes(data, conn),
      relationships: %{},
      links: %{
        self: view.url_for(data, conn)
      }
    }

    valid_includes = get_valid_includes(view, conn)

    Enum.map_reduce(valid_includes, doc, fn({key, rel_view}, acc) ->
      rel_data = data[key]
      if loaded?(rel_data) && (!is_nil(rel_data) || !Enum.empty(rel_data)) do
        rel_url = view.url_for_rel(data, rel_view.type(), conn)
        acc = put_in(acc, [:relationships, key], encode_relation(rel_view, rel_data, rel_url, conn))

        {rel_included, encoded_rel} = encode_data(rel_view, rel_data, conn)
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

  def flatten_included(included) do    
    List.flatten(included)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(fn(i) -> "#{i[:type]}-#{i[:id]}" end) #TODO Better way to do this?
  end

  # TODO Grab the includes from the query parser config, then build the view tree appropiately.
  def get_valid_includes(view, nil), do: view.includes
  def get_valid_includes(view, conn) do
    include = get_in(conn.assigns, [:jsonapi_query, :includes])
    if is_nil(include) do
      view.includes()
    end
  end
end
