defmodule JSON.LD.W3C.FromRdfTest do
  @moduledoc """
  The official W3C JSON.LD 1.1 Test Suite for the _Serialize RDF as JSON-LD Algorithm_.

  See <https://w3c.github.io/json-ld-api/tests/fromRdf-manifest.html>.
  """

  use ExUnit.Case, async: false
  use RDF.Test.EarlFormatter, test_suite: :fromRdf

  import JSON.LD.TestSuite
  import JSON.LD.Case

  @manifest manifest("fromRdf")
  @base expanded_base_iri(@manifest)

  @skipped skip_map([
             {[
                "#t0001",
                "#t0002",
                "#t0017",
                "#t0018",
                "#t0019"
              ],
              "JSON-LD Object comparison - Actually correct values are produced, but the ordering is different."},
             {["#t0027"],
              "TODO: apply change from https://github.com/w3c/json-ld-api/pull/625 fixing https://github.com/w3c/json-ld-api/issues/555"}
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
        @tag :from_rdf_test_suite
        @tag test_case: RDF.iri(@base <> id)
        @tag data: test_case
        test "fromRdf#{id}: #{name} (ordered)", %{
          data: %{"input" => input, "expect" => expected} = test_case
        } do
          assert serialize(
                   input,
                   test_case_options(test_case, @base) |> Keyword.put_new(:ordered, true)
                 ) == j(expected)
        end

        skip_test(id, @skipped)
        skip_json_ld_1_0_test(test_case)
        @tag :test_suite
        @tag :from_rdf_test_suite
        @tag test_case: RDF.iri(@base <> id)
        @tag data: test_case
        test "fromRdf#{id}: #{name} (unordered)", %{
          data: %{"input" => input, "expect" => expected} = test_case
        } do
          assert serialize(input, test_case_options(test_case, @base)) == j(expected)
        end
      end

    {:negative_evaluation_test, test_cases} ->
      for %{"@id" => id, "name" => name} = test_case <- test_cases do
        skip_json_ld_1_0_test(test_case)

        @tag :test_suite
        @tag :from_rdf_test_suite
        @tag test_case: RDF.iri(@base <> id)
        @tag data: test_case
        test "fromRdf#{id}: #{name}", %{
          data: %{"input" => input, "expectErrorCode" => error} = test_case
        } do
          assert_raise_json_ld_error error, fn ->
            serialize(input, test_case_options(test_case, @base))
          end
        end
      end
  end)

  def serialize(filename, options) do
    filename
    |> parse_nquads()
    |> JSON.LD.Encoder.from_rdf!(options)
  end
end
