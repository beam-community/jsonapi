defmodule JSONAPI.Deprecation do
  @moduledoc """
    Generate warnings in places where we want to deprecate functions or struct parameters
  """

  @doc """
    Generates a deprecation warning for using `fields[relationship_key]` instead of `fields[type]` when
    parsing query parameters.
  """
  def warn(:query_parser_fields) do
    IO.warn(
      "`JSONAPI.QueryParser` will no longer accept `fields` query params that refer to the relationship key of a `JSONAPI.View`.  Please use the `type` of the resource to perform filtering.
      See: https://github.com/jeregrine/jsonapi/pull/203.",
      Macro.Env.stacktrace(__ENV__)
    )
  end
end
