defmodule JSON.LD.TestSuite.ToRdfTest do
  use ExUnit.Case, async: false

  import JSON.LD.TestSuite
  import RDF.Sigils

  setup_all do
    [base_iri: manifest("toRdf")["baseIri"]]
  end

  test_cases("toRdf")
  # TODO: Ordering problems
  #  |> Enum.filter(fn %{"@id" => id} -> id in ~w[#t0118] end)
  |> Enum.each(fn %{"name" => name, "input" => input} = test_case ->
    if input in ~w[toRdf-0118-in.jsonld] do
      @tag skip: """
             Actually an isomorphic graph is generated, but due to different ordering
             during expansion the generated blank nodes are named different.
           """
    end

    @tag :test_suite
    @tag :to_rdf_test_suite
    @tag data: test_case
    test "#{input}: #{name}",
         %{data: %{"input" => input, "expect" => output} = test_case, base_iri: base_iri} do
      # This requires a special handling, since the N-Quad ouput file is not valid, by using blank nodes as predicates
      dataset =
        if input == "toRdf-0118-in.jsonld",
          do: toRdf_0118_dataset(),
          else: RDF.NQuads.read_file!(file(output))

      assert JSON.LD.read_file!(file(input), test_case_options(test_case, base_iri)) == dataset
    end
  end)

  def toRdf_0118_dataset do
    RDF.Dataset.new([
      {RDF.bnode("b0"), ~I<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>, RDF.bnode("b0")},
      {RDF.bnode("b0"), RDF.bnode("b0"), "plain value"},
      {RDF.bnode("b0"), RDF.bnode("b0"), ~I<http://json-ld.org/test-suite/tests/relativeIri>},
      {RDF.bnode("b0"), RDF.bnode("b0"), RDF.bnode("b0")},
      {RDF.bnode("b0"), RDF.bnode("b0"), RDF.bnode("b1")},
      {RDF.bnode("b0"), RDF.bnode("b0"), RDF.bnode("b2")},
      {RDF.bnode("b0"), RDF.bnode("b0"), RDF.bnode("b3")},
      {RDF.bnode("b1"), RDF.bnode("b0"), "term"},
      {RDF.bnode("b2"), RDF.bnode("b0"), "termId"}
    ])
  end
end
