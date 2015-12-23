defmodule JSONAPI.Mixfile do
  use Mix.Project

  def project do
    [app: :jsonapi,
      version: "0.0.2",
      package: package(),
      elixir: "~> 1.0",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      source_url: "https://github.com/jeregrine/jsonapi",
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
      {:plug, "~> 1.0"},
      {:ex_doc, "~> 0.7", only: :dev},
      {:earmark, ">= 0.0.0", only: :dev},
      {:poison, "~> 1.5.0", only: :test}
    ]
  end

  defp package do
    [contributors: ["Jason Stiebs", "Mitchell Henke", "Jake Robers"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/jeregrine/jsonapi", docs: "http://hexdocs.pm/jsonapi/"}]
  end

end
