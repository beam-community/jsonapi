defmodule JSONAPI.Config do
  @moduledoc """
  Configuration struct containing JSON API information for a request
  """

  defstruct data: nil,
            fields: %{},
            filter: [],
            include: [],
            opts: nil,
            sort: nil,
            view: nil,
            page: %{}

  @type t :: %__MODULE__{
          data: nil | map,
          fields: map,
          filter: keyword,
          include: [atom | {atom, any}],
          opts: nil | keyword,
          sort: nil | keyword,
          view: any,
          page: nil | map
        }
end
