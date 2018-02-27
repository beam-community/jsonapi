defmodule JSONAPI.Ecto do
  @moduledoc """
  Helper functions for working with Ecto
  """

  @doc """
  Checks to see if an associated table is Loaded.

  If the model is an `Ecto.Association.NotLoaded`
  """
  def assoc_loaded?(association) do
    case association do
      %{__struct__: Ecto.Association.NotLoaded} -> false
      _ -> true
    end
  end
end
