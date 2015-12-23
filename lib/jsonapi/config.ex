defmodule JSONAPI.Config do
  @type t :: %JSONAPI.Config {
    fields: map,
    view: atom,
    filter: map,
    includes: list,
    sort: list,
    data: any,
    required_fields: list,
    opts: list
  }

  defstruct fields: %{}, view: nil, filter: %{}, includes: [], sort: nil, data: nil, required_fields: nil, opts: nil
end
