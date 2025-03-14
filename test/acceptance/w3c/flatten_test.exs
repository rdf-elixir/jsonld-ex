defmodule JSON.LD.W3C.FlattenTest do
  @moduledoc """
  The official W3C JSON.LD 1.1 Test Suite for the _Flattening Algorithm_.

  See <https://w3c.github.io/json-ld-api/tests/flatten-manifest.html>.
  """

  use ExUnit.Case, async: false
  use RDF.EarlFormatter, test_suite: :flatten

  import JSON.LD.TestSuite
  import ExUnit.CaptureLog

  @manifest manifest("flatten")
  @base expanded_base_iri(@manifest)

  @manifest
  |> test_cases()
  |> test_cases_by_type()
  |> Enum.each(fn
    {:positive_evaluation_test, test_cases} ->
      for %{"@id" => id, "name" => name} = test_case <- test_cases do
        skip_json_ld_1_0_test(test_case)

        if id in [
             "#t0034",
             "#t0035",
             "#tin03"
           ] do
          @tag skip:
                 "TODO: JSON-LD Object comparison - Actually correct values are expanded, but the ordering is different."
        end

        @tag :test_suite
        @tag :flatten_test_suite
        @tag test_case: RDF.iri(@base <> id)
        @tag data: test_case
        test "flatten#{id}: #{name}", %{
          data: %{"input" => input, "expect" => expected} = test_case
        } do
          context = if context = test_case["context"], do: j(context)

          if test_case["@id"] in ~w[#t0005] do
            log =
              capture_log(fn ->
                assert JSON.LD.flatten(j(input), context, test_case_options(test_case, @base)) ==
                         j(expected)
              end)

            assert log =~
                     ~r/\[warning\] \w+ beginning with '@' are reserved for future use and ignored/
          else
            assert JSON.LD.flatten(j(input), context, test_case_options(test_case, @base)) ==
                     j(expected)
          end
        end
      end

    {:negative_evaluation_test, test_cases} ->
      for %{"@id" => id, "name" => name} = test_case <- test_cases do
        skip_json_ld_1_0_test(test_case)

        @tag :test_suite
        @tag :flatten_test_suite
        @tag test_case: RDF.iri(@base <> id)
        @tag data: test_case
        test "flatten#{id}: #{name}", %{
          data: %{"input" => input, "expectErrorCode" => error} = test_case
        } do
          context = if context = test_case["context"], do: j(context)

          assert_raise exception(error), fn ->
            JSON.LD.flatten(j(input), context, test_case_options(test_case, @base))
          end
        end
      end
  end)
end
