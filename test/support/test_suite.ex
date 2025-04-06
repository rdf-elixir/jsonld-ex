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

  @run_mode Application.compile_env(:json_ld, :w3c_test_suite_run_mode, :local)
  def run_mode, do: @run_mode

  case @run_mode do
    :local ->
      @path JSON.LD.TestData.file("json-ld-api-tests")

      def parse_json_file!(file) do
        case File.read(file(file)) do
          {:ok, content} -> Jason.decode!(content)
          {:error, reason} -> raise File.Error, path: file, action: "read", reason: reason
        end
      end

      def parse_nquads(file) do
        file
        |> file()
        |> RDF.NQuads.read_file!()
      end

    :remote ->
      @path "https://w3c.github.io/json-ld-api/tests/"
      def parse_json_file!(file) do
        file
        |> file()
        |> JSON.LD.DocumentLoader.RemoteDocument.load!()
        |> Map.get(:document)
      end

      def parse_nquads(file) do
        url = file(file)

        case HTTPoison.get(url) do
          {:ok, %HTTPoison.Response{status_code: status} = response} when status in 200..299 ->
            RDF.NQuads.read_string!(response.body)

          {:ok, %{status_code: status}} ->
            raise "HTTP request of #{url} failed with status #{status}"

          {:error, error} ->
            raise error
        end
      end

    invalid ->
      raise "Invalid W3C test suite run mode: #{inspect(invalid)}; allowed are local and remote"
  end

  defdelegate j(file), to: __MODULE__, as: :parse_json_file!

  def file({type, name}), do: file(type, name)
  def file(name), do: Path.join(@path, name)
  def file(type, name), do: Path.join([@path, to_string(type), name])

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

  def test_case_options(test_case) do
    test_case
    |> Map.get("option", %{})
    |> Enum.map(fn {key, value} ->
      {key |> Macro.underscore() |> String.to_atom(), value}
    end)
    |> Enum.map(fn
      {:expand_context, file} -> {:expand_context, j(file)}
      option -> option
    end)
  end

  def test_case_options(test_case, %{"baseIri" => base_iri}),
    do: test_case_options(test_case, base_iri)

  def test_case_options(test_case, base_iri) do
    test_case
    |> test_case_options()
    |> Keyword.put_new(:base, base_iri <> test_case["input"])
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

  def skip_map(skipped, mode \\ nil) do
    Enum.flat_map(skipped, fn
      {tests, message} -> Enum.map(tests, &{&1, message})
      {^mode, tests, message} -> Enum.map(tests, &{&1, message})
      {_mode, _tests, _message} -> []
    end)
    |> Map.new()
  end

  defmacro skip_test(id, skipped) do
    quote do
      if message = unquote(skipped)[unquote(id)] do
        @tag skip: message
      end
    end
  end

  defmacro skip_json_ld_1_0_test(test_case) do
    quote do
      if get_in(unquote(test_case), ["option", "specVersion"]) == "json-ld-1.0" do
        @tag skip: "JSON-LD 1.0 test"
      end
    end
  end
end
