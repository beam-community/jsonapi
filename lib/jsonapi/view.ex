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
    * `:host` (binary) - Allows the `host` to be overrided for generated URLs. Defaults to `host` of the supplied `conn`.

    * `:scheme` (atom) - Enables configuration of the HTTP scheme for generated URLS.  Defaults to `scheme` from the provided `conn`.

    * `:namespace` (binary) - Allows the namespace of a given resource. This may be
      configured globally or overridden on the View itself. Note that if you have
      a globally defined namespace and need to *remove* the namespace for a
      resource, set the namespace to a blank String.

  The default behaviour for `host` and `scheme` is to derive it from the `conn` provided, while the
  default style for presentation in names is to be underscored and not dashed.
  """

  alias Plug.Conn

  defmacro __using__(opts \\ []) do
    {type, opts} = Keyword.pop(opts, :type)
    {namespace, opts} = Keyword.pop(opts, :namespace)
    {paginator, _opts} = Keyword.pop(opts, :paginator)

    quote do
      import JSONAPI.Utils.List, only: [to_list_of_query_string_components: 1]
      import JSONAPI.Serializer, only: [serialize: 5]

      @resource_type unquote(type)
      @namespace unquote(namespace)
      @paginator unquote(paginator)

      def id(nil), do: nil
      def id(%{__struct__: Ecto.Association.NotLoaded}), do: nil
      def id(%{id: id}), do: to_string(id)

      if @resource_type do
        def type, do: @resource_type
      else
        def type, do: raise("Need to implement type/0")
      end

      if @namespace do
        def namespace, do: @namespace
      else
        def namespace, do: Application.get_env(:jsonapi, :namespace, "")
      end

      def pagination_links(data, conn, page, options) do
        paginator = Application.get_env(:jsonapi, :paginator, @paginator)

        if Code.ensure_loaded?(paginator) && function_exported?(paginator, :paginate, 5) do
          paginator.paginate(data, __MODULE__, conn, page, options)
        else
          %{}
        end
      end

      defp requested_fields_for_type(%Conn{assigns: %{jsonapi_query: %{fields: fields}}} = conn) do
        fields[type()]
      end

      defp requested_fields_for_type(_conn), do: nil

      defp net_fields_for_type(requested_fields, fields) when requested_fields in [nil, %{}],
        do: fields

      defp net_fields_for_type(requested_fields, fields) do
        fields
        |> MapSet.new()
        |> MapSet.intersection(MapSet.new(requested_fields))
        |> MapSet.to_list()
      end

      @spec visible_fields(map(), conn :: nil | Conn.t()) :: list(atom)
      def visible_fields(data, conn) do
        all_fields =
          conn
          |> requested_fields_for_type()
          |> net_fields_for_type(fields())

        hidden_fields = hidden(data)

        all_fields -- hidden_fields
      end

      @spec attributes(map(), conn :: nil | Conn.t()) :: map()
      def attributes(data, conn) do
        visible_fields = visible_fields(data, conn)

        Enum.reduce(visible_fields, %{}, fn field, intermediate_map ->
          value =
            case function_exported?(__MODULE__, field, 2) do
              true -> apply(__MODULE__, field, [data, conn])
              false -> Map.get(data, field)
            end

          Map.put(intermediate_map, field, value)
        end)
      end

      def links(_data, _conn), do: %{}

      def meta(_data, _conn), do: nil

      def relationships, do: []

      def fields, do: raise("Need to implement fields/0")

      def hidden(data), do: []

      def show(model, conn, _params, meta \\ nil, options \\ []),
        do: serialize(__MODULE__, model, conn, meta, options)

      def index(models, conn, _params, meta \\ nil, options \\ []),
        do: serialize(__MODULE__, models, conn, meta, options)

      def url_for(nil, nil), do: "#{namespace()}/#{type()}"

      def url_for(data, nil) when is_list(data), do: "#{namespace()}/#{type()}"

      def url_for(data, nil), do: "#{namespace()}/#{type()}/#{id(data)}"

      def url_for(data, %Plug.Conn{} = conn) when is_list(data) or is_nil(data) do
        "#{scheme(conn)}://#{host(conn)}#{namespace()}/#{type()}"
      end

      def url_for(data, %Plug.Conn{} = conn) do
        "#{scheme(conn)}://#{host(conn)}#{namespace()}/#{type()}/#{id(data)}"
      end

      def url_for_rel(data, rel_type, conn) do
        "#{url_for(data, conn)}/relationships/#{rel_type}"
      end

      def url_for_pagination(data, %{query_params: query_params} = conn, pagination_attrs) do
        query_params
        |> Map.put("page", pagination_attrs)
        |> to_list_of_query_string_components()
        |> URI.encode_query()
        |> prepare_url(data, conn)
      end

      defp prepare_url("", data, conn), do: url_for(data, conn)

      defp prepare_url(query, data, conn), do: "#{url_for(data, conn)}?#{query}"

      if Code.ensure_loaded?(Phoenix) do
        def render("show.json", %{data: data, conn: conn, params: params, meta: meta}),
          do: show(data, conn, params, meta)

        def render("show.json", %{data: data, conn: conn, meta: meta}),
          do: show(data, conn, conn.params, meta)

        def render("show.json", %{data: data, conn: conn}), do: show(data, conn, conn.params)

        def render("index.json", %{data: data, conn: conn, params: params, meta: meta}),
          do: index(data, conn, params, meta)

        def render("index.json", %{data: data, conn: conn, meta: meta}),
          do: index(data, conn, conn.params, meta)

        def render("index.json", %{data: data, conn: conn}), do: index(data, conn, conn.params)
      else
        raise ArgumentError,
              "Attempted to call function that depends on Phoenix. " <>
                "Make sure Phoenix is part of your dependencies"
      end

      defp host(conn), do: Application.get_env(:jsonapi, :host, conn.host)

      defp scheme(conn), do: Application.get_env(:jsonapi, :scheme, to_string(conn.scheme))

      defoverridable attributes: 2,
                     links: 2,
                     pagination_links: 4,
                     fields: 0,
                     hidden: 1,
                     id: 1,
                     meta: 2,
                     relationships: 0,
                     type: 0,
                     url_for: 2,
                     url_for_rel: 3
    end
  end
end
