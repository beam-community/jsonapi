defmodule JSONAPI.FormatRequired do
  @moduledoc """
  Enforces the JSONAPI format of {"data" => {"attributes" => ...}} for request bodies
  """

  import JSONAPI.ErrorView

  def init(opts), do: opts

  def call(%{method: method} = conn, _opts) when method in ["DELETE", "GET", "HEAD"], do: conn

  def call(%{method: method, params: %{"data" => %{"type" => _}}} = conn, _)
      when method == "POST",
      do: conn

  def call(%{params: %{"data" => %{"type" => _, "id" => _}}} = conn, _), do: conn

  def call(%{params: %{"data" => _}} = conn, _),
    do: send_error(conn, missing_data_attributes_param())

  def call(conn, _), do: send_error(conn, missing_data_param())
end
