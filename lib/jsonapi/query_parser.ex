defmodule JSONAPI.QueryParser do
  @behaviour Plug
  alias JSONAPI.Config
  import Plug.Conn

  # This is the big module that parses the query into a jsonapi config struct that
  # gets passed down to every subsequent jsonapi call. It's important we start at
  # the top.
  def init(opts) do
    build_config(opts)
  end

  def call(conn, opts) do
    query_params = conn.query_params

    config = opts
    |> parse_fields(Map.get(query_params, "fields", ""))
    |> parse_include(Map.get(query_params, "includes", ""))
    |> IO.inspect()

    # config is %JSONAPI.Config{ select....} basically everything parsed into elixir types 
    #assign(conn, :jsonapi_config, config)
  end

  def parse_fields(config, ""), do: config
  def parse_fields(%Config{opts: opts}=config, fields) do
  end

  def parse_include(config, ""), do: config
  def parse_include(%Config{opts: opts}=config, include_str) do
    includes = handle_include(include_str, opts[:include])
    Map.put(config, :include, includes)
  end

  def handle_include(str, valid_include) when is_binary(str) do
    String.split(str, ",")
    |> Enum.reduce([], fn(inc, acc) ->
      if inc =~ ~r/\w+\.\w+/ do
        acc ++ handle_nested_include(inc, valid_include)
      else
        inc = String.to_existing_atom(inc)
        if Enum.any?(valid_include, fn ({key, _val}) -> key == inc  
                                       (key) -> key == inc
                                    end) do
                                      
          acc ++ [inc]
        else
          raise "400 bad Request BAD KEYWORD"
        end
      end
    end)
  end

  def handle_nested_include(key, valid_include) do
    keys = String.split(key, ".")
    |> Enum.map(&String.to_existing_atom/1)

    last = List.last(keys)
    path = Enum.slice(keys, 0, Enum.count(keys)-1) 

    #If the path is allowed in the include we are good, gonna have to punt for now checking if we can select.
    if member_of_tree?(path, valid_include) do
      put_as_tree([], path, last)
    else
      raise "400 bad Request"
    end
  end

  def put_as_tree(acc, items, val) do
    [head | tail] = Enum.reverse(items)
    build_tree(Keyword.put([], head, val), tail)
  end

  def build_tree(acc, []), do: acc
  def build_tree(acc, [head | tail]) do
    build_tree(Keyword.put([], head, acc), tail)
  end


  def member_of_tree?([], _thing), do: true
  def member_of_tree?([path | tail], include) when is_list(include) do
    if Dict.has_key?(include, path) do
      member_of_tree?(tail, include[path])
    else 
      false 
    end
  end

  defp build_config(opts) do
    struct(JSONAPI.Config, opts: opts)
  end
end

