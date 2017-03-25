defmodule JSON.LD.TestSuite.CompactTest do
  use ExUnit.Case, async: false

  import JSON.LD.TestSuite

  setup_all do
    [base_iri: manifest("compact")["baseIri"]]
  end

  test_cases("compact")
  |> Enum.each(fn %{"name" => name, "input" => input} = test_case ->
      @tag :test_suite
      @tag :compact_test_suite
      @tag data: test_case
      test "#{input}: #{name}",
          %{data: %{"input" => input, "expect" => output, "context" => context} = test_case, base_iri: base_iri} do
        assert JSON.LD.compact(j(input), j(context), test_case_options(test_case, base_iri)) == j(output)
      end
    end)

end
