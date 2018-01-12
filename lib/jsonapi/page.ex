defmodule JSONAPI.Page do
  @moduledoc """
  Configuration struct containing pagination opts for a request
  """

  defstruct limit: nil,
            offset: nil,
            size: nil,
            page: nil,
            cursor: nil
end
