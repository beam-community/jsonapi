defmodule JSONAPI.Utils.Underscore do
  @moduledoc """
  DEPRECATED. Please Use `JSONAPI.Utils.String` instead.
  """

  @doc """
  Replace dashes between words in `value` with underscores

  Ignores dashes that are not between letters/numbers
  """
  @deprecated "Use JSONAPI.Utils.String.underscore/1 instead"
  def dash(value) do
    JSONAPI.Utils.String.underscore(value)
  end

  @doc """
  Replace underscores between words in `value` with dashes

  Ignores underscores that are not between letters/numbers
  """
  @deprecated "Use JSONAPI.Utils.String.dasherize/1 instead"
  def underscore(value) do
    JSONAPI.Utils.String.dasherize(value)
  end
end
