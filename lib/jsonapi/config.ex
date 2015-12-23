defmodule JSONAPI.Config do
  defstruct fields: %{}, view: nil, filter: %{}, includes: [], sort: nil, data: nil, required_fields: nil, opts: nil
end
