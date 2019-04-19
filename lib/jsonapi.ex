defmodule JSONAPI do
  @moduledoc """
  A module for working with the JSON API specification in Elixir
  """

  @doc """
  Returns the configured JSON encoding library for JSONAPI.
  To customize the JSON library, including the following
  in your `config/config.exs`:
      config :jsonapi, :json_library, Jason
  """
  @spec json_library :: module()
  def json_library do
    module = Application.get_env(:jsonapi, :json_library, Jason)

    if Code.ensure_loaded?(module) do
      module
    else
      IO.write(:stderr, """
      failed to load #{inspect(module)} for JSONAPI JSON encoding.
      (module #{inspect(module)} is not available)
      Ensure #{inspect(module)} is loaded from your deps in mix.exs, or
      configure an existing encoder in your mix config using:
          config :jsonapi, :json_library, MyJSONLibrary
      """)
    end
  end

  @mime_type "application/vnd.api+json"

  @doc """
  This returns the MIME type for JSONAPIs
  """
  @spec mime_type :: binary()
  def mime_type, do: @mime_type
end
