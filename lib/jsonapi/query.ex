defmodule JSONAPI.Query do
  import Ecto.Query
  @doc """
  Will take an existing query, and add a limit and offset to it.
  """
  def add_query_paging(query, params)do
    number = get_in(params, [:page, :number]) || 0
    size = get_in(params, [:page, :size]) || 20

    from(t in query,
      limit: ^size,
      offset: ^(size * number))
  end
end

