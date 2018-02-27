defmodule JSONAPI.PlugResponseContentType do
  @moduledoc """
  Simply add this plug to your endpoint or your router :api pipeline and it will
  ensure you return the correct response type.

  If you need to override the response type simple set conn.assigns[:override_jsonapi]
  and this will be skipped.
  """
  @behaviour Plug
  import Plug.Conn

  def init(_opts) do
  end

  def call(conn, _opts) do
    register_before_send(conn, fn conn ->
      if conn.assigns[:override_jsonapi] do
        conn
      else
        put_resp_content_type(conn, "application/vnd.api+json")
      end
    end)
  end
end
