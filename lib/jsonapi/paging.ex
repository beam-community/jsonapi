defmodule JSONAPI.Paging do
  #|> handle_paging(mod, Map.drop(params, ["format", :sort, "filter"]), conn_or_endpoint)
  defp handle_paging(doc, mod, params, endpoint) do
    links = %{
      self: mod.url_func().(endpoint, :index, params),
    }

    page_number = get_in(params, [:page, :number])
    page_size  = get_in(params, [:page, :size])
    resources = Map.get(doc, :data, [])

    if page_number && page_size do

      if Enum.count(resources) == page_size do
        next_page = mod.url_func().(endpoint, :index, put_in(params, [:page, :number], page_number+1))
        links = Dict.put(links, :next_page, next_page)
      end

      if page_number > 0 do
        previous_page = mod.url_func().(endpoint, :index, put_in(params, [:page, :number], page_number-1))
        links = Dict.put(links, :previous_page, previous_page)
      end

      links = Map.get(doc, :links, %{}) |> Map.merge(links)
    end

    Map.put(doc, :links, links)
  end
end
