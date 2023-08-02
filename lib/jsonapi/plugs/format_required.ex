defmodule JSONAPI.FormatRequired do
  @moduledoc """
  Enforces the JSONAPI format of {"data" => {"attributes" => ...}} for request bodies
  """

  import JSONAPI.ErrorView

  # Cf. https://jsonapi.org/format/#crud-updating-to-many-relationships
  @update_has_many_relationships_methods ~w[DELETE PATCH POST]

  def init(opts), do: opts

  def call(%{method: method} = conn, _opts) when method in ~w[DELETE GET HEAD], do: conn

  def call(
        %{method: method, params: %{"data" => %{"type" => _, "relationships" => relationships}}} =
          conn,
        _
      )
      when method in ~w[POST PATCH] and not is_map(relationships) do
    send_error(conn, relationships_missing_object())
  end

  def call(
        %{
          method: method,
          params: %{"data" => %{"type" => _, "relationships" => relationships}}
        } = conn,
        _
      )
      when method in ~w[POST PATCH] and is_map(relationships) do
    errors =
      Enum.reduce(relationships, [], fn
        {_relationship_name, %{"data" => %{"type" => _type, "id" => _}}}, acc ->
          acc

        {relationship_name, %{"data" => %{"type" => _type}}}, acc ->
          error = missing_relationship_data_id_param_error_attrs(relationship_name)
          [error | acc]

        {relationship_name, %{"data" => %{"id" => _type}}}, acc ->
          error = missing_relationship_data_type_param_error_attrs(relationship_name)
          [error | acc]

        {relationship_name, %{"data" => %{}}}, acc ->
          id_error = missing_relationship_data_id_param_error_attrs(relationship_name)
          type_error = missing_relationship_data_type_param_error_attrs(relationship_name)
          [id_error | [type_error | acc]]

        {_relationship_name, %{"data" => _}}, acc ->
          # Allow things other than resource identifier objects per https://jsonapi.org/format/#document-resource-object-linkage
          # - null for empty to-one relationships.
          # - an empty array ([]) for empty to-many relationships.
          # - an array of resource identifier objects for non-empty to-many relationships.
          acc

        {relationship_name, _}, acc ->
          error = missing_relationship_data_param_error_attrs(relationship_name)
          [error | acc]
      end)

    if Enum.empty?(errors) do
      conn
    else
      send_error(conn, serialize_errors(errors))
    end
  end

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

  def call(%{method: "PATCH", params: %{"data" => %{"attributes" => _, "type" => _}}} = conn, _) do
    send_error(conn, missing_data_id_param())
  end

  def call(%{method: "PATCH", params: %{"data" => %{"attributes" => _, "id" => _}}} = conn, _) do
    send_error(conn, missing_data_type_param())
  end

  def call(%{params: %{"data" => %{"attributes" => _}}} = conn, _),
    do: send_error(conn, missing_data_type_param())

  def call(%{params: %{"data" => _}} = conn, _),
    do: send_error(conn, missing_data_attributes_param())

  def call(conn, _), do: send_error(conn, missing_data_param())
end
