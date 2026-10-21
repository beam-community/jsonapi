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
        # Resource linkage per https://jsonapi.org/format/#document-resource-object-linkage
        # - null for empty to-one relationships.
        {_relationship_name, %{"data" => nil}}, acc ->
          acc

        # - an array of resource identifier objects for to-many relationships, possibly empty.
        {relationship_name, %{"data" => linkages}}, acc when is_list(linkages) ->
          linkages
          |> Enum.with_index()
          |> Enum.reduce(acc, fn {linkage, index}, inner_acc ->
            resource_identifier_errors(linkage, relationship_name, index) ++ inner_acc
          end)

        # - a single resource identifier object for non-empty to-one relationships.
        {relationship_name, %{"data" => linkage}}, acc ->
          resource_identifier_errors(linkage, relationship_name, nil) ++ acc

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

  defp resource_identifier_errors(%{"type" => _, "id" => _}, _relationship_name, _index), do: []

  defp resource_identifier_errors(%{"type" => _}, relationship_name, index),
    do: [missing_relationship_data_id_param_error_attrs(relationship_name, index)]

  defp resource_identifier_errors(%{"id" => _}, relationship_name, index),
    do: [missing_relationship_data_type_param_error_attrs(relationship_name, index)]

  defp resource_identifier_errors(%{}, relationship_name, index) do
    [
      missing_relationship_data_id_param_error_attrs(relationship_name, index),
      missing_relationship_data_type_param_error_attrs(relationship_name, index)
    ]
  end

  defp resource_identifier_errors(_linkage, relationship_name, index),
    do: [invalid_relationship_linkage_error_attrs(relationship_name, index)]
end
