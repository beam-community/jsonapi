defmodule JSONAPI.EnsureSpec do
  @moduledoc """
  A helper Plug to enforce the JSON API specification
  """

  use Plug.Builder

  alias JSONAPI.{ContentTypeNegotiation, FormatRequired, IdRequired, ResponseContentType}

  plug ContentTypeNegotiation
  plug FormatRequired
  plug IdRequired
  plug ResponseContentType
end
