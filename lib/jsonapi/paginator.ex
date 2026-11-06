defmodule JSONAPI.Paginator do
  @moduledoc """
  Pagination strategy behaviour
  """

  alias Plug.Conn

  @type options :: Keyword.t()

  @type page :: map()

  @type params :: %{String.t() => String.t()}

  @type links :: %{
          optional(:first) => String.t() | nil,
          optional(:last) => String.t() | nil,
          optional(:next) => String.t() | nil,
          optional(:prev) => String.t() | nil
        }

  @callback paginate(data :: term, view :: atom, conn :: Conn.t(), page, options) :: links
end
