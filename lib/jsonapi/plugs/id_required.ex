defmodule JSONAPI.IdRequired do
  @moduledoc """
  Ensure that the URL id matches the id in the request body and is a string
  """

  import JSONAPI.ErrorView

  def init(opts), do: opts

  def call(%{method: method} = conn, _opts) when method in ["DELETE", "GET", "HEAD", "POST"],
    do: conn

  def call(%{params: %{"data" => %{"id" => id}, "id" => id}} = conn, _) when is_binary(id),
    do: conn

  def call(%{params: %{"data" => %{"id" => id}}} = conn, _) when not is_binary(id),
    do: send_error(conn, malformed_id())

  def call(%{params: %{"data" => %{"id" => id}, "id" => _id}} = conn, _) when is_binary(id),
    do: send_error(conn, mismatched_id())

  def call(%{params: %{"id" => _id}} = conn, _), do: send_error(conn, missing_id())
  def call(conn, _), do: conn
end
