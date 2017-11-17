defmodule <%= module %>View do
  use <%= base %>.Web, :view
  use JSONAPI.PhoenixView

  def render("index.json", %{<%= plural %>: <%= plural %>}) do
    %{data: render_many(<%= plural %>, <%= module %>View, "<%= singular %>.json")}
  end

  def render("show.json", %{<%= singular %>: <%= singular %>}) do
    %{data: render_one(<%= singular %>, <%= module %>View, "<%= singular %>.json")}
  end

  def render("<%= singular %>.json", %{<%= singular %>: <%= singular %>}) do
    %{id: <%= singular %>.id<%= for {k, _} <- attrs do %>,
      <%= k %>: <%= singular %>.<%= k %><% end %>}
  end


  def fields(), do: [:text, :body]
  def type(), do: "<%= singular %>"
  def relationships(), do: []
end
