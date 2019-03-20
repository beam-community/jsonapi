defmodule JSONAPI.Page do
  @moduledoc """
  Configuration struct containing pagination opts for a request
  """

  defstruct limit: nil,
            offset: nil,
            size: nil,
            page: nil,
            cursor: nil,
            total_items: nil,
            total_pages: nil

  @type t :: %__MODULE__{
          limit: nil | non_neg_integer,
          offset: nil | non_neg_integer,
          size: nil | non_neg_integer,
          page: nil | non_neg_integer,
          cursor: nil | non_neg_integer,
          total_items: nil | non_neg_integer,
          total_pages: nil | non_neg_integer
        }

  def put_total_items(page, count), do: %__MODULE__{page | total_items: count}
  def put_total_pages(page, count), do: %__MODULE__{page | total_pages: count}
end
