defmodule JSONAPI.PhoenixView do
  @moduledoc """
  This is an optional Phoenix specific module to include. It will give you default render show and index.json methods.
  """
  
  defmacro __using__(_opts) do
    quote do
      use JSONAPI.View
      def render("show.json", %{data: data, conn: conn}), do: show(data, conn, conn.params)
      def render("show.json", %{data: data, conn: conn, params: params}), do: show(data, conn, params)

      def render("index.json", %{data: data, conn: conn}), do: index(data, conn, conn.params)
      def render("index.json", %{data: data, conn: conn, params: params}), do: show(data, conn, params)
    end
  end
end
