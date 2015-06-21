defmodule JSONAPI.Mixfile do
  use Mix.Project

  def project do
    [app: :jsonapi,
      version: "0.0.1",
      package: package(),
      elixir: "~> 1.0",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    []
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:phoenix, "~> 0.13"},
      {:ecto, "~> 0.11"},
      {:ex_doc, "~> 0.7", only: :dev},
      {:earmark, ">= 0.0.0", only: :dev}
    ]
  end

  defp package do
    [contributors: ["Jason Stiebs"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/jeregrine/jsonapi"}]
  end

end
