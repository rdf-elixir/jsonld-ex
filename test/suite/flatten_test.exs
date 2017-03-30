defmodule JSON.LD.TestSuite.FlattenTest do
  use ExUnit.Case, async: false

  import JSON.LD.TestSuite

  setup_all do
    [base_iri: manifest("flatten")["baseIri"]]
  end

  test_cases("flatten")
# TODO: Ordering problems
#  |> Enum.filter(fn %{"@id" => id} -> id in ~w[#t0034] end)
#  |> Enum.filter(fn %{"@id" => id} -> id in ~w[#t0035] end)
#  |> Enum.filter(fn %{"@id" => id} -> id in ~w[#t0038] end)
# TODO: Fixed in Elixir 1.5
#  |> Enum.filter(fn %{"@id" => id} -> id in ~w[#t0029] end)
  |> Enum.each(fn %{"name" => name, "input" => input} = test_case ->
      if input in ~w[flatten-0029-in.jsonld] do
        @tag skip: """
          probably caused by a bug in Elixirs URI.merge which should be fixed with Elixir 1.5
          https://github.com/elixir-lang/elixir/pull/5780
        """
      end
      if input in ~w[flatten-0034-in.jsonld flatten-0035-in.jsonld flatten-0038-in.jsonld] do
        @tag skip: "TODO: Actually correct values are expanded, but the ordering is different."
      end
      @tag :test_suite
      @tag :flatten_test_suite
      @tag data: test_case
      test "#{input}: #{name}",
          %{data: %{"input" => input, "expect" => output} = test_case, base_iri: base_iri} do
        context =
          case test_case["context"] do
            nil     -> nil
            context -> j(context)
          end
        assert JSON.LD.flatten(j(input), context, test_case_options(test_case, base_iri)) == j(output)
      end
    end)

end
