defmodule JSONAPI.Config do
  defstruct data: nil,
            fields: %{},
            filter: [],
            includes: [],
            opts: nil,
            required_fields: nil,
            sort: nil,
            view: nil
end
