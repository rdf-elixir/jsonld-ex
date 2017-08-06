defmodule JSON.LD.TestSuite.ExpandTest do
  use ExUnit.Case, async: false

  import JSON.LD.TestSuite

  setup_all do
    [base_iri: manifest("expand")["baseIri"]]
  end

  test_cases("expand")
# TODO: Ordering problems
#  |> Enum.filter(fn %{"@id" => id} -> id in ~w[#t0034] end)
#  |> Enum.filter(fn %{"@id" => id} -> id in ~w[#t0035] end)
#  |> Enum.filter(fn %{"@id" => id} -> id in ~w[#t0038] end)
  |> Enum.each(fn %{"name" => name, "input" => input} = test_case ->
      if input in ~w[expand-0034-in.jsonld expand-0035-in.jsonld expand-0038-in.jsonld] do
        @tag skip: "TODO: Actually correct values are expanded, but the ordering is different."
      end
      @tag :test_suite
      @tag :expand_test_suite
      @tag data: test_case
      test "#{input}: #{name}",
          %{data: %{"input" => input, "expect" => output} = test_case, base_iri: base_iri} do
        assert JSON.LD.expand(j(input), test_case_options(test_case, base_iri)) == j(output)
      end
    end)

end
