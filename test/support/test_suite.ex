defmodule JSON.LD.TestSuite do

  @test_suite_dir "json-ld.org-test-suite"
  def test_suite_dir, do: @test_suite_dir

  def file(name), do: JSON.LD.TestData.file(Path.join(@test_suite_dir, name))

  def parse_json_file!(file) do
    case File.read(file(file)) do
      {:ok,   content} -> Jason.decode!(content)
      {:error, reason} -> raise File.Error, path: file, action: "read", reason: reason
    end
  end

  def j(file), do: parse_json_file!(file)

  def manifest_filename(type), do: "#{to_string(type)}-manifest.jsonld"

  def manifest(type) do
    type
    |> manifest_filename
    |> parse_json_file!
  end

  def test_cases(type), do: manifest(type)["sequence"]

  def test_cases_by_type(test_cases) do
    Enum.group_by(test_cases, fn %{"@type" => type} ->
      cond do
        "jld:PositiveEvaluationTest" in type -> :positive_evaluation_test
        "jld:NegativeEvaluationTest" in type -> :negative_evaluation_test
        "jld:PositiveSyntaxTest"     in type -> :positive_syntax_test
        "jld:NegativeSyntaxTest"     in type -> :negative_syntax_test
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
        {key |> Macro.underscore |> String.to_atom, value}
       end)
    |> Enum.map(fn
        {:expand_context, file} -> {:expand_context, j(file)}
        option -> option
       end)
    |> JSON.LD.Options.new
  end

  def exception(error) do
    error = error
    |> String.replace(" ", "_")
    |> String.replace("-", "_")
    |> String.replace("@", "_")
    |> Macro.camelize
    |> String.replace("_", "")
    String.to_existing_atom("Elixir.JSON.LD.#{error}Error")
  end

end
