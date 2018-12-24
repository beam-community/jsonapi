defmodule JSONAPI.Deprecation do
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

  def warn(:hidden) do
    IO.warn(
      "`JSONAPI.View.hidden/0` is deprecated; use `JSONAPI.View.hidden/1` instead.",
      Macro.Env.stacktrace(__ENV__)
    )
  end
end
