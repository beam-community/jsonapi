defmodule JSONAPI.Exceptions do
  defmodule InvalidSortParameter do
    defexception plug_status: 400, message: "invalid sort parameter", resource: nil, param: nil

    def exception(opts) do
      resource   = Keyword.fetch!(opts, :resource)
      param      = Keyword.fetch!(opts, :param)

      %InvalidSortParameter{message: "invalid sort, #{param} for type #{resource}", resource: resource, param: param}
    end
  end
end
