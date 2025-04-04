defmodule JSON.LD.Decoder do
  @moduledoc """
  A decoder for JSON-LD serializations to `RDF.Dataset`s.

  As for all decoders of `RDF.Serialization.Format`s, you normally won't use these
  functions directly, but via one of the `read_` functions on the `JSON.LD` format
  module or the generic `RDF.Serialization` module.
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
        # 1.1)
        if graph_name != "@default" and not well_formed_iri?(graph_name) and
             not blank_node_id?(graph_name) do
          dataset
        else
          # 1.3)
          rdf_graph =
            graph
            |> Enum.sort_by(fn {subject, _} -> subject end)
            |> Enum.reduce(Graph.new(), fn {subject, node}, rdf_graph ->
              # 1.3.1)
              if not well_formed_iri?(subject) and not blank_node_id?(subject) do
                rdf_graph
              else
                # 1.3.2)
                node
                |> Enum.sort_by(fn {property, _} -> property end)
                |> Enum.reduce(rdf_graph, fn {property, values}, rdf_graph ->
                  cond do
                    # 1.3.2.1)
                    property == "@type" ->
                      if subject = node_to_rdf(subject) do
                        objects = values |> Enum.map(&node_to_rdf/1) |> Enum.reject(&is_nil/1)

                        Graph.add(rdf_graph, {subject, NS.RDF.type(), objects})
                      else
                        rdf_graph
                      end

                    # 1.3.2.2)
                    JSON.LD.keyword?(property) ->
                      rdf_graph

                    # 1.3.2.3)
                    not options.produce_generalized_rdf and blank_node_id?(property) ->
                      rdf_graph

                    # 1.3.2.4)
                    not well_formed_iri?(property) ->
                      rdf_graph

                    # 1.3.2.5)
                    true ->
                      Enum.reduce(values, rdf_graph, fn item, rdf_graph ->
                        case object_to_rdf(item, node_id_map, options) do
                          {_list_triples, nil} ->
                            rdf_graph

                          {list_triples, object} ->
                            rdf_graph
                            |> Graph.add({node_to_rdf(subject), node_to_rdf(property), object})
                            |> Graph.add(list_triples)
                        end
                      end)
                  end
                end)
              end
            end)

          if Enum.empty?(rdf_graph) do
            dataset
          else
            graph_name = if graph_name == "@default", do: nil, else: graph_name
            Dataset.add(dataset, rdf_graph, graph: graph_name)
          end
        end
      end)
    after
      NodeIdentifierMap.stop(node_id_map)
    end
  end

  defp well_formed_iri?(iri) do
    valid_uri?(iri)
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

  @spec node_to_rdf(String.t()) :: IRI.t() | BlankNode.t() | nil
  def node_to_rdf(node) do
    cond do
      blank_node_id?(node) -> node |> String.trim_leading("_:") |> RDF.bnode()
      well_formed_iri?(node) -> RDF.uri(node)
      true -> nil
    end
  end

  # Object to RDF Conversion - https://www.w3.org/TR/json-ld11-api/#object-to-rdf-conversion
  defp object_to_rdf(item, node_id_map, options)
  # 1) and 2)
  defp object_to_rdf(%{"@id" => id}, _node_id_map, _options) do
    {[], node_to_rdf(id)}
  end

  # 3)
  defp object_to_rdf(%{"@list" => list}, node_id_map, options) do
    list_to_rdf(list, node_id_map, options)
  end

  # 4)
  defp object_to_rdf(%{"@value" => value} = item, _node_id_map, options) do
    # 5)
    datatype = item["@type"]

    {value, datatype} =
      cond do
        # 6)
        not is_nil(datatype) and relative_iri?(datatype) and datatype != "@json" ->
          {nil, datatype}

        # 7)
        Map.has_key?(item, "@language") and not relative_iri?(item["@language"]) ->
          {nil, datatype}

        # 8)
        datatype == "@json" ->
          value =
            value
            |> RDF.JSON.new(as_value: true)
            |> RDF.JSON.canonical()
            |> RDF.JSON.lexical()

          {value, RDF.iri(RDF.JSON)}

        # 9)
        is_boolean(value) ->
          value =
            value
            |> XSD.Boolean.new()
            |> XSD.Boolean.canonical()
            |> XSD.Boolean.lexical()

          datatype = if is_nil(datatype), do: NS.XSD.boolean(), else: datatype
          {value, datatype}

        # 10)
        is_number(value) and
            (datatype == to_string(NS.XSD.double()) or value != trunc(value) or
               value >= 1.0e21) ->
          value =
            value
            |> XSD.Double.new()
            |> XSD.Double.canonical()
            |> XSD.Double.lexical()

          datatype = if is_nil(datatype), do: NS.XSD.double(), else: datatype
          {value, datatype}

        # 11)
        is_number(value) ->
          value =
            if(is_float(value), do: trunc(value), else: value)
            |> XSD.Integer.new()
            |> XSD.Integer.canonical()
            |> XSD.Integer.lexical()

          datatype = if is_nil(datatype), do: NS.XSD.integer(), else: datatype
          {value, datatype}

        # 12)
        is_nil(datatype) ->
          datatype =
            if Map.has_key?(item, "@language"), do: RDF.langString(), else: NS.XSD.string()

          {value, datatype}

        true ->
          {value, datatype}
      end

    cond do
      is_nil(value) ->
        {[], nil}

      # 13)
      Map.has_key?(item, "@direction") and not is_nil(options.rdf_direction) ->
        # 13.1)
        language = String.downcase(item["@language"] || "")
        direction = item["@direction"]

        case options.rdf_direction do
          # 13.2)
          "i18n-datatype" ->
            {[],
             Literal.new(value, datatype: "https://www.w3.org/ns/i18n##{language}_#{direction}")}

          # 13.3)
          "compound-literal" ->
            literal = RDF.bnode()

            list_triples =
              [
                {literal, RDF.value(), value},
                {literal, RDF.iri(RDF.__base_iri__() <> "direction"), direction}
              ]

            list_triples =
              if Map.has_key?(item, "@language") do
                [{literal, RDF.iri(RDF.__base_iri__() <> "language"), language} | list_triples]
              else
                list_triples
              end

            {list_triples, literal}
        end

      # 14)
      language = item["@language"] ->
        {
          [],
          if(valid_language?(language),
            do: Literal.new(value, language: language, canonicalize: true)
          )
        }

      true ->
        {[], Literal.new(value, datatype: datatype, canonicalize: true)}
    end
  end

  @spec list_to_rdf([map], pid, Options.t()) :: {[Statement.t()], IRI.t() | BlankNode.t()}
  defp list_to_rdf(list, node_id_map, options) do
    {list_triples, first, last} =
      Enum.reduce(list, {[], nil, nil}, fn item, {list_triples, first, last} ->
        case object_to_rdf(item, node_id_map, options) do
          {more_list_triples, object} ->
            bnode = RDF.bnode(generate_blank_node_id(node_id_map))
            list_triples = more_list_triples ++ list_triples
            object_triples = if object, do: [{bnode, NS.RDF.first(), object}], else: []

            if last do
              {list_triples ++ [{last, NS.RDF.rest(), bnode} | object_triples], first, bnode}
            else
              {object_triples ++ list_triples, bnode, bnode}
            end
        end
      end)

    if last do
      {list_triples ++ [{last, NS.RDF.rest(), NS.RDF.nil()}], first}
    else
      {[], NS.RDF.nil()}
    end
  end
end
