defmodule JSON.LD.TestSuite.RemoteDocTest do
  use ExUnit.Case, async: false

  import JSON.LD.TestSuite

  setup_all do
    [base_iri: manifest("remote-doc")["baseIri"]]
  end

  test_cases("remote-doc")
  |> Enum.each(fn %{"name" => name, "input" => input} = test_case ->
    if input in ~w[
          remote-doc-0005-in.jsonld
          remote-doc-0006-in.jsonld
          remote-doc-0007-in.jsonld
          remote-doc-0008-in.jsonld
        ] do
      @tag skip: "TODO: Missed test file"
    end

    if input in ~w[
          remote-doc-0009-in.jsonld
          remote-doc-0010-in.json
          remote-doc-0011-in.jldt
          remote-doc-0012-in.json
        ] do
      @tag skip: "TODO: Context from Link header is unsupported"
    end

    @tag :test_suite
    @tag :remote_doc_test_suite
    @tag data: test_case
    case hd(test_case["@type"]) do
      "jld:PositiveEvaluationTest" ->
        test "#{input}: #{name}",
             %{data: %{"input" => input, "expect" => output} = test_case, base_iri: base_iri} do
          assert JSON.LD.expand(j(input), test_case_options(test_case, base_iri)) == j(output)
        end

      "jld:NegativeEvaluationTest" ->
        @tag skip: "TODO: "
        test "#{input}: #{name}",
             %{data: %{"input" => input, "expect" => error} = test_case, base_iri: base_iri} do
        end
    end
  end)
end
