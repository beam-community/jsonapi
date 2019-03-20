defmodule JSONAPI.Paginator do
  @moduledoc """
  Pagination strategy behaviour
  """

  @type links :: %{
          first: String.t() | nil,
          last: String.t() | nil,
          next: String.t() | nil,
          prev: String.t() | nil
        }

  @callback paginate(data :: term, view :: atom, conn :: Plug.Conn.t(), page :: JSONAPI.Page.t()) ::
              links
end
