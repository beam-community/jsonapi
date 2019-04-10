defmodule JSONAPI.Paginator.Page do
  @moduledoc """
  Page based pagination strategy
  """

  @behaviour JSONAPI.Paginator

  @impl true
  def paginate(data, view, conn, page, options) do
    number =
      page
      |> Map.get("page", "0")
      |> String.to_integer()

    size =
      page
      |> Map.get("size", "0")
      |> String.to_integer()

    total_pages =
      options
      |> Keyword.get(:total_pages, 0)

    %{
      first: view.url_for_pagination(data, conn, %{page | "page" => "1"}),
      last: view.url_for_pagination(data, conn, %{page | "page" => total_pages}),
      next: next_link(data, view, conn, number, size, total_pages),
      prev: previous_link(data, view, conn, number, size)
    }
  end

  defp next_link(data, view, conn, page, size, total_pages)
       when page < total_pages,
       do: view.url_for_pagination(data, conn, %{size: size, page: page + 1})

  defp next_link(_data, _view, _conn, _page, _size, _total_pages),
    do: nil

  defp previous_link(data, view, conn, page, size)
       when page > 1,
       do: view.url_for_pagination(data, conn, %{size: size, page: page - 1})

  defp previous_link(_data, _view, _conn, _page, _size),
    do: nil
end
