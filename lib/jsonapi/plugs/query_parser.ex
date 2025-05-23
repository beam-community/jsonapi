defmodule JSONAPI.QueryParser do
  @moduledoc """
  Implements a fully JSONAPI V1 spec for parsing a complex query string via the
  `query_params` field from a `Plug.Conn` struct and returning Elixir datastructures.
  The purpose is to validate and encode incoming queries and fail quickly.

  Primarialy this handles:
    * [sorts](http://jsonapi.org/format/#fetching-sorting)
    * [include](http://jsonapi.org/format/#fetching-includes)
    * [filtering](http://jsonapi.org/format/#fetching-filtering)
    * [sparse fieldsets](https://jsonapi.org/format/#fetching-sparse-fieldsets)
    * [pagination](http://jsonapi.org/format/#fetching-pagination)

  This Plug works in conjunction with a `JSONAPI.View` as well as some Plug
  defined configuration.

  In your controller you may add:

  ```
  plug JSONAPI.QueryParser,
    filter: ~w(title),
    sort: ~w(created_at title),
    include: ~w(others) # optionally specify a list of allowed includes.
    view: MyView
  ```

  If you specify which includes are allowed, any include name not in the list
  will produce an error. If you omit the `include` list then all relationships
  specified by the given resource will be allowed.

  If your controller's index function receives a query with params inside those
  bounds it will build a `JSONAPI.Config` that has all the validated and parsed
  fields for your usage. The final configuration will be added to assigns
  `jsonapi_query`.

  The final output will be a `JSONAPI.Config` struct and will look similar to the
  following:

      %JSONAPI.Config{
        view: MyView,
        opts: [view: MyView, sort: ["created_at", "title"], filter: ["title"]],
        sort: [desc: :created_at] # Easily insertable into an ecto order_by,
        filter: [title: "my title"] # Easily reduceable into ecto where clauses
        include: [comments: :user] # Easily insertable into a Repo.preload,
        fields: %{"myview" => [:id, :text], "comment" => [:id, :body],
        page: %{
          limit: limit,
          offset: offset,
          page: page,
          size: size,
          cursor: cursor
        }}
      }

  The final result should allow you to build a query quickly and with little overhead.

  ## Sparse Fieldsets

  Sparse fieldsets are supported. By default your response will include all
  available fields. Note that the query to your database is left to you. Should
  you want to query your DB for specific fields `JSONAPI.Config.fields` will
  return the requested fields for each resource (see above example).

  ## Options
    * `:view` - The JSONAPI View which is the basis for this plug.
    * `:sort` - List of atoms which define which fields can be sorted on.
    * `:filter` - List of atoms which define which fields can be filtered on.

  ## Dasherized Fields

  Note that if your API is returning dasherized fields (e.g. `"dog-breed": "Corgi"`)
  we recommend that you include the `JSONAPI.UnderscoreParameters` Plug in your
  API's pipeline with the `replace_query_params` option set to `true`. This will
  underscore fields for easier operations in your code.

  For more details please see `JSONAPI.UnderscoreParameters`.
  """
  @behaviour Plug

  import JSONAPI.Utils.IncludeTree
  import JSONAPI.Utils.String, only: [underscore: 1]

  alias JSONAPI.Exceptions.InvalidQuery
  alias JSONAPI.{Config, Deprecation}
  alias Plug.Conn

  @impl Plug
  def init(opts) do
    build_config(opts)
  end

  @impl Plug
  def call(conn, opts) do
    query_params_config_struct =
      conn
      |> Conn.fetch_query_params()
      |> Map.get(:query_params)
      |> struct_from_map(%Config{})

    config =
      opts
      |> parse_fields(query_params_config_struct.fields)
      |> parse_include(query_params_config_struct.include)
      |> parse_filter(query_params_config_struct.filter)
      |> parse_sort(query_params_config_struct.sort)
      |> parse_pagination(query_params_config_struct.page)

    Conn.assign(conn, :jsonapi_query, config)
  end

  def parse_pagination(config, map) when map_size(map) == 0, do: config

  def parse_pagination(%Config{} = config, page), do: Map.put(config, :page, page)

  @spec parse_filter(Config.t(), keyword()) :: Config.t()
  def parse_filter(config, map) when map_size(map) == 0, do: config

  def parse_filter(%Config{opts: opts} = config, filter) do
    opts_filter = Keyword.get(opts, :filter, [])

    Enum.reduce(filter, config, fn {key, val}, acc ->
      check_filter_allowed!(opts_filter, key, config)

      keys = key |> String.split(".") |> Enum.map(&String.to_existing_atom/1)
      filter = deep_merge(acc.filter, put_as_tree([], keys, val))
      %{acc | filter: filter}
    end)
  end

  defp check_filter_allowed!(filters, key, config) do
    unless key in filters do
      raise InvalidQuery, resource: config.view.type(), param: key, param_type: :filter
    end
  end

  @spec parse_fields(Config.t(), map()) :: Config.t() | no_return()
  def parse_fields(%Config{} = config, fields) when fields == %{}, do: config

  def parse_fields(%Config{} = config, fields) do
    Enum.reduce(fields, config, fn {type, value}, acc ->
      valid_fields =
        config
        |> get_valid_fields_for_type(type)
        |> Enum.into(MapSet.new())

      requested_fields =
        try do
          value
          |> String.split(",")
          |> Enum.filter(&(&1 !== ""))
          |> Enum.map(&underscore/1)
          |> Enum.into(MapSet.new(), &String.to_existing_atom/1)
        rescue
          ArgumentError -> raise_invalid_field_names(value, config.view.type())
        end

      size = MapSet.size(requested_fields)

      case MapSet.subset?(requested_fields, valid_fields) do
        # no fields if empty - https://jsonapi.org/format/#fetching-sparse-fieldsets
        false when size > 0 ->
          bad_fields =
            requested_fields
            |> MapSet.difference(valid_fields)
            |> MapSet.to_list()
            |> Enum.join(",")

          raise_invalid_field_names(bad_fields, config.view.type())

        _ ->
          %{acc | fields: Map.put(acc.fields, type, MapSet.to_list(requested_fields))}
      end
    end)
  end

  def parse_sort(config, nil), do: config

  def parse_sort(%Config{opts: opts} = config, sort_fields) do
    sorts =
      sort_fields
      |> String.split(",")
      |> Enum.map(fn field ->
        valid_sort = Keyword.get(opts, :sort, [])
        [_, direction, field] = Regex.run(~r/(-?)(\S*)/, field)

        unless field in valid_sort do
          raise InvalidQuery, resource: config.view.type(), param: field, param_type: :sort
        end

        build_sort(direction, String.to_existing_atom(field))
      end)
      |> List.flatten()

    %{config | sort: sorts}
  end

  def build_sort("", field), do: [asc: field]
  def build_sort("-", field), do: [desc: field]

  def parse_include(config, []), do: config

  def parse_include(%Config{} = config, include_str) do
    includes = handle_include(include_str, config)

    Map.put(config, :include, includes)
  end

  def handle_include(str, config) when is_binary(str) do
    valid_includes = get_base_relationships(config.view)

    includes =
      str
      |> String.split(",")
      |> Enum.filter(&(&1 !== ""))
      |> Enum.map(&underscore/1)

    Enum.reduce(includes, [], &include_reducer(config, valid_includes, &1, &2))
  end

  defp include_reducer(config, valid_includes, inc, acc) do
    # if an explicit list of allowed includes was specified, check this include
    # against it:
    check_include_allowed!(inc, config)

    if inc =~ ~r/\w+\.\w+/ do
      acc ++ handle_nested_include(inc, valid_includes, config)
    else
      inc =
        try do
          String.to_existing_atom(inc)
        rescue
          ArgumentError -> raise_invalid_include_query(inc, config.view.type())
        end

      # credo:disable-for-next-line
      if Enum.any?(valid_includes, fn {key, _val} -> key == inc end) do
        Enum.reverse([inc | acc])
      else
        raise_invalid_include_query(inc, config.view.type())
      end
    end
  end

  defp check_include_allowed!(key, %Config{opts: opts, view: view}) do
    if opts do
      check_include_allowed!(key, Keyword.get(opts, :include), view)
    end
  end

  defp check_include_allowed!(key, allowed_includes, view) when is_list(allowed_includes) do
    unless key in allowed_includes do
      raise_invalid_include_query(key, view.type())
    end
  end

  defp check_include_allowed!(_key, nil, _view) do
    # all includes are allowed if none are specified in input config
  end

  @spec handle_nested_include(key :: String.t(), valid_include :: list(), config :: Config.t()) ::
          list() | no_return()
  def handle_nested_include(key, valid_includes, config) do
    keys =
      try do
        key
        |> String.split(".")
        |> Enum.map(&String.to_existing_atom/1)
      rescue
        ArgumentError -> raise_invalid_include_query(key, config.view.type())
      end

    last = List.last(keys)
    path = Enum.slice(keys, 0, Enum.count(keys) - 1)

    if member_of_tree?(keys, valid_includes) do
      put_as_tree([], path, last)
    else
      raise_invalid_include_query(key, config.view.type())
    end
  end

  @spec get_valid_fields_for_type(Config.t(), String.t()) :: list(atom())
  def get_valid_fields_for_type(%Config{view: view}, type) do
    if type == view.type() do
      view.fields()
    else
      get_view_for_type(view, type).fields()
    end
  end

  @spec get_view_for_type(module(), String.t()) :: module() | no_return()
  def get_view_for_type(view, type) do
    case Enum.find(view.relationships(), fn relationship ->
           field_valid_for_relationship?(relationship, type)
         end) do
      {_, view} -> view
      nil -> raise_invalid_field_names(type, view.type())
    end
  end

  @spec field_valid_for_relationship?({atom(), module()}, String.t()) :: boolean()
  defp field_valid_for_relationship?({key, view}, expected_type) do
    cond do
      view.type() == expected_type ->
        true

      Atom.to_string(key) == expected_type ->
        Deprecation.warn(:query_parser_fields)
        true

      true ->
        false
    end
  end

  @spec raise_invalid_include_query(param :: String.t(), resource_type :: String.t()) ::
          no_return()
  defp raise_invalid_include_query(param, resource_type) do
    raise InvalidQuery, resource: resource_type, param: param, param_type: :include
  end

  @spec raise_invalid_field_names(bad_fields :: String.t(), resource_type :: String.t()) ::
          no_return()
  defp raise_invalid_field_names(bad_fields, resource_type) do
    raise InvalidQuery, resource: resource_type, param: bad_fields, param_type: :fields
  end

  defp build_config(opts) do
    view = Keyword.fetch!(opts, :view)
    struct(Config, opts: opts, view: view)
  end

  defp struct_from_map(params, struct) do
    processed_map =
      for {struct_key, _} <- Map.from_struct(struct), into: %{} do
        case Map.get(params, to_string(struct_key)) do
          nil -> {false, false}
          value -> {struct_key, value}
        end
      end

    struct(struct, processed_map)
  end
end
