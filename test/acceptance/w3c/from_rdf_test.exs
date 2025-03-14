defmodule JSON.LD.W3C.FromRdfTest do
  @moduledoc """
  The official W3C JSON.LD 1.1 Test Suite for the _Serialize RDF as JSON-LD Algorithm_.

  See <https://w3c.github.io/json-ld-api/tests/fromRdf-manifest.html>.
  """

  use ExUnit.Case, async: false
  use RDF.EarlFormatter, test_suite: :fromRdf

  import JSON.LD.TestSuite

  @manifest manifest("fromRdf")
  @base expanded_base_iri(@manifest)

  @manifest
  |> test_cases()
  |> test_cases_by_type()
  |> Enum.each(fn
    {:positive_evaluation_test, test_cases} ->
      for %{"@id" => id, "name" => name} = test_case <- test_cases do
        skip_json_ld_1_0_test(test_case)

        if id in [
             "#t0001",
             "#t0002",
             "#t0017",
             "#t0018",
             "#t0019"
           ] do
          @tag skip:
                 "TODO: JSON-LD Object comparison - Actually correct values are produced, but the ordering is different."
        end

        if id in [
             "#tli03",
             "#tli02",
             "#tli01"
           ] do
          @tag skip: "TODO: fix nested list handling"
        end

        @tag :test_suite
        @tag :from_rdf_test_suite
        @tag test_case: RDF.iri(@base <> id)
        @tag data: test_case
        test "fromRdf#{id}: #{name}", %{
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
          assert_raise exception(error), fn ->
            serialize(input, test_case_options(test_case, @base))
          end
        end
      end
  end)

  def serialize(filename, options) do
    filename
    |> file
    |> RDF.NQuads.read_file!()
    |> JSON.LD.Encoder.from_rdf!(options)
  end
end
