defmodule JSON.LD.TestSuite.FromRdfTest do
  use ExUnit.Case, async: false

  import JSON.LD.TestSuite


  setup_all do
    [base_iri: manifest("fromRdf")["baseIri"]]
  end

  test_cases("fromRdf")
# TODO: https://github.com/json-ld/json-ld.org/issues/357
#  |> Enum.filter(fn %{"@id" => id} -> id in ~w[#t0020] end)
#  |> Enum.filter(fn %{"@id" => id} -> id in ~w[#t0021] end)
# TODO: Ordering problems
#  |> Enum.filter(fn %{"@id" => id} -> id in ~w[#t0001] end)
#  |> Enum.filter(fn %{"@id" => id} -> id in ~w[#t0002] end)
#  |> Enum.filter(fn %{"@id" => id} -> id in ~w[#t0017] end)
#  |> Enum.filter(fn %{"@id" => id} -> id in ~w[#t0018] end)
#  |> Enum.filter(fn %{"@id" => id} -> id in ~w[#t0019] end)

  |> Enum.each(fn %{"name" => name, "input" => input} = test_case ->
      if input in ~w[fromRdf-0001-in.nq fromRdf-0002-in.nq fromRdf-0017-in.nq fromRdf-0018-in.nq fromRdf-0019-in.nq] do
        @tag skip: """
          The values are correct, but the order not, because Elixirs maps with the input graphs have no order.
          So, fixing that would require a different representation of graphs in general.
        """
      end
      if input in ~w[fromRdf-0020-in.nq fromRdf-0021-in.nq] do
        @tag skip: "https://github.com/json-ld/json-ld.org/issues/357"
      end
      @tag :test_suite
      @tag :from_rdf_test_suite
      @tag data: test_case
      test "#{input}: #{name}",
          %{data: %{"input" => input, "expect" => output} = test_case, base_iri: base_iri} do
        assert serialize(input, test_case_options(test_case, base_iri)) == json(output)
      end
    end)

  def serialize(filename, options) do
    filename
    |> file
    |> RDF.NQuads.read_file!
    |> JSON.LD.Encoder.from_rdf!(options)
  end

  def json(filename) do
    filename
    |> file
    |> File.read!
    |> Poison.Parser.parse!
  end
end
