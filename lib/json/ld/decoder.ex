defmodule JSON.LD.Decoder do
  @moduledoc """
  """

  use RDF.Serialization.Decoder

  import JSON.LD.{NodeIdentifierMap, Utils}
  alias JSON.LD.NodeIdentifierMap
  alias RDF.{Dataset, Graph}
  alias RDF.NS.{XSD}


  def decode(content, opts \\ []) do
    with {:ok, json_ld_object} <- parse_json(content),
         dataset                = to_rdf(json_ld_object, opts) do
      {:ok, dataset}
    end
  end

  def to_rdf(element, options \\ %JSON.LD.Options{}) do
    with options = JSON.LD.Options.new(options) do
      {:ok, node_id_map} = NodeIdentifierMap.start_link
      try do
        element
        |> JSON.LD.expand(options)
        |> JSON.LD.node_map(node_id_map)
        |> Enum.sort_by(fn {graph_name, _} -> graph_name end)
        |> Enum.reduce(Dataset.new, fn ({graph_name, graph}, dataset) ->
            unless relative_iri?(graph_name) do
              rdf_graph =
                graph
                |> Enum.sort_by(fn {subject, _} -> subject end)
                |> Enum.reduce(Graph.new, fn ({subject, node}, rdf_graph) ->
                     unless relative_iri?(subject) do
                       node
                       |> Enum.sort_by(fn {property, _} -> property end)
                       |> Enum.reduce(rdf_graph, fn ({property, values}, rdf_graph) ->
                            cond do
                              property == "@type" ->
                                Graph.add rdf_graph, 
                                  node_to_rdf(subject), RDF.NS.RDF.type, 
                                    Enum.map(values, &node_to_rdf/1)
                              JSON.LD.keyword?(property) ->
                                rdf_graph
                              not options.produce_generalized_rdf and
                                  blank_node_id?(property) ->
                                rdf_graph
                              relative_iri?(property) ->
                                rdf_graph
                              true ->
                                Enum.reduce values, rdf_graph, fn
                                  (%{"@list" => list}, rdf_graph) ->
                                    with {list_triples, first} <- 
                                          list_to_rdf(list, node_id_map) do
                                      rdf_graph
                                      |> Graph.add({node_to_rdf(subject), node_to_rdf(property), first})
                                      |> Graph.add(list_triples)
                                    end
                                  (item, rdf_graph) ->
                                    case object_to_rdf(item) do
                                      nil    -> rdf_graph
                                      object ->
                                        Graph.add rdf_graph,
                                          {node_to_rdf(subject), node_to_rdf(property), object}
                                    end
                                end
                            end
                          end)
                     else
                       rdf_graph
                     end
                   end)
               Dataset.add(dataset, rdf_graph,
                            if(graph_name == "@default", do: nil, else: graph_name))
            else
              dataset
            end
        end)
      after
        NodeIdentifierMap.stop(node_id_map)
      end
    end
  end

  # TODO: This should not be dependent on Poison as a JSON parser in general,
  #   but determine available JSON parsers and use one heuristically or by configuration
  def parse_json(content, opts \\ []) do
    Poison.Parser.parse(content)
  end

  def parse_json!(content, opts \\ []) do
    Poison.Parser.parse!(content)
  end

  def node_to_rdf(nil), do: nil
  def node_to_rdf(node) do
    if blank_node_id?(node) do
      node
      |> String.trim_leading("_:")
      |> RDF.bnode
    else
      RDF.uri(node)
    end
  end

  defp object_to_rdf(%{"@id" => id}) do
    unless relative_iri?(id) do
      node_to_rdf(id)
    end
  end

  defp object_to_rdf(%{"@value" => value} = item) do
    datatype = item["@type"]
    cond do
      is_boolean(value) ->
        value = to_string(value)
        datatype = if is_nil(datatype), do: XSD.boolean, else: datatype
      is_float(value) or (is_number(value) and datatype == to_string(XSD.double)) ->
        value = to_string(value) # TODO: canonicalize according to Data Round Tripping
        datatype = if is_nil(datatype), do: XSD.double, else: datatype
      is_integer(value) or (is_number(value) and datatype == to_string(XSD.integer)) ->
        value = to_string(value) # TODO: canonicalize according to Data Round Tripping
        datatype = if is_nil(datatype), do: XSD.integer, else: datatype
      is_nil(datatype) ->
        datatype =
          if Map.has_key?(item, "@language") do
            RDF.langString
          else
            XSD.string
          end
      true ->
    end
    RDF.Literal.new(value, datatype: datatype, language: item["@language"])
  end

  defp list_to_rdf(list, node_id_map) do
   list
   |> Enum.reverse
   |> Enum.reduce({[], RDF.NS.RDF.nil}, fn (item, {list_triples, last}) ->
        case object_to_rdf(item) do
          nil    -> {list_triples, last}
          object ->
            with bnode = node_to_rdf(generate_blank_node_id(node_id_map)) do
              {
                [{bnode, RDF.NS.RDF.first, object}, 
                 {bnode, RDF.NS.RDF.rest,  last  } | list_triples],
                bnode
              }
            end
        end
      end)
  end

end
