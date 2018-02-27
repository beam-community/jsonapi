defmodule JSONAPI.ErrorView do
  @moduledoc """
  """

  import Plug.Conn, only: [send_resp: 3, halt: 1]

  @crud_message "Check out http://jsonapi.org/format/#crud for more info."

  def build_error(title, status, detail, pointer \\ nil, meta \\ nil) do
    error = %{
      detail: detail,
      status: status,
      title: title
    }

    error
    |> append_field(:source, pointer)
    |> append_field(:meta, meta)
  end

  def malformed_id do
    "Malformed id in data parameter"
    |> build_error(422, @crud_message, "/data/id")
    |> serialize_error
  end

  def mismatched_id do
    "Mismatched id parameter"
    |> build_error(
      409,
      "The id in the url must match the id at '/data/id'.  #{@crud_message}",
      "/data/id"
    )
    |> serialize_error
  end

  def missing_data_attributes_param do
    "Missing attributes in data parameter"
    |> build_error(400, @crud_message, "/data/attributes")
    |> serialize_error
  end

  def missing_data_param do
    "Missing data parameter"
    |> build_error(400, @crud_message, "/data")
    |> serialize_error
  end

  def missing_id do
    "Missing id in data parameter"
    |> build_error(400, @crud_message, "/data/id")
    |> serialize_error
  end

  def send_error(conn, %{errors: [%{status: status}]} = error),
    do: send_error(conn, status, error)

  def send_error(conn, %{errors: errors} = error) when is_list(errors) do
    status = Enum.max_by(errors, &Map.get(&1, :status))
    send_error(conn, status, error)
  end

  def send_error(conn, status, error \\ "")

  def send_error(conn, status, error) when is_map(error) do
    json = Poison.encode!(error)
    send_error(conn, status, json)
  end

  def send_error(conn, status, error) do
    conn
    |> send_resp(status, error)
    |> halt
  end

  def serialize_error(error) do
    error = Map.take(error, [:detail, :id, :links, :meta, :source, :status, :title])
    %{errors: [error]}
  end

  defp append_field(error, _field, nil), do: error
  defp append_field(error, :meta, value), do: Map.put(error, :meta, %{meta: value})
  defp append_field(error, :source, value), do: Map.put(error, :source, %{pointer: value})
end
