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
    if String.contains?(conn.request_path, "relationships") do
      conn
    else
      send_error(conn, to_many_relationships_payload_for_standard_endpoint())
    end
  end

  def call(%{params: %{"data" => %{"type" => _, "id" => _}}} = conn, _), do: conn

  def call(%{method: "PATCH", params: %{"data" => %{"attributes" => _}}} = conn, _) do
    send_error(conn, missing_data_id_param())
  end

  def call(%{params: %{"data" => %{"attributes" => _}}} = conn, _),
    do: send_error(conn, missing_data_type_param())

  def call(%{params: %{"data" => _}} = conn, _),
    do: send_error(conn, missing_data_attributes_param())

  def call(conn, _), do: send_error(conn, missing_data_param())
end
