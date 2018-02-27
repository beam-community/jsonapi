defmodule JSONAPI.Utils.IncludeTree do
  @moduledoc """
  Internal utility for building trees of resource relationships
  """

  def put_as_tree(acc, items, val) do
    [head | tail] = Enum.reverse(items)
    build_tree(Keyword.put(acc, head, val), tail)
  end

  def build_tree(acc, []), do: acc

  def build_tree(acc, [head | tail]) do
    build_tree(Keyword.put([], head, acc), tail)
  end

  def member_of_tree?([], _thing), do: true
  def member_of_tree?(_thing, []), do: false

  def member_of_tree?([path | tail], include) when is_list(include) do
    if Keyword.has_key?(include, path) do
      member_of_tree?(tail, get_base_relationships(include[path]))
    else
      false
    end
  end

  def get_base_relationships({view, :include}), do: get_base_relationships(view)

  def get_base_relationships(view) do
    Enum.map(view.relationships(), fn
      {view, :include} -> view
      view -> view
    end)
  end
end
