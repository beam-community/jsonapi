defmodule Deprecation do
  def warn(:includes) do
    IO.warn "`%JSONAPI.Config{}.includes` is deprecated; call `%JSONAPI.Config{}.include` instead.",
    Macro.Env.stacktrace(__ENV__)
  end
end
