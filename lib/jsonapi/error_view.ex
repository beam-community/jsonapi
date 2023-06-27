defmodule JSONAPI.ErrorView do
  @moduledoc """
  """

  import Plug.Conn, only: [send_resp: 3, halt: 1, put_resp_content_type: 2]

  @crud_message "Check out http://jsonapi.org/format/#crud for more info."
  @relationship_resource_linkage_message "Check out https://jsonapi.org/format/#document-resource-object-linkage for more info."

  @spec build_error(binary(), pos_integer(), binary() | nil, binary() | nil) :: map()
  def build_error(title, status, detail, pointer \\ nil, meta \\ nil) do
    error = %{
      detail: detail,
      status: Integer.to_string(status),
      title: title
    }

    error
    |> append_field(:source, pointer)
    |> append_field(:meta, meta)
  end

  @spec malformed_id :: map()
  def malformed_id do
    "Malformed id in data parameter"
    |> build_error(422, @crud_message, "/data/id")
    |> serialize_error
  end

  @spec mismatched_id :: map()
  def mismatched_id do
    "Mismatched id parameter"
    |> build_error(
      409,
      "The id in the url must match the id at '/data/id'.  #{@crud_message}",
      "/data/id"
    )
    |> serialize_error
  end

  @spec missing_data_attributes_param :: map()
  def missing_data_attributes_param do
    "Missing attributes in data parameter"
    |> build_error(400, @crud_message, "/data/attributes")
    |> serialize_error
  end

  @spec missing_data_id_param :: map()
  def missing_data_id_param do
    "Missing id in data parameter"
    |> build_error(400, @crud_message, "/data/id")
    |> serialize_error
  end

  @spec missing_data_type_param :: map()
  def missing_data_type_param do
    "Missing type in data parameter"
    |> build_error(400, @crud_message, "/data/type")
    |> serialize_error
  end

  @spec missing_data_param :: map()
  def missing_data_param do
    "Missing data parameter"
    |> build_error(400, @crud_message, "/data")
    |> serialize_error
  end

  @spec missing_id :: map()
  def missing_id do
    "Missing id in data parameter"
    |> build_error(400, @crud_message, "/data/id")
    |> serialize_error
  end

  @spec to_many_relationships_payload_for_standard_endpoint :: map()
  def to_many_relationships_payload_for_standard_endpoint do
    "Data parameter has multiple Resource Identifier Objects for a non-relationship endpoint"
    |> build_error(
      400,
      "Check out https://jsonapi.org/format/#crud-updating-to-many-relationships for more info.",
      "/data"
    )
    |> serialize_error
  end

  @spec incorrect_content_type :: map()
  def incorrect_content_type do
    detail =
      "The content-type header must use the media type '#{JSONAPI.mime_type()}'.  #{@crud_message}"

    "Incorrect content-type"
    |> build_error(415, detail)
    |> serialize_error
  end

  @spec relationships_create_missing_object :: map()
  def relationships_create_missing_object do
    "Relationships parameter is not an object"
    |> build_error(
      400,
      "Check out https://jsonapi.org/format/#document-resource-object-relationships for more info.",
      "/data/relationships"
    )
    |> serialize_error
  end

  @spec missing_relationship_data_param_error(binary()) :: map()
  def missing_relationship_data_param_error(relationship_name) do
    "Missing data parameter in relationship"
    |> build_error(
      400,
      "Check out https://jsonapi.org/format/#crud-creating for more info.",
      "/data/relationships/#{relationship_name}/data"
    )
  end

  @spec missing_relationship_data_id_param_error(binary()) :: map()
  def missing_relationship_data_id_param_error(relationship_name) do
    "Missing id in relationship data parameter"
    |> build_error(
      400,
      @relationship_resource_linkage_message,
      "/data/relationships/#{relationship_name}/data/id"
    )
  end

  @spec missing_relationship_data_type_param_error(binary()) :: map()
  def missing_relationship_data_type_param_error(relationship_name) do
    "Missing type in relationship data parameter"
    |> build_error(
      400,
      @relationship_resource_linkage_message,
      "/data/relationships/#{relationship_name}/data/type"
    )
  end

  @spec send_error(Plug.Conn.t(), term()) :: term()
  def send_error(conn, %{errors: [%{status: status}]} = error),
    do: send_error(conn, status, error)

  def send_error(conn, %{errors: errors} = error) when is_list(errors) do
    status =
      errors
      |> Enum.max_by(&Map.get(&1, :status))
      |> Map.get(:status)

    send_error(conn, status, error)
  end

  def send_error(conn, status, error \\ "")

  def send_error(conn, status, error) when is_map(error) do
    json = JSONAPI.json_library().encode!(error)
    send_error(conn, status, json)
  end

  def send_error(conn, status, error) when is_binary(status) do
    send_error(conn, String.to_integer(status), error)
  end

  def send_error(conn, status, error) do
    conn
    |> put_resp_content_type(JSONAPI.mime_type())
    |> send_resp(status, error)
    |> halt
  end

  @spec serialize_error(map()) :: map()
  def serialize_error(error) do
    error = extract_error(error)
    %{errors: [error]}
  end

  @spec serialize_errors(list()) :: map()
  def serialize_errors(errors) do
    extracted = Enum.map(errors, &extract_error/1)
    %{errors: extracted}
  end

  defp extract_error(error) do
    Map.take(error, [:detail, :id, :links, :meta, :source, :status, :title])
  end

  defp append_field(error, _field, nil), do: error
  defp append_field(error, :meta, value), do: Map.put(error, :meta, %{meta: value})
  defp append_field(error, :source, value), do: Map.put(error, :source, %{pointer: value})
end
