defmodule JSON.LD.Decoder do
  @moduledoc """
  """

  use RDF.Serialization.Decoder

  import JSON.LD.{NodeIdentifierMap, Utils}

  alias JSON.LD.{NodeIdentifierMap, Options}
  alias RDF.{BlankNode, Dataset, Graph, IRI, Literal, NS, Statement, XSD}

  @impl RDF.Serialization.Decoder
  @spec decode(String.t(), keyword) :: {:ok, Dataset.t() | Graph.t()} | {:error, any}
  def decode(content, opts \\ []) do
    with {:ok, json_ld_object} <- parse_json(content) do
      dataset = to_rdf(json_ld_object, opts)

      {:ok, dataset}
    end
  end

  @dialyzer {:nowarn_function, to_rdf: 2}
  @spec to_rdf(map, Options.t() | Enum.t()) :: Dataset.t() | Graph.t()
  def to_rdf(element, options \\ %Options{}) do
    {:ok, node_id_map} = NodeIdentifierMap.start_link()

    options = Options.new(options)

    try do
      element
      |> JSON.LD.expand(options)
      |> JSON.LD.node_map(node_id_map)
      |> Enum.sort_by(fn {graph_name, _} -> graph_name end)
      |> Enum.reduce(Dataset.new(), fn {graph_name, graph}, dataset ->
        unless relative_iri?(graph_name) do
          rdf_graph =
            graph
            |> Enum.sort_by(fn {subject, _} -> subject end)
            |> Enum.reduce(Graph.new(), fn {subject, node}, rdf_graph ->
              unless relative_iri?(subject) do
                node
                |> Enum.sort_by(fn {property, _} -> property end)
                |> Enum.reduce(rdf_graph, fn {property, values}, rdf_graph ->
                  cond do
                    property == "@type" ->
                      Graph.add(
                        rdf_graph,
                        {node_to_rdf(subject), NS.RDF.type(), Enum.map(values, &node_to_rdf/1)}
                      )

                    JSON.LD.keyword?(property) ->
                      rdf_graph

                    not options.produce_generalized_rdf and blank_node_id?(property) ->
                      rdf_graph

                    relative_iri?(property) ->
                      rdf_graph

                    true ->
                      Enum.reduce(values, rdf_graph, fn
                        %{"@list" => list}, rdf_graph ->
                          with {list_triples, first} <- list_to_rdf(list, node_id_map) do
                            rdf_graph
                            |> Graph.add({node_to_rdf(subject), node_to_rdf(property), first})
                            |> Graph.add(list_triples)
                          end

                        item, rdf_graph ->
                          case object_to_rdf(item) do
                            nil ->
                              rdf_graph

                            object ->
                              Graph.add(
                                rdf_graph,
                                {node_to_rdf(subject), node_to_rdf(property), object}
                              )
                          end
                      end)
                  end
                end)
              else
                rdf_graph
              end
            end)

          if Enum.empty?(rdf_graph) do
            dataset
          else
            graph_name = if graph_name == "@default", do: nil, else: graph_name
            Dataset.add(dataset, rdf_graph, graph: graph_name)
          end
        else
          dataset
        end
      end)
    after
      NodeIdentifierMap.stop(node_id_map)
    end
  end

  @spec parse_json(String.t(), [Jason.decode_opt()]) ::
          {:ok, map} | {:error, Jason.DecodeError.t()}
  def parse_json(content, _opts \\ []) do
    Jason.decode(content)
  end

  @spec parse_json!(String.t(), [Jason.decode_opt()]) :: map
  def parse_json!(content, _opts \\ []) do
    Jason.decode!(content)
  end

  @spec node_to_rdf(String.t()) :: IRI.t() | BlankNode.t()
  def node_to_rdf(node) do
    if blank_node_id?(node) do
      node
      |> String.trim_leading("_:")
      |> RDF.bnode()
    else
      RDF.uri(node)
    end
  end

  @spec object_to_rdf(map) :: IRI.t() | BlankNode.t() | Literal.t() | nil
  defp object_to_rdf(%{"@id" => id}) do
    unless relative_iri?(id), do: node_to_rdf(id)
  end

  defp object_to_rdf(%{"@value" => value} = item) do
    datatype = item["@type"]

    {value, datatype} =
      cond do
        is_boolean(value) ->
          value =
            value
            |> XSD.Boolean.new()
            |> XSD.Boolean.canonical()
            |> XSD.Boolean.lexical()

          datatype = if is_nil(datatype), do: NS.XSD.boolean(), else: datatype
          {value, datatype}

        is_float(value) or (is_number(value) and datatype == to_string(NS.XSD.double())) ->
          value =
            value
            |> XSD.Double.new()
            |> XSD.Double.canonical()
            |> XSD.Double.lexical()

          datatype = if is_nil(datatype), do: NS.XSD.double(), else: datatype
          {value, datatype}

        is_integer(value) or (is_number(value) and datatype == to_string(NS.XSD.integer())) ->
          value =
            value
            |> XSD.Integer.new()
            |> XSD.Integer.canonical()
            |> XSD.Integer.lexical()

          datatype = if is_nil(datatype), do: NS.XSD.integer(), else: datatype
          {value, datatype}

        is_nil(datatype) ->
          datatype =
            if Map.has_key?(item, "@language"), do: RDF.langString(), else: NS.XSD.string()

          {value, datatype}

        true ->
          {value, datatype}
      end

    if language = item["@language"] do
      Literal.new(value, language: language, canonicalize: true)
    else
      Literal.new(value, datatype: datatype, canonicalize: true)
    end
  end

  @spec list_to_rdf([map], pid) :: {[Statement.t()], IRI.t() | BlankNode.t()}
  defp list_to_rdf(list, node_id_map) do
    {list_triples, first, last} =
      Enum.reduce(list, {[], nil, nil}, fn item, {list_triples, first, last} ->
        case object_to_rdf(item) do
          nil ->
            {list_triples, first, last}

          object ->
            bnode = node_to_rdf(generate_blank_node_id(node_id_map))

            if last do
              {
                list_triples ++
                  [{last, NS.RDF.rest(), bnode}, {bnode, NS.RDF.first(), object}],
                first,
                bnode
              }
            else
              {
                list_triples ++ [{bnode, NS.RDF.first(), object}],
                bnode,
                bnode
              }
            end
        end
      end)

    if last do
      {list_triples ++ [{last, NS.RDF.rest(), NS.RDF.nil()}], first}
    else
      {[], NS.RDF.nil()}
    end
  end

  # This is a much nicer and faster version, but the blank node numbering is reversed.
  # Although this isn't relevant, I prefer to be more spec conform (for now).
  # defp list_to_rdf(list, node_id_map) do
  #   list
  #   |> Enum.reverse
  #   |> Enum.reduce({[], RDF.NS.RDF.nil}, fn (item, {list_triples, last}) ->
  #        case object_to_rdf(item) do
  #          nil    -> {list_triples, last}
  #          object ->
  #            with bnode = node_to_rdf(generate_blank_node_id(node_id_map)) do
  #              {
  #                [{bnode, RDF.NS.RDF.first, object},
  #                 {bnode, RDF.NS.RDF.rest,  last  } | list_triples],
  #                bnode
  #              }
  #            end
  #        end
  #      end)
  # end
end
