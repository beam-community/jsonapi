defmodule JSONAPI.Paginator.Page do
  @behaviour JSONAPI.Paginator

  alias JSONAPI.Page

  def paginate(data, view, conn, %Page{page: page, size: size, total_pages: total_pages}) do
    first = view.url_for_pagination(data, conn, %{size: size, page: 1})
    last = view.url_for_pagination(data, conn, %{size: size, page: total_pages})

    next =
      if page != total_pages do
        view.url_for_pagination(data, conn, %{size: size, page: page + 1})
      else
        nil
      end

    prev =
      if page != 1 do
        view.url_for_pagination(data, conn, %{size: size, page: page - 1})
      else
        nil
      end

    %{first: first, last: last, prev: prev, next: next}
  end
end
