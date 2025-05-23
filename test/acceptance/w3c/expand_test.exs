defmodule JSON.LD.W3C.ExpandTest do
  @moduledoc """
  The official W3C JSON.LD 1.1 Test Suite for the _Expansion Algorithm_.

  See <https://w3c.github.io/json-ld-api/tests/expand-manifest.html>.
  """

  use ExUnit.Case, async: false
  use RDF.Test.EarlFormatter, test_suite: :"json-ld-api"

  import JSON.LD.TestSuite
  import JSON.LD.Case
  import ExUnit.CaptureLog

  @test_suite_name "expand"
  @manifest manifest(@test_suite_name)
  @base expanded_base_iri(@manifest)

  @cases_with_warnings ~w[#t0005 #tpr34 #tpr35 #tpr36 #tpr37 #tpr38 #tpr39 #t0119 #t0120]

  @skipped [
    {:unordered,
     [
       "#t0034",
       "#t0035",
       "#tin03",
       "#tdi03",
       "#tn004"
     ],
     %{
       message:
         "JSON-LD Object comparison - Actually correct values are expanded, but the ordering is different.",
       earl_result: :passed,
       earl_mode: :semi_auto
     }},
    {:ordered,
     [
       "#t0034",
       "#t0035",
       "#tin03",
       "#tdi03"
     ],
     %{
       message:
         "JSON-LD Object comparison - Actually correct values are expanded, but the ordering is different.",
       earl_result: :passed,
       earl_mode: :semi_auto
     }}
  ]
  @skipped_ordered skip_map(@skipped, :ordered)
  @skipped_unordered skip_map(@skipped, :unordered)

  @manifest
  |> test_cases()
  |> test_cases_by_type()
  |> Enum.each(fn
    {:positive_evaluation_test, test_cases} ->
      for %{"@id" => id, "name" => name} = test_case <- test_cases do
        skip_json_ld_1_0_test(test_case)
        skip_test(id, @skipped_ordered)
        @tag :test_suite
        @tag :expand_test_suite
        @tag ordered: true
        @tag test_case: RDF.iri(@base <> @test_suite_name <> "-manifest" <> id)
        @tag data: test_case
        test "expand#{id}: #{name} (ordered)", %{
          data: %{"input" => input, "expect" => expected} = test_case
        } do
          if test_case["@id"] in @cases_with_warnings do
            log =
              capture_log(fn ->
                assert JSON.LD.expand(
                         j(input),
                         test_case_options(test_case, @base) |> Keyword.put_new(:ordered, true)
                       ) ==
                         j(expected)
              end)

            assert log =~
                     ~r/\[warning\] \w+ beginning with '@' are reserved for future use and ignored/
          else
            assert JSON.LD.expand(
                     j(input),
                     test_case_options(test_case, @base) |> Keyword.put_new(:ordered, true)
                   ) ==
                     j(expected)
          end
        end

        skip_json_ld_1_0_test(test_case)
        skip_test(id, @skipped_unordered)
        @tag :test_suite
        @tag :expand_test_suite
        @tag ordered: false
        @tag test_case: RDF.iri(@base <> @test_suite_name <> "-manifest" <> id)
        @tag data: test_case
        test "expand#{id}: #{name} (unordered)", %{
          data: %{"input" => input, "expect" => expected} = test_case
        } do
          if test_case["@id"] in @cases_with_warnings do
            log =
              capture_log(fn ->
                assert JSON.LD.expand(j(input), test_case_options(test_case, @base)) ==
                         j(expected)
              end)

            assert log =~
                     ~r/\[warning\] \w+ beginning with '@' are reserved for future use and ignored/
          else
            assert JSON.LD.expand(j(input), test_case_options(test_case, @base)) ==
                     j(expected)
          end
        end
      end

    {:negative_evaluation_test, test_cases} ->
      for %{"@id" => id, "name" => name} = test_case <- test_cases do
        skip_json_ld_1_0_test(test_case)
        @tag :test_suite
        @tag :expand_test_suite
        @tag test_case: RDF.iri(@base <> @test_suite_name <> "-manifest" <> id)
        @tag data: test_case
        test "expand#{id}: #{name}", %{
          data: %{"input" => input, "expectErrorCode" => error} = test_case
        } do
          if test_case["@id"] in @cases_with_warnings do
            log =
              capture_log(fn ->
                assert_raise_json_ld_error error, fn ->
                  JSON.LD.expand(j(input), test_case_options(test_case, @base))
                end
              end)

            assert log =~
                     ~r/\[warning\] \w+ beginning with '@' are reserved for future use and ignored/
          else
            assert_raise_json_ld_error error, fn ->
              JSON.LD.expand(j(input), test_case_options(test_case, @base))
            end
          end
        end
      end
  end)
end
