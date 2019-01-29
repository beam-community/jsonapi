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
            required_fields: nil,
            sort: nil,
            view: nil,
            page: %Page{}

  @type t :: %__MODULE__{
          data: struct,
          fields: map,
          filter: keyword,
          include: keyword,
          opts: any,
          required_fields: any,
          sort: any,
          view: any,
          page: Page.t()
        }
end
