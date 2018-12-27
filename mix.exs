defmodule JSONAPI.Mixfile do
  use Mix.Project

  def project do
    [
      app: :jsonapi,
      version: "0.8.0",
      package: package(),
      compilers: compilers(Mix.env()),
      description: description(),
      elixir: "~> 1.0",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      source_url: "https://github.com/jeregrine/jsonapi",
      deps: deps(),
      docs: [
        extras: [
          "README.md"
        ],
        main: "readme"
      ]
    ]
  end

  # Use Phoenix compiler depending on environment.
  defp compilers(:test), do: [:phoenix] ++ Mix.compilers()
  defp compilers(_), do: Mix.compilers()

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.0"},
      {:jason, "~> 1.0", optional: true},
      {:ex_doc, "~> 0.7", only: :dev},
      {:earmark, ">= 0.0.0", only: :dev},
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:phoenix, "~> 1.3", only: :test}
    ]
  end

  defp package do
    [
      maintainers: ["Jason Stiebs", "Mitchell Henke", "Jake Robers", "Sean Callan"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/jeregrine/jsonapi", docs: "http://hexdocs.pm/jsonapi/"}
    ]
  end

  defp description do
    """
    Fully functional JSONAPI V1 Serializer as well as a QueryParser for Plug based projects and applications.
    """
  end
end
