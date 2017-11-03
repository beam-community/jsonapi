defmodule JSONAPI.Config do
  @moduledoc """
  Configuration struct containing JSON API information for a request
  """

  defstruct data: nil,
            fields: %{},
            filter: [],
            includes: [],
            opts: nil,
            required_fields: nil,
            sort: nil,
            view: nil,
            page: nil
          end
