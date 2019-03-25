defmodule JSONAPI.Paginator.Page do
  @moduledoc """
  Page based pagination strategy
  """

  @behaviour JSONAPI.Paginator

  @impl true
  def paginate(data, view, conn, %{size: size, total_pages: total_pages} = page) do
    first = view.url_for_pagination(data, conn, %{size: size, page: 1})
    last = view.url_for_pagination(data, conn, %{size: size, page: total_pages})

    %{
      first: first,
      last: last,
      next: next_link(data, view, conn, page),
      prev: previous_link(data, view, conn, page)
    }
  end

  defp next_link(data, view, conn, %{page: page, size: size, total_pages: total_pages})
       when page < total_pages,
       do: view.url_for_pagination(data, conn, %{size: size, page: page + 1})

  defp next_link(_data, _view, _conn, _page),
    do: nil

  defp previous_link(data, view, conn, %{page: page, size: size}) when page > 1,
    do: view.url_for_pagination(data, conn, %{size: size, page: page - 1})

  defp previous_link(_data, _view, _conn, _page),
    do: nil
end
