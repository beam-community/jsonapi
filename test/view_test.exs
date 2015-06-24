Code.require_file "./fixtures/views.exs", __DIR__

defmodule JSONAPITest.View do
  use ExUnit.Case

  # http://jsonapi.org/format/#document-top-level
  test "renders single top level correctly" do
    user = %User{id: 1, email: "test@test.com"}
    post = %Post{id: 3, user_id: user.id, user: user, body: "Test Body"}
    rendered = JSONAPI.show(MyApp.PostView, post, nil, nil)

    assert(conforms_to_json_api_spec(rendered))
  end

  def conforms_to_json_api_spec(document) when is_map(document) do
    assert is_map(document)
    assert(has_valid_top_level(document))
    assert(does_not_have_invalid_top_level_keys(document))
  end

  defp does_not_have_invalid_top_level_keys(document) do
    invalid_keys_count = Dict.drop(document, valid_top_level_keys)
    |> Dict.keys
    |> Enum.count

    invalid_keys_count == 0
  end

  defp has_valid_top_level(%{data: data} = rendered) do
    assert Dict.has_key?(rendered, :errors) == false
    assert is_map(data) || is_list(data) || is_nil(data)

    assert(has_valid_data(data))

  end

  defp has_valid_top_level(%{errors: errors} = rendered) when is_list(errors) do
    assert Dict.has_key?(rendered, :data) == false
  end

  defp has_valid_top_level(%{meta: meta} = rendered) when is_map(meta) do
    assert Dict.has_key?(rendered, :data) == false
    assert Dict.has_key?(rendered, :included) == false
  end

  defp valid_top_level_keys do
    [:jsonapi, :links, :included, :data, :errors]
  end

  defp has_valid_attributes(%{attributes: attributes}) when is_map(attributes), do: true
  defp has_valid_attributes(%{attributes: nil}), do: false
  defp has_valid_attributes(_data), do: true

  defp has_valid_relationships(%{relationships: nil}), do: false
  defp has_valid_relationships(_data), do: true
  defp has_valid_relationships(%{relationships: relationships}) when is_map(relationships) do
    relationships
  end

  defp has_valid_data(nil), do: true
  defp has_valid_data(data_object) when is_map(data_object) do
    assert is_binary(Dict.get(data_object, :id))
    assert is_binary(Dict.get(data_object, :type))

    assert has_valid_attributes(data_object)
    assert has_valid_relationships(data_object)
  end
  defp has_valid_data(data_list) when is_list(data_list) do
    # TODO: no duplicates for [type, id] combination
    Enum.each(data_list, fn(data) ->
      assert(is_map(data))
      assert(has_valid_data(data))
    end)
  end

  defp is_valid_relationship_object(%{links: links} when is_map(links) do

  end

  defp is_valid_relationship_object(%{data: data}) do
    has_valid_data(data)
  end

  defp is_valid_relationship_object(%{meta: meta}) when is_map(meta) do
  end
end
