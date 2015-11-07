defmodule JSONAPI.Exceptions do
  defmodule InvalidQuery do
    defexception plug_status: 400, message: "invalid query", resource: nil, param: nil, param_type: nil

    def exception(opts) do
      resource = Keyword.fetch!(opts, :resource)
      param    = Keyword.fetch!(opts, :param)
      type     = Keyword.fetch!(opts, :param_type) 

      %InvalidQuery{message: "invalid #{type}, #{param} for type #{resource}", 
        resource: resource, param: param, param_type: type}
    end
  end
end
