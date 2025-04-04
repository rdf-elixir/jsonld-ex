defmodule JSON.LD.W3C.ToRdfTest do
  @moduledoc """
  The official W3C JSON.LD 1.1 Test Suite for the _Deserialize JSON-LD to RDF Algorithm_.

  See <https://w3c.github.io/json-ld-api/tests/toRdf-manifest.html>.
  """

  use ExUnit.Case, async: false
  use RDF.EarlFormatter, test_suite: :toRdf

  import JSON.LD.TestSuite
  import ExUnit.CaptureLog
  import RDF.Test.Assertions

  @manifest manifest("toRdf")
  @base expanded_base_iri(@manifest)

  @manifest
  |> test_cases()
  |> test_cases_by_type()
  |> Enum.each(fn
    {:positive_evaluation_test, test_cases} ->
      for %{"@id" => id, "name" => name} = test_case <- test_cases do
        skip_json_ld_1_0_test(test_case)

        if id == "#te122", do: @tag(skip: "https://github.com/w3c/json-ld-api/issues/480")

        if not Version.match?(System.version(), ">= 1.19.0") and
             id in [
               # Bug in Elixir's URI.merge/2 removing trailing slash at root path
               # https://github.com/elixir-lang/elixir/pull/14346
               "#t0123",
               # Bug in Elixir's URI.merge/2 handling dots without a trailing slash in base URIs incorrect
               # https://github.com/elixir-lang/elixir/pull/14341
               "#t0124",
               "#t0125",
               # Bug in Elixir's URI.merge/2 resulting in '(ArgumentError) you must merge onto an absolute URI '
               # https://github.com/elixir-lang/elixir/pull/14344
               "#t0130",
               "#t0131",
               "#t0132",
               # Bug in Elixir's URI.merge/2 handling of base without host and path
               # https://github.com/elixir-lang/elixir/pull/14358
               "#tli11"
             ] do
          @tag skip: "missing fixes of URI.merge/2"
        end

        if get_in(test_case["option"]["produceGeneralizedRdf"]) do
          # affected test cases: t0118 and te075
          # see also: https://github.com/w3c/json-ld-api/issues/205 and https://github.com/w3c/json-ld-api/issues/546
          @tag skip: "TODO: missing generalized RDF support"
        end

        if id == "#tc031", do: @tag(skip: "TODO: JSON.LD.LoadingRemoteContextFailedError")

        @tag :test_suite
        @tag :to_rdf_test_suite
        @tag test_case: RDF.iri(@base <> id)
        @tag data: test_case
        test "toRdf#{id}: #{name}", %{data: %{"input" => input, "expect" => expected} = test_case} do
          dataset = RDF.NQuads.read_file!(file(expected))

          if test_case["@id"] in ~w[#te005 #tpr34 #tpr35 #tpr36 #tpr37 #tpr38 #tpr39 #te119 #te120] do
            log =
              capture_log(fn ->
                assert_rdf_isomorphic(
                  JSON.LD.read_file!(file(input), test_case_options(test_case, @base)),
                  dataset
                )
              end)

            assert log =~
                     ~r/\[warning\] \w+ beginning with '@' are reserved for future use and ignored/
          else
            assert_rdf_isomorphic(
              JSON.LD.read_file!(file(input), test_case_options(test_case, @base)),
              dataset
            )
          end
        end
      end

    {:negative_evaluation_test, test_cases} ->
      for %{"@id" => id, "name" => name} = test_case <- test_cases do
        skip_json_ld_1_0_test(test_case)

        @tag :test_suite
        @tag :to_rdf_test_suite
        @tag test_case: RDF.iri(@base <> id)
        @tag data: test_case
        test "toRdf#{id}: #{name}", %{
          data: %{"input" => input, "expectErrorCode" => error} = test_case
        } do
          assert_raise exception(error), fn ->
            JSON.LD.read_file!(file(input), test_case_options(test_case, @base))
          end
        end
      end

    {:positive_syntax_test, test_cases} ->
      for %{"@id" => id, "name" => name} = test_case <- test_cases do
        skip_json_ld_1_0_test(test_case)

        @tag :test_suite
        @tag :to_rdf_test_suite
        @tag test_case: RDF.iri(@base <> id)
        @tag data: test_case
        test "toRdf#{id}: #{name}", %{data: %{"input" => input} = test_case} do
          assert %RDF.Dataset{} =
                   JSON.LD.read_file!(file(input), test_case_options(test_case, @base))
        end
      end
  end)
end
