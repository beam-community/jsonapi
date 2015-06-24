defmodule Post do
  defstruct [:id, :user_id, :user, :body]
end

defmodule User do
  defstruct [:id, :email]
end

defmodule MyApp.UserView do
  use Phoenix.View, root: "test/fixtures/templates"
  use JSONAPI.PhoenixView

  def type, do: "user"

  def attributes(model) do
    Map.take(model, [:email])
  end

  def url_func() do
    # &post_url/3
  end
end

defmodule MyApp.PostView do
  use Phoenix.View, root: "test/fixtures/templates"
  use JSONAPI.PhoenixView

  def type, do: "post"

  def attributes(model) do
    Map.take(model, [:body])
  end

  def relationships() do
    %{
      user: %{
        view: MyApp.UserView
      },
    }
  end

  def url_func() do
    # &user_url/3
  end
end

