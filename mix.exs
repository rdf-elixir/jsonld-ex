defmodule JSON.LD.Mixfile do
  use Mix.Project

  @repo_url "https://github.com/marcelotto/jsonld-ex"

  @version "0.1.0"

  def project do
    [
      app: :json_ld,
      version: @version,
      elixir: "~> 1.4", # TODO: "~> 1.5" for the fix of URI.merge
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),

      # Hex
      package: package(),
      description: description(),

      # Docs
      name: "JSON-LD.ex",
      docs: [
        main: "JSON.LD",
        source_url: @repo_url,
        source_ref: "v#{@version}",
        extras: ["README.md"],
      ]
    ]
  end

  defp description do
    """
    An implementation of JSON-LD for Elixir and RDF.ex.
    """
  end

  defp package do
    [
      maintainers: ["Marcel Otto"],
      licenses: ["MIT"],
      links: %{"GitHub" => @repo_url},
      files: ~w[lib mix.exs README.md LICENSE.md]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:rdf, "~> 0.1"},
      {:poison, "~> 3.0"},
      {:dialyxir, "~> 0.4",       only: [:dev, :test], runtime: false},
      {:credo, "~> 0.6",          only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.14",        only: :dev, runtime: false},
      {:mix_test_watch, "~> 0.3", only: :dev, runtime: false},
    ]
  end
end
