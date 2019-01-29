defmodule JSONAPI.Page do
  @moduledoc """
  Configuration struct containing pagination opts for a request
  """

  defstruct limit: nil,
            offset: nil,
            size: nil,
            page: nil,
            cursor: nil

  @type t :: %__MODULE__{
          limit: non_neg_integer,
          offset: non_neg_integer,
          size: non_neg_integer,
          page: non_neg_integer,
          cursor: non_neg_integer
        }
end
