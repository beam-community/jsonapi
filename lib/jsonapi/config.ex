defmodule JSONAPI.Config do
  @moduledoc """
  Configuration struct containing JSON API information for a request
  """

  alias JSONAPI.Page

  defstruct data: nil,
            fields: %{},
            filter: [],
            include: [],
            opts: nil,
            sort: nil,
            view: nil,
            page: %Page{}

  @type t :: %__MODULE__{
          data: nil | map,
          fields: map,
          filter: keyword,
          include: keyword,
          opts: nil | keyword,
          sort: nil | keyword,
          view: any,
          page: Page.t()
        }
end
