defmodule JSON.LD.W3C.CompactTest do
  @moduledoc """
  The official W3C JSON.LD 1.1 Test Suite for the _Compaction Algorithm_.

  See <https://w3c.github.io/json-ld-api/tests/compact-manifest.html>.
  """

  use ExUnit.Case, async: false
  use RDF.EarlFormatter, test_suite: :compact

  import JSON.LD.TestSuite
  import JSON.LD.Case

  @manifest manifest("compact")
  @base expanded_base_iri(@manifest)

  @skipped skip_map([
             {["#t0114"], "Is this test actually correct? No implementation runs this test."}
           ])

  @manifest
  |> test_cases()
  |> test_cases_by_type()
  |> Enum.each(fn
    {:positive_evaluation_test, test_cases} ->
      for %{"@id" => id, "name" => name} = test_case <- test_cases do
        skip_test(id, @skipped)
        skip_json_ld_1_0_test(test_case)
        @tag :test_suite
        @tag :compact_test_suite
        @tag test_case: RDF.iri(@base <> id)
        @tag data: test_case
        test "compact#{id}: #{name} (ordered)", %{
          data: %{"input" => input, "expect" => expected, "context" => context} = test_case
        } do
          assert JSON.LD.compact(
                   j(input),
                   j(context),
                   test_case_options(test_case, @base) |> Keyword.put_new(:ordered, true)
                 ) ==
                   j(expected)
        end

        skip_test(id, @skipped)
        skip_json_ld_1_0_test(test_case)
        @tag :test_suite
        @tag :compact_test_suite
        @tag test_case: RDF.iri(@base <> id)
        @tag data: test_case
        test "compact#{id}: #{name} (unordered)", %{
          data: %{"input" => input, "expect" => expected, "context" => context} = test_case
        } do
          assert JSON.LD.compact(j(input), j(context), test_case_options(test_case, @base)) ==
                   j(expected)
        end
      end

    {:negative_evaluation_test, test_cases} ->
      for %{"@id" => id, "name" => name} = test_case <- test_cases do
        skip_json_ld_1_0_test(test_case)
        @tag :test_suite
        @tag :compact_test_suite
        @tag test_case: RDF.iri(@base <> id)
        @tag data: test_case
        test "compact#{id}: #{name}", %{
          data: %{"input" => input, "expectErrorCode" => error, "context" => context} = test_case
        } do
          assert_raise_json_ld_error error, fn ->
            JSON.LD.compact(j(input), j(context), test_case_options(test_case, @base))
          end
        end
      end
  end)
end
