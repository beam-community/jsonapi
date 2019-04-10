defmodule JSONAPI.Paginator do
  @moduledoc """
  Pagination strategy behaviour
  """

  alias Plug.Conn

  @type page :: map()

  @type options :: Keyword.t()

  @type links :: %{
          first: String.t() | nil,
          last: String.t() | nil,
          next: String.t() | nil,
          prev: String.t() | nil
        }

  @callback paginate(data :: term, view :: atom, conn :: Conn.t(), page, options) :: links
end
