defmodule JSONAPI.FormatRequired do
  @moduledoc """
  Enforces the JSONAPI format of {"data" => {"attributes" => ...}} for request bodies
  """

  import JSONAPI.ErrorView

  # Cf. https://jsonapi.org/format/#crud-updating-to-many-relationships
  @update_has_many_relationships_methods ~w[DELETE PATCH POST]

  def init(opts), do: opts

  def call(%{method: method} = conn, _opts) when method in ~w[DELETE GET HEAD], do: conn

  def call(%{method: "POST", params: %{"data" => %{"type" => _}}} = conn, _), do: conn

  def call(%{method: method, params: %{"data" => [%{"type" => _} | _]}} = conn, _)
      when method in @update_has_many_relationships_methods do
    conn
  end

  def call(%{params: %{"data" => %{"type" => _, "id" => _}}} = conn, _), do: conn

  def call(%{params: %{"data" => _}} = conn, _),
    do: send_error(conn, missing_data_attributes_param())

  def call(conn, _), do: send_error(conn, missing_data_param())
end
