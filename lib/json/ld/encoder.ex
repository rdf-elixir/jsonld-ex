defmodule JSON.LD.Encoder do
  @moduledoc """
  An encoder for JSON-LD serializations of RDF.ex data structures.

  As for all encoders of `RDF.Serialization.Format`s, you normally won't use these
  functions directly, but via one of the `write_` functions on the `JSON.LD`
  format module or the generic `RDF.Serialization` module.


  ## Options

  - `:context`: When a context map or remote context URL string is given,
    compaction is performed using this context
  - `:base`: : Allows to specify a base URI to be used during compaction
    (only when `:context` is provided).
    Default is the base IRI of the encoded graph or if none present or in case of
    encoded datasets the `RDF.default_base_iri/0`.
  - `:use_native_types`: If this flag is set to `true`, RDF literals with a datatype IRI
    that equals `xsd:integer` or `xsd:double` are converted to a JSON numbers and
    RDF literals with a datatype IRI that equals `xsd:boolean` are converted to `true`
    or `false` based on their lexical form. (default: `false`)
  - `:use_rdf_type`: Unless this flag is set to `true`, `rdf:type` predicates will be
    serialized as `@type` as long as the associated object is either an IRI or blank
    node identifier. (default: `false`)

  The given options are also passed through to `Jason.encode/2`, so you can also
  provide any the options this function supports, most notably the `:pretty` option.

  """

  use RDF.Serialization.Encoder

  alias JSON.LD.Options

  alias RDF.{
    BlankNode,
    Dataset,
    Description,
    Graph,
    IRI,
    LangString,
    Literal,
    NS,
    XSD
  }

  import JSON.LD.Utils
  import RDF.Guards

  @type input :: Dataset.t() | Description.t() | Graph.t()

  @rdf_type to_string(RDF.NS.RDF.type())
  @rdf_value to_string(RDF.NS.RDF.value())
  @rdf_nil to_string(RDF.NS.RDF.nil())
  @rdf_first to_string(RDF.NS.RDF.first())
  @rdf_rest to_string(RDF.NS.RDF.rest())
  @rdf_list to_string(RDF.uri(RDF.NS.RDF.List))
  @rdf_direction RDF.__base_iri__() <> "direction"
  @rdf_language RDF.__base_iri__() <> "language"

  @impl RDF.Serialization.Encoder
  @spec encode(RDF.Data.t(), keyword) :: {:ok, String.t()} | {:error, any}
  def encode(data, opts \\ []) do
    opts = set_base_iri(data, opts)

    with {:ok, json_ld_object} <- from_rdf(data, opts),
         {:ok, json_ld_object} <- maybe_compact(json_ld_object, opts) do
      encode_json(json_ld_object, opts)
    end
  end

  defp set_base_iri(%Graph{base_iri: base_iri}, opts) when not is_nil(base_iri) do
    Keyword.put_new(opts, :base, IRI.to_string(base_iri))
  end

  defp set_base_iri(_, opts) do
    if base = RDF.default_base_iri() do
      Keyword.put_new(opts, :base, IRI.to_string(base))
    else
      opts
    end
  end

  defp maybe_compact(json_ld_object, opts) do
    if context = Keyword.get(opts, :context) do
      {:ok, JSON.LD.compact(json_ld_object, context, opts)}
    else
      {:ok, json_ld_object}
    end
  end

  @spec from_rdf(RDF.Data.t(), Options.t() | Enum.t()) :: {:ok, [map]} | {:error, any}
  def from_rdf(dataset, options \\ %Options{}) do
    {:ok, from_rdf!(dataset, options)}
  rescue
    exception ->
      {:error, Exception.message(exception)}
  end

  @spec from_rdf!(RDF.Data.t(), Options.t() | Enum.t()) :: [map]
  def from_rdf!(rdf_data, options \\ %Options{})

  def from_rdf!(%Dataset{} = dataset, options) do
    options = Options.new(options)

    {graph_map, referenced_once, compound_literal_subjects} =
      Enum.reduce(Dataset.graphs(dataset), {%{}, %{}, %{}}, fn
        graph, {graph_map, referenced_once, compound_literal_subjects} ->
          # 5.1)
          name = to_string(graph.name || "@default")
          # 5.2)
          graph_map = Map.put_new(graph_map, name, %{})
          # 5.3)
          compound_literal_subjects = Map.put_new(compound_literal_subjects, name, %{})

          # 5.4)
          graph_map =
            if graph.name && !get_in(graph_map, ["@default", name]) do
              Map.update(graph_map, "@default", %{name => %{"@id" => name}}, fn default_graph ->
                Map.put(default_graph, name, %{"@id" => name})
              end)
            else
              graph_map
            end

          # 5.5) & 5.6) & 5.7)
          {node_map, referenced_once, compound_map} =
            process_graph_triples(
              graph,
              graph_map[name],
              referenced_once,
              compound_literal_subjects[name],
              options
            )

          {
            Map.put(graph_map, name, node_map),
            referenced_once,
            Map.put(compound_literal_subjects, name, compound_map)
          }
      end)

    # 6)
    {graph_map, _referenced_once} =
      Enum.reduce(graph_map, {%{}, referenced_once}, fn
        {name, graph_object}, {graph_map, referenced_once} ->
          # 6.1)
          {graph_object, referenced_once} =
            process_compound_literals(
              graph_object,
              compound_literal_subjects[name],
              referenced_once
            )

          # 6.2) - 6.4)
          {graph_object, referenced_once} = convert_list(graph_object, referenced_once)

          {Map.put(graph_map, name, graph_object), referenced_once}
      end)

    # 7+8)
    graph_map
    |> Map.get("@default", %{})
    |> maybe_sort_by(options.ordered, fn {subject, _} -> subject end)
    |> Enum.reduce([], fn {subject, node}, result ->
      # 8.1)
      node =
        if Map.has_key?(graph_map, subject) do
          Map.put(
            node,
            "@graph",
            graph_map[subject]
            |> maybe_sort_by(options.ordered, fn {s, _} -> s end)
            |> Enum.reduce([], fn {_s, n}, graph_nodes ->
              n = Map.delete(n, :usages)

              if map_size(n) == 1 and Map.has_key?(n, "@id") do
                graph_nodes
              else
                [n | graph_nodes]
              end
            end)
            |> Enum.reverse()
          )
        else
          node
        end

      # 8.2)
      node = Map.delete(node, :usages)

      if map_size(node) == 1 and Map.has_key?(node, "@id") do
        result
      else
        [node | result]
      end
    end)
    |> Enum.reverse()
  end

  def from_rdf!(rdf_data, options),
    do: rdf_data |> Dataset.new() |> from_rdf!(options)

  # Process triples in the graph (steps 5.5 through 5.7)
  defp process_graph_triples(graph, node_map, referenced_once, compound_map, options) do
    Enum.reduce(graph, {node_map, referenced_once, compound_map}, fn
      {subject, predicate, object}, {node_map, referenced_once, compound_map} ->
        subject = to_string(subject)
        predicate = to_string(predicate)

        # 5.7.1)
        node_map = Map.put_new(node_map, subject, %{"@id" => subject})
        # 5.7.2)
        node = Map.get(node_map, subject)

        # 5.7.3) Handle the compound-literal direction case
        compound_map =
          if options.rdf_direction == "compound-literal" && predicate == @rdf_direction do
            Map.put(compound_map, subject, true)
          else
            compound_map
          end

        # 5.7.4)
        {object_id, node_map} =
          if is_node_object = is_rdf_resource(object) do
            object_id = to_string(object)
            node_map = Map.put_new(node_map, object_id, %{"@id" => object_id})
            {object_id, node_map}
          else
            {nil, node_map}
          end

        # 5.7.5)
        {node, node_map, referenced_once} =
          if is_node_object and !options.use_rdf_type and predicate == @rdf_type do
            node =
              Map.update(node, "@type", [object_id], fn types ->
                if object_id in types, do: types, else: types ++ [object_id]
              end)

            {node, node_map, referenced_once}
          else
            # 5.7.6)
            value = rdf_to_object(object, options)

            # 5.7.7) & 5.7.8)
            node =
              Map.update(node, predicate, [value], fn objects ->
                if value in objects, do: objects, else: objects ++ [value]
              end)

            {node_map, referenced_once} =
              cond do
                # 5.7.9)
                object_id == @rdf_nil ->
                  usage = %{node: subject, property: predicate, value: value}

                  node_map =
                    Map.update(node_map, @rdf_nil, %{usages: [usage]}, fn object_node ->
                      Map.update(object_node, :usages, [usage], &[usage | &1])
                    end)

                  {node_map, referenced_once}

                # 5.7.10)
                Map.has_key?(referenced_once, object_id) ->
                  {node_map, Map.put(referenced_once, object_id, false)}

                # 5.7.11)
                is_rdf_bnode(object) ->
                  {node_map,
                   Map.put(referenced_once, object_id, %{
                     # We're using here the node id as the reference to the respective graph map entry.
                     node: subject,
                     property: predicate,
                     value: value
                   })}

                true ->
                  {node_map, referenced_once}
              end

            {node, node_map, referenced_once}
          end

        {Map.put(node_map, subject, node), referenced_once, compound_map}
    end)
  end

  # 6.1)
  defp process_compound_literals(graph_object, nil, referenced_once),
    do: {graph_object, referenced_once}

  defp process_compound_literals(graph_object, compound_map, referenced_once) do
    Enum.reduce(compound_map, {graph_object, referenced_once}, fn
      {cl, _}, {graph_object, referenced_once} ->
        case referenced_once[cl] do
          # SPEC ISSUE: "6.1.4) Initialize value to value of value in cl entry." seems unnecessary, since value is never used
          %{node: node_id, property: property, value: _value} ->
            node = graph_object[node_id]
            # 6.1.5)
            case Map.pop(graph_object, cl) do
              {%{} = cl_node, graph_object} ->
                # 6.1.6)
                node
                |> Map.get(property, [])
                |> Enum.reduce({graph_object, referenced_once}, fn
                  %{"@id" => ^cl} = cl_reference, {graph_object, referenced_once} ->
                    cl_reference =
                      cl_reference
                      # 6.1.6.1)
                      |> Map.delete("@id")
                      # 6.1.6.2)
                      |> Map.put(
                        "@value",
                        (List.first(cl_node[@rdf_value] || []) || %{})["@value"]
                      )

                    # 6.1.6.3)
                    cl_reference =
                      case cl_node[@rdf_language] do
                        [%{"@value" => language} | _] ->
                          if not valid_language?(language) do
                            raise JSON.LD.InvalidLanguageTaggedStringError, value: language
                          end

                          Map.put(cl_reference, "@language", language)

                        _ ->
                          cl_reference
                      end

                    # 6.1.6.4)
                    cl_reference =
                      case cl_node[@rdf_direction] do
                        [%{"@value" => direction} | _] ->
                          if direction not in ~w[ltr rtl] do
                            raise JSON.LD.InvalidBaseDirectionError,
                              message:
                                "invalid @direction value #{inspect(direction)}; must be 'ltr' or 'rtl'"
                          end

                          Map.put(cl_reference, "@direction", direction)

                        _ ->
                          cl_reference
                      end

                    {
                      update_in(graph_object, [node_id, property], fn props ->
                        Enum.map(props, fn
                          %{"@id" => ^cl} -> cl_reference
                          other -> other
                        end)
                      end),
                      Map.delete(referenced_once, cl)
                    }

                  _, {graph_object, referenced_once} ->
                    {graph_object, referenced_once}
                end)

              _ ->
                {graph_object, referenced_once}
            end

          _ ->
            {graph_object, referenced_once}
        end
    end)
  end

  #  # 6.3) - 6.4)
  defp convert_list(%{@rdf_nil => %{usages: usages}} = graph_object, referenced_once) do
    Enum.reduce(usages, {graph_object, referenced_once}, fn
      # 6.4.1)
      # Note: original_head is always an rdf:nil node
      %{node: node_id, property: property, value: original_head}, {graph_object, referenced_once} ->
        node = graph_object[node_id]

        # 6.4.2) & 6.4.3)
        {list, list_nodes, head_path, head} =
          extract_list(node, property, original_head, referenced_once, graph_object)

        updated_head =
          head
          # 6.4.4)
          |> Map.delete("@id")
          # 6.4.5) is not needed since extract_list returns the list in reverse order already
          # 6.4.6)
          |> Map.put("@list", list)

        {graph_object, referenced_once} =
          update_head(graph_object, referenced_once, head_path, head, updated_head)

        # 6.4.7)
        graph_object =
          Enum.reduce(list_nodes, graph_object, fn node_id, graph_object ->
            Map.delete(graph_object, node_id)
          end)

        {graph_object, referenced_once}
    end)
  end

  defp convert_list(graph_object, referenced_once), do: {graph_object, referenced_once}

  # 6.4.2) & 6.4.3)
  defp extract_list(
         node,
         property,
         head,
         referenced_once,
         graph_object,
         list \\ [],
         list_nodes \\ []
       )

  defp extract_list(
         %{"@id" => "_:" <> _ = id, @rdf_rest => [_rest]} = node,
         @rdf_rest = property,
         head,
         referenced_once,
         graph_object,
         list,
         list_nodes
       ) do
    do_extract_list(
      node,
      referenced_once[id],
      property,
      head,
      referenced_once,
      graph_object,
      list,
      list_nodes
    )
  end

  defp extract_list(node, property, head, _referenced_once, _graph_object, list, list_nodes) do
    {list, list_nodes, [node["@id"], property], head}
  end

  defp do_extract_list(
         %{
           "@id" => "_:" <> _ = id,
           @rdf_first => [first],
           "@type" => [@rdf_list]
         } = node,
         %{node: next_node_id, property: next_property, value: next_head},
         _property,
         _head,
         referenced_once,
         graph_object,
         list,
         list_nodes
       )
       when map_size(node) == 4 do
    extract_list(
      graph_object[next_node_id],
      next_property,
      next_head,
      referenced_once,
      graph_object,
      [first | list],
      [id | list_nodes]
    )
  end

  defp do_extract_list(
         %{
           "@id" => "_:" <> _ = id,
           @rdf_first => [first]
         } = node,
         %{node: next_node_id, property: next_property, value: next_head},
         _property,
         _head,
         referenced_once,
         graph_object,
         list,
         list_nodes
       )
       when map_size(node) == 3 do
    extract_list(
      graph_object[next_node_id],
      next_property,
      next_head,
      referenced_once,
      graph_object,
      [first | list],
      [id | list_nodes]
    )
  end

  defp do_extract_list(
         node,
         _id_ref,
         property,
         head,
         _referenced_once,
         _graph_object,
         list,
         list_nodes
       ) do
    {list, list_nodes, [node["@id"], property], head}
  end

  defp rdf_to_object(%IRI{} = iri, _) do
    %{"@id" => to_string(iri)}
  end

  defp rdf_to_object(%BlankNode{} = bnode, _) do
    %{"@id" => to_string(bnode)}
  end

  defp rdf_to_object(%Literal{literal: %datatype{}} = literal, options) do
    result = %{}
    value = Literal.value(literal)
    converted_value = literal
    type = nil

    {converted_value, type, result} =
      cond do
        options.use_native_types ->
          cond do
            datatype == XSD.String ->
              {value, type, result}

            datatype == XSD.Boolean ->
              if RDF.XSD.Boolean.valid?(literal) do
                {value, type, result}
              else
                {converted_value, NS.XSD.boolean(), result}
              end

            datatype in [XSD.Integer, XSD.Double] ->
              if Literal.valid?(literal) do
                {value, type, result}
              else
                {converted_value, type, result}
              end

            true ->
              {converted_value, Literal.datatype_id(literal), result}
          end

        options.processing_mode != "json-ld-1.0" and datatype == RDF.JSON ->
          if RDF.JSON.valid?(literal) do
            {value, "@json", result}
          else
            raise JSON.LD.InvalidJSONLiteralError, value: literal
          end

        (i18n_datatype_parts = i18n_datatype_parts(literal)) &&
            options.rdf_direction == "i18n-datatype" ->
          {language, direction} = i18n_datatype_parts

          {
            value,
            type,
            if language do
              Map.put(result, "@language", language)
            else
              result
            end
            |> Map.put("@direction", direction)
          }

        datatype == LangString ->
          {converted_value, type, Map.put(result, "@language", Literal.language(literal))}

        datatype == XSD.String ->
          {converted_value, type, result}

        true ->
          {Literal.lexical(literal), Literal.datatype_id(literal), result}
      end

    result = (type && Map.put(result, "@type", to_string(type))) || result

    Map.put(
      result,
      "@value",
      (match?(%Literal{}, converted_value) && Literal.lexical(converted_value)) || converted_value
    )
  end

  defp i18n_datatype_parts(%Literal{} = literal),
    do: literal |> Literal.datatype_id() |> i18n_datatype_parts()

  defp i18n_datatype_parts(%IRI{} = datatype),
    do: datatype |> to_string() |> i18n_datatype_parts()

  defp i18n_datatype_parts("https://www.w3.org/ns/i18n#" <> suffix) do
    case String.split(suffix, "_", parts: 2) do
      ["", direction] -> {nil, direction}
      [language, direction] -> {language, direction}
      _ -> nil
    end
  end

  defp i18n_datatype_parts(_), do: nil

  #  # This function is necessary because we have no references and use this instead to update the head by path
  defp update_head(graph_object, referenced_once, [subject, property], old, new) do
    {
      deep_replace(graph_object, old, new),
      case old do
        %{"@id" => head_id} ->
          Map.new(referenced_once, fn
            {^head_id, %{node: ^subject, property: ^property} = usage} ->
              {head_id, %{usage | value: new}}

            other ->
              other
          end)

        _ ->
          Map.new(referenced_once, fn
            {key, %{node: ^subject, property: ^property} = usage} -> {key, %{usage | value: new}}
            other -> other
          end)
      end
    }
  end

  defp deep_replace(old, old, new), do: new

  defp deep_replace(map, old, new) when is_map(map) do
    Map.new(map, fn
      {:usages, value} -> {:usages, value}
      {key, value} -> {key, deep_replace(value, old, new)}
    end)
  end

  defp deep_replace(list, old, new) when is_list(list),
    do: Enum.map(list, &deep_replace(&1, old, new))

  defp deep_replace(old, _, _), do: old

  defp encode_json(value, opts) do
    Jason.encode(value, opts)
  end
end
