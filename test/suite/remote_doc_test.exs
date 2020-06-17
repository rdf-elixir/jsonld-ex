defmodule JSON.LD.TestSuite.RemoteDocTest do
  use ExUnit.Case, async: false

  import JSON.LD.TestSuite

  setup_all do
    [base_iri: manifest("remote-doc")["baseIri"]]
  end

  test_cases("remote-doc")
  |> Enum.each(fn %{"name" => name, "input" => input} = test_case ->
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
               %{data: %{"input" => input, "expect" => output} = test_case, base_iri: base_iri} do
          end
      end
    end)
end
