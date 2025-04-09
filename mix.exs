defmodule JSON.LD.Mixfile do
  use Mix.Project

  @repo_url "https://github.com/rdf-elixir/jsonld-ex"

  @version File.read!("VERSION") |> String.trim()

  def project do
    [
      app: :json_ld,
      version: @version,
      elixir: "~> 1.15",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),

      # Hex
      package: package(),
      description: description(),

      # Docs
      name: "JSON-LD.ex",
      docs: [
        main: "JSON.LD",
        source_url: @repo_url,
        source_ref: "v#{@version}",
        extras: ["README.md", "CHANGELOG.md"]
      ],

      # Dialyzer
      dialyzer: dialyzer(),

      # ExCoveralls
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        check: :test,
        earl_reports: :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
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
      files: ~w[lib mix.exs README.md LICENSE.md VERSION]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      # TODO: Change back to hex version once v2.1 is released
      {:rdf, github: "rdf-elixir/rdf-ex"},
      {:jason, "~> 1.2"},
      {:tesla, "~> 1.2"},
      {:hackney, "~> 1.21", only: [:dev, :test]},
      {:gun, "~> 2.1", only: [:dev, :test]},
      {:mint, "~> 1.6", only: [:dev, :test]},
      {:castore, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.2", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:bypass, "~> 2.1", only: :test},
      {:mox, "~> 1.2", only: :test},
      {:excoveralls, "~> 0.15", only: :test}
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
    ]
  end

  defp aliases do
    [
      earl_reports: &earl_reports/1,
      check: [
        "clean",
        "deps.unlock --check-unused",
        "compile --warnings-as-errors",
        "format --check-formatted",
        "test --warnings-as-errors",
        "credo"
      ]
    ]
  end

  defp earl_reports(_) do
    files = [
      "test/acceptance/w3c/compact_test.exs",
      "test/acceptance/w3c/expand_test.exs",
      "test/acceptance/w3c/flatten_test.exs",
      "test/acceptance/w3c/from_rdf_test.exs",
      "test/acceptance/w3c/to_rdf_test.exs",
      "test/acceptance/w3c/remote_doc_test.exs"
    ]

    Mix.Task.run(
      "test",
      ["--formatter", "RDF.Test.EarlFormatter", "--exclude", "ordered:false", "--seed", "0"] ++
        files
    )
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
