defmodule JSONAPI.View do
  @moduledoc """
  A View is simply a module that defines certain callbacks to configure proper
  rendering of your JSONAPI documents.

      defmodule PostView do
        use JSONAPI.View

        def fields, do: [:id, :text, :body]
        def type, do: "post"
        def relationships do
          [author: UserView,
           comments: CommentView]
        end
      end

      defmodule UserView do
        use JSONAPI.View

        def fields, do: [:id, :username]
        def type, do: "user"
        def relationships, do: []
      end

      defmodule CommentView do
        use JSONAPI.View

        def fields, do: [:id, :text]
        def type, do: "comment"
        def relationships do
          [user: {UserView, :include}]
        end
      end

      defmodule DogView do
        use JSONAPI.View, namespace: "/pupperz-api"
      end

  You can now call `UserView.show(user, conn, conn.params)` and it will render
  a valid jsonapi doc.

  ## Fields

  By default, the resulting JSON document consists of fields, defined in the `fields/0`
  function. You can define custom fields or override current fields by defining a
  2-arity function inside the view that takes `data` and `conn` as arguments and has
  the same name as the field it will be producing. Refer to our `fullname/2` example below.

      defmodule UserView do
        use JSONAPI.View

        def fullname(data, conn), do: "fullname"

        def fields, do: [:id, :username, :fullname]
        def type, do: "user"
        def relationships, do: []
      end

  Fields may be omitted manually using the `hidden/1` function.

      defmodule UserView do
        use JSONAPI.View

        def fields, do: [:id, :username, :email]

        def type, do: "user"

        def hidden(_data) do
          [:email] # will be removed from the response
        end
      end

  In order to use [sparse fieldsets](https://jsonapi.org/format/#fetching-sparse-fieldsets)
  you must include the `JSONAPI.QueryParser` plug.

  If you want to fetch fields from the given data *dynamically*, you can use the
  `c:get_field/3` callback.

      defmodule UserView do
        use JSONAPI.View

        def fields, do: [:id, :username, :email]

        def type, do: "user"

        def get_field(field, data, _conn) do
          Map.fetch!(data, field)
        end
      end

  ## Relationships

  Currently the relationships callback expects that a map is returned
  configuring the information you will need. If you have the following Ecto
  Model setup

      defmodule User do
        schema "users" do
          field :username
          has_many :posts
          has_one :image
        end
      end

  and the includes setup from above. If your Post has loaded the author and the
  query asks for it then it will be loaded.

  So for example:
  `GET /posts?include=post.author` if the author record is loaded on the Post, and you are using
  the `JSONAPI.QueryParser` it will be included in the `includes` section of the JSONAPI document.

  If you always want to include a relationship. First make sure its always preloaded
  and then use the `[user: {UserView, :include}]` syntax in your `includes` function. This tells
  the serializer to *always* include if its loaded.

  ## Options
    * `:host` (binary) - Allows the `host` to be overridden for generated URLs. Defaults to `host` of the supplied `conn`.

    * `:scheme` (atom) - Enables configuration of the HTTP scheme for generated URLS.  Defaults to `scheme` from the provided `conn`.

    * `:namespace` (binary) - Allows the namespace of a given resource. This may be
      configured globally or overridden on the View itself. Note that if you have
      a globally defined namespace and need to *remove* the namespace for a
      resource, set the namespace to a blank String.

  The default behaviour for `host` and `scheme` is to derive it from the `conn` provided, while the
  default style for presentation in names is to be underscored and not dashed.
  """

  alias JSONAPI.{Paginator, Utils}
  alias Plug.Conn

  @type t :: module()
  @type data :: any()
  @type field :: atom()
  @type links :: %{atom() => String.t()}
  @type meta :: %{atom() => String.t()}
  @type options :: keyword()
  @type resource_id :: String.t()
  @type resource_type :: String.t()

  @callback attributes(data(), Conn.t() | nil) :: map()
  @callback id(data()) :: resource_id() | nil
  @callback fields() :: [field()]
  @callback get_field(field(), data(), Conn.t()) :: any()
  @callback hidden(data()) :: [field()]
  @callback links(data(), Conn.t()) :: links()
  @callback meta(data(), Conn.t()) :: meta() | nil
  @callback namespace() :: String.t()
  @callback pagination_links(data(), Conn.t(), Paginator.page(), Paginator.options()) ::
              Paginator.links()
  @callback path() :: String.t() | nil
  @callback relationships() :: [{atom(), t() | {t(), :include}}]
  @callback type() :: resource_type()
  @callback url_for(data(), Conn.t() | nil) :: String.t()
  @callback url_for_pagination(data(), Conn.t(), Paginator.params()) :: String.t()
  @callback url_for_rel(term(), String.t(), Conn.t() | nil) :: String.t()
  @callback visible_fields(data(), Conn.t() | nil) :: list(atom)

  @optional_callbacks [get_field: 3]

  defmacro __using__(opts \\ []) do
    {type, opts} = Keyword.pop(opts, :type)
    {namespace, opts} = Keyword.pop(opts, :namespace)
    {path, opts} = Keyword.pop(opts, :path)
    {paginator, _opts} = Keyword.pop(opts, :paginator)

    quote do
      alias JSONAPI.{Serializer, View}

      @behaviour View

      @resource_type unquote(type)
      @namespace unquote(namespace)
      @path unquote(path)
      @paginator unquote(paginator)

      @impl View
      def id(nil), do: nil
      def id(%{__struct__: Ecto.Association.NotLoaded}), do: nil
      def id(%{id: id}), do: to_string(id)

      @impl View
      def attributes(data, conn) do
        visible_fields = View.visible_fields(__MODULE__, data, conn)

        Enum.reduce(visible_fields, %{}, fn field, intermediate_map ->
          value =
            cond do
              function_exported?(__MODULE__, field, 2) ->
                apply(__MODULE__, field, [data, conn])

              function_exported?(__MODULE__, :get_field, 3) ->
                apply(__MODULE__, :get_field, [field, data, conn])

              true ->
                Map.get(data, field)
            end

          Map.put(intermediate_map, field, value)
        end)
      end

      @impl View
      def fields, do: raise("Need to implement fields/0")

      @impl View
      def hidden(_data), do: []

      @impl View
      def links(_data, _conn), do: %{}

      @impl View
      def meta(_data, _conn), do: nil

      @impl View
      if @namespace do
        def namespace, do: @namespace
      else
        def namespace, do: Application.get_env(:jsonapi, :namespace, "")
      end

      @impl View
      def pagination_links(data, conn, page, options) do
        paginator = Application.get_env(:jsonapi, :paginator, @paginator)

        if Code.ensure_loaded?(paginator) && function_exported?(paginator, :paginate, 5) do
          paginator.paginate(data, __MODULE__, conn, page, options)
        else
          %{}
        end
      end

      @impl View
      def path, do: @path

      @impl View
      def relationships, do: []

      @impl View
      if @resource_type do
        def type, do: @resource_type
      else
        def type, do: raise("Need to implement type/0")
      end

      @impl View
      def url_for(data, conn),
        do: View.url_for(__MODULE__, data, conn)

      @impl View
      def url_for_pagination(data, conn, pagination_params),
        do: View.url_for_pagination(__MODULE__, data, conn, pagination_params)

      @impl View
      def url_for_rel(data, rel_type, conn),
        do: View.url_for_rel(__MODULE__, data, rel_type, conn)

      @impl View
      def visible_fields(data, conn),
        do: View.visible_fields(__MODULE__, data, conn)

      defoverridable View

      def index(models, conn, _params, meta \\ nil, options \\ []),
        do: Serializer.serialize(__MODULE__, models, conn, meta, options)

      def show(model, conn, _params, meta \\ nil, options \\ []),
        do: Serializer.serialize(__MODULE__, model, conn, meta, options)

      if Code.ensure_loaded?(Phoenix) do
        def render("show.json", %{data: data, conn: conn, meta: meta, options: options}),
          do: Serializer.serialize(__MODULE__, data, conn, meta, options)

        def render("show.json", %{data: data, conn: conn, meta: meta}),
          do: Serializer.serialize(__MODULE__, data, conn, meta)

        def render("show.json", %{data: data, conn: conn}),
          do: Serializer.serialize(__MODULE__, data, conn)

        def render("index.json", %{data: data, conn: conn, meta: meta, options: options}),
          do: Serializer.serialize(__MODULE__, data, conn, meta, options)

        def render("index.json", %{data: data, conn: conn, meta: meta}),
          do: Serializer.serialize(__MODULE__, data, conn, meta)

        def render("index.json", %{data: data, conn: conn}),
          do: Serializer.serialize(__MODULE__, data, conn)
      else
        raise ArgumentError,
              "Attempted to call function that depends on Phoenix. " <>
                "Make sure Phoenix is part of your dependencies"
      end
    end
  end

  @spec url_for(t(), term(), Conn.t() | nil) :: String.t()
  def url_for(view, data, nil = _conn) when is_nil(data) or is_list(data),
    do: URI.to_string(%URI{path: Enum.join([view.namespace(), path_for(view)], "/")})

  def url_for(view, data, nil = _conn) do
    URI.to_string(%URI{
      path: Enum.join([view.namespace(), path_for(view), view.id(data)], "/")
    })
  end

  def url_for(view, data, %Plug.Conn{} = conn) when is_nil(data) or is_list(data) do
    URI.to_string(%URI{
      scheme: scheme(conn),
      host: host(conn),
      port: port(conn),
      path: Enum.join([view.namespace(), path_for(view)], "/")
    })
  end

  def url_for(view, data, %Plug.Conn{} = conn) do
    URI.to_string(%URI{
      scheme: scheme(conn),
      host: host(conn),
      port: port(conn),
      path: Enum.join([view.namespace(), path_for(view), view.id(data)], "/")
    })
  end

  @spec url_for_rel(t(), data(), resource_type(), Conn.t() | nil) :: String.t()
  def url_for_rel(view, data, rel_type, conn) do
    "#{url_for(view, data, conn)}/relationships/#{rel_type}"
  end

  @spec url_for_rel(t(), data(), Conn.query_params(), Paginator.params()) :: String.t()
  def url_for_pagination(
        view,
        data,
        %{query_params: query_params} = conn,
        nil = _pagination_params
      ) do
    query =
      query_params
      |> Utils.List.to_list_of_query_string_components()
      |> URI.encode_query()

    prepare_url(view, query, data, conn)
  end

  def url_for_pagination(view, data, %{query_params: query_params} = conn, pagination_params) do
    query_params = Map.put(query_params, "page", pagination_params)

    url_for_pagination(view, data, %{conn | query_params: query_params}, nil)
  end

  @spec visible_fields(t(), data(), Conn.t() | nil) :: list(atom)
  def visible_fields(view, data, conn) do
    all_fields =
      view
      |> requested_fields_for_type(conn)
      |> net_fields_for_type(view.fields())

    hidden_fields = view.hidden(data)

    all_fields -- hidden_fields
  end

  defp net_fields_for_type(requested_fields, fields) when requested_fields in [nil, %{}],
    do: fields

  defp net_fields_for_type(requested_fields, fields) do
    fields
    |> MapSet.new()
    |> MapSet.intersection(MapSet.new(requested_fields))
    |> MapSet.to_list()
  end

  defp prepare_url(view, "", data, conn), do: url_for(view, data, conn)

  defp prepare_url(view, query, data, conn) do
    view
    |> url_for(data, conn)
    |> URI.parse()
    |> struct(query: query)
    |> URI.to_string()
  end

  defp requested_fields_for_type(view, %Conn{assigns: %{jsonapi_query: %{fields: fields}}}) do
    fields[view.type()]
  end

  defp requested_fields_for_type(_view, _conn), do: nil

  defp host(%Conn{host: host}),
    do: Application.get_env(:jsonapi, :host, host)

  defp port(%Conn{port: 0} = conn),
    do: port(%{conn | port: URI.default_port(scheme(conn))})

  defp port(%Conn{port: port}),
    do: Application.get_env(:jsonapi, :port, port)

  defp scheme(%Conn{scheme: scheme}),
    do: Application.get_env(:jsonapi, :scheme, to_string(scheme))

  defp path_for(view), do: view.path() || view.type()
end
