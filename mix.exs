defmodule JSONAPI.Mixfile do
  use Mix.Project

  def project do
    [app: :jsonapi,
      version: "0.3.0",
      package: package(),
      description: description(),
      elixir: "~> 1.0",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      source_url: "https://github.com/jeregrine/jsonapi",
      deps: deps]
  end

  def application do
    []
  end

  defp deps do
    [
      {:plug, "~> 1.0"},
      {:ex_doc, "~> 0.7", only: :dev},
      {:earmark, ">= 0.0.0", only: :dev},
      {:poison, "~> 1.5.0", only: :test}
    ]
  end

  defp package do
    [
      maintainers: ["Jason Stiebs", "Mitchell Henke", "Jake Robers"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/jeregrine/jsonapi", docs: "http://hexdocs.pm/jsonapi/"}]
  end

  defp description do
    """
    Fully functional JSONAPI V1 Serializer as well as a QueryParser for Plug based projects and applications.
    """
  end
end
