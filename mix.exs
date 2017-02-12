defmodule JSON.LD.Mixfile do
  use Mix.Project

  @version "0.0.1"

  def project do
    [
      app: :json_ld,
      version: @version,
      description: "An implementation of the JSON-LD standard",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.3",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      package: package(),
      deps: deps()
    ]
  end

  defp package do
    [
      name: :json_ld,
      maintainers: ["Marcel Otto"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/rdfex/json_ld",
               "Docs" => "http://rdfex.github.io/json_ld)/"},
      files: ["lib", "priv", "mix.exs", "README*", "readme*", "LICENSE*", "license*"]
    ]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [
      {:rdf_core, in_umbrella: true},
      {:poison, "~> 3.0"},
      {:dialyxir, "~> 0.4", only: [:dev, :test]},
      {:credo, "~> 0.6", only: [:dev, :test]},
      {:ex_doc, "~> 0.14", only: :dev},
      {:mix_test_watch, "~> 0.3", only: :dev},
    ]
  end
end
