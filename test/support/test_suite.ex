defmodule JSON.LD.TestSuite do
  @moduledoc """
  General helper functions for the W3C test suites.
  """

  defmodule NS do
    @moduledoc false
    use RDF.Vocabulary.Namespace

    defvocab MF,
      base_iri: "http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#",
      terms: [],
      strict: false

    defvocab JLD,
      base_iri: "https://w3c.github.io/json-ld-api/tests/vocab#",
      file: Path.absname("test/data/json-ld-api-tests/vocab.ttl"),
      strict: false
  end

  @compile {:no_warn_undefined, JSON.LD.TestSuite.NS.MF}
  @compile {:no_warn_undefined, JSON.LD.TestSuite.NS.JLD}

  @path JSON.LD.TestData.file("json-ld-api-tests")

  def file({type, name}), do: file(type, name)
  def file(name), do: Path.join(@path, name)
  def file(type, name), do: Path.join([@path, to_string(type), name])

  def parse_json_file!(file) do
    case File.read(file(file)) do
      {:ok, content} -> Jason.decode!(content)
      {:error, reason} -> raise File.Error, path: file, action: "read", reason: reason
    end
  end

  defdelegate j(file), to: __MODULE__, as: :parse_json_file!

  def manifest_file(type), do: "#{type}-manifest.jsonld"

  def manifest(type) do
    type
    |> manifest_file()
    |> parse_json_file!()
  end

  def base_iri(%{"baseIri" => base_iri}), do: base_iri

  def expanded_base_iri(%{"baseIri" => base_iri}) do
    base_iri
  end

  def test_cases(type) when is_binary(type), do: type |> manifest() |> test_cases()
  def test_cases(manifest), do: manifest["sequence"]

  def test_cases_by_type(test_cases) do
    Enum.group_by(test_cases, fn %{"@type" => type} ->
      cond do
        "jld:PositiveEvaluationTest" in type -> :positive_evaluation_test
        "jld:NegativeEvaluationTest" in type -> :negative_evaluation_test
        "jld:PositiveSyntaxTest" in type -> :positive_syntax_test
        "jld:NegativeSyntaxTest" in type -> :negative_syntax_test
      end
    end)
  end

  def test_case_options(test_case, %{"baseIri" => base_iri}),
    do: test_case_options(test_case, base_iri)

  def test_case_options(test_case, base_iri) do
    test_case
    |> Map.get("option", %{})
    |> Map.put_new("base", base_iri <> test_case["input"])
    |> Enum.map(fn {key, value} ->
      {key |> Macro.underscore() |> String.to_atom(), value}
    end)
    |> Enum.map(fn
      {:expand_context, file} -> {:expand_context, j(file)}
      option -> option
    end)
  end

  def exception(error) do
    error =
      error
      |> String.replace(" ", "_")
      |> String.replace("-", "_")
      |> String.replace("@", "_")
      |> Macro.camelize()
      |> String.replace("_", "")

    String.to_existing_atom("Elixir.JSON.LD.#{error}Error")
  end

  defmacro skip_json_ld_1_0_test(test_case) do
    quote do
      if get_in(unquote(test_case), ["option", "specVersion"]) == "json-ld-1.0" do
        @tag skip: "JSON-LD 1.0 test"
      end
    end
  end
end
