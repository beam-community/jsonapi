defmodule Deprecation do
  @moduledoc """
    Generate warnings in places where we want to deprecate functions or struct parameters
  """

  @doc """
    Generates a deprecation warning for `includes` in the JSONAPI.Config struct.
  """

  def warn(:includes) do
    IO.warn(
      "`%JSONAPI.Config{}.includes` is deprecated; call `%JSONAPI.Config{}.include` instead.",
      Macro.Env.stacktrace(__ENV__)
    )
  end
end
