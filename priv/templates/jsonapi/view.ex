defmodule <%= module %>View do
  use <%= base %>.Web, :view

  use JSONAPI.PhoenixView

  def type, do: "<%= singular %>"

  def attributes(model) do
    Map.take(model, [ :id,
      <%= for {k, _} <- attrs do %> <%= inspect k %>,
      <% end %>
      :created_at, :updated_at ])
  end

  def relationships() do
    %{}
  end

  def url_func() do
    &<%= singular %>_url/3
  end
end
