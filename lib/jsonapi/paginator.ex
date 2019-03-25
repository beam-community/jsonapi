defmodule JSONAPI.Paginator do
  @moduledoc """
  Pagination strategy behaviour
  """

  alias JSONAPI.Page
  alias Plug.Conn

  @type links :: %{
          first: String.t() | nil,
          last: String.t() | nil,
          next: String.t() | nil,
          prev: String.t() | nil
        }

  @callback paginate(data :: term, view :: atom, conn :: Conn.t(), page :: Page.t()) :: links
end
