defmodule JSON.LD.Flattening do
  @moduledoc nil

  import JSON.LD.{NodeIdentifierMap, Utils}
  alias JSON.LD.NodeIdentifierMap


  def flatten(input, context \\ nil, options \\ %JSON.LD.Options{}) do
    with options  = JSON.LD.Options.new(options),
         expanded = JSON.LD.expand(input, options)
    do
      {:ok, node_id_map} = NodeIdentifierMap.start_link
      node_map =
        try do
          generate_node_map(expanded, %{"@default" => %{}}, node_id_map)
        after
          NodeIdentifierMap.stop(node_id_map)
        end

      default_graph =
        Enum.reduce node_map, node_map["@default"], fn
          ({"@default", _}, default_graph) -> default_graph
          ({graph_name, graph}, default_graph) ->
            entry =
              if Map.has_key?(default_graph, graph_name) do
                default_graph[graph_name]
              else
                %{"@id" => graph_name}
              end

            graph_entry =
              graph
              |> Stream.reject(fn {_, node} ->
                          Map.has_key?(node, "@id") and map_size(node) == 1 end)
              |> Enum.sort_by(fn {id, _} -> id end)
              # TODO: Spec fixme: Spec doesn't handle the case, when a "@graph" member already exists
              |> Enum.reduce(Map.get(entry, "@graph", []), fn ({_, node}, graph_entry) ->
                   [node | graph_entry]
                 end)
              |> Enum.reverse

            Map.put(default_graph, graph_name,
              Map.put(entry, "@graph", graph_entry))
        end

      flattened =
        default_graph
        |> Enum.sort_by(fn {id, _} -> id end)
        |> Enum.reduce([], fn ({_, node}, flattened) ->
             if not (Enum.count(node) == 1 and Map.has_key?(node, "@id")) do
               [node | flattened]
             else
               flattened
             end
           end)
        |> Enum.reverse

      if context && !Enum.empty?(flattened) do # TODO: Spec fixme: !Enum.empty?(flattened) is not in the spec, but in other implementations (Ruby, Java, Go, ...)
        JSON.LD.compact(flattened, context, options)
      else
        flattened
      end
    end
  end


  @doc """
  Node Map Generation

  Details at <https://www.w3.org/TR/json-ld-api/#node-map-generation>
  """
  def generate_node_map(element, node_map, node_id_map, active_graph \\ "@default",
                        active_subject \\ nil, active_property \\ nil, list \\ nil)

  # 1)
  def generate_node_map(element, node_map, node_id_map, active_graph, active_subject,
                        active_property, list) when is_list(element) do
    Enum.reduce element, node_map, fn (item, node_map) ->
      generate_node_map(item, node_map, node_id_map, active_graph, active_subject,
                          active_property, list)
    end
  end


  # 2)
  def generate_node_map(element, node_map, node_id_map, active_graph, active_subject,
                        active_property, list) when is_map(element) do
    identifier_map = %{}
    counter = 1

    node_map = Map.put_new(node_map, active_graph, %{})
    node = node_map[active_graph][active_subject]

    # 3)
    if types = Map.get(element, "@type") do
      types = Enum.reduce(types, [],
        fn (item, types) ->
          if blank_node_id?(item) do
            identifier = generate_blank_node_id(node_id_map, item)
            types ++ [identifier]
          else
            types ++ [item]
          end
        end)
      element = Map.put(element, "@type", types)
    end

    cond do

      # 4)
      Map.has_key?(element, "@value") ->
        if is_nil(list) do
          if node do
            update_in(node_map, [active_graph, active_subject, active_property], fn
              nil -> [element]
              items ->
                unless element in items,
                  do: items ++ [element],
                else: items
            end)
          else
            node_map
          end
        else
          append_to_list(list, element)
          node_map
        end

      # 5)
      Map.has_key?(element, "@list") ->
        {:ok, result_list} = new_list
        {node_map, result} =
          try do
            {
              generate_node_map(element["@list"], node_map, node_id_map,
                active_graph, active_subject, active_property, result_list),
              get_list(result_list)
            }
        after
          terminate_list(result_list)
        end
        if node do
          update_in(node_map, [active_graph, active_subject, active_property], fn
            nil   -> [result]
            items -> items ++ [result]
          end)
        else
          node_map
        end

      # 6)
      true ->
        # 6.1)
        {id, element} = Map.pop(element, "@id")
        id =
          if id do
            if blank_node_id?(id) do
              generate_blank_node_id(node_id_map, id)
            else
              id
            end
          # 6.2)
          else
            generate_blank_node_id(node_id_map)
          end

        # 6.3)
        unless Map.has_key?(node_map[active_graph], id) do
          node_map = Map.update!(node_map, active_graph, fn graph ->
            Map.put_new(graph, id, %{"@id" => id})
          end)
        end

        # 6.4) TODO: Spec fixme: "this line is asked for by the spec, but it breaks various tests" (according to Java and Go implementation, which perform this step before 6.7) instead)
        node = node_map[active_graph][id]

        # 6.5)
        if is_map(active_subject) do
          unless Map.has_key?(node, active_property) do
            node_map =
              update_in(node_map, [active_graph, id, active_property], fn
                nil -> [active_subject]
                items ->
                  unless active_subject in items,
                    do: items ++ [active_subject],
                  else: items
              end)
          end
        # 6.6)
        else
          unless is_nil(active_property) do
            reference = %{"@id" => id}
            if is_nil(list) do
              node_map =
                update_in(node_map, [active_graph, active_subject, active_property], fn
                  nil -> [reference]
                  items ->
                    unless reference in items,
                      do: items ++ [reference],
                    else: items
                end)
            # 6.6.3) TODO: Spec fixme: specs says to add ELEMENT to @list member, should be REFERENCE
            else
              append_to_list(list, reference)
            end
          end
        end

        # 6.7)
        if Map.has_key?(element, "@type") do
          node_map =
            Enum.reduce element["@type"], node_map, fn (type, node_map) ->
              update_in(node_map, [active_graph, id, "@type"], fn
                nil -> [type]
                items ->
                  unless type in items,
                    do: items ++ [type],
                  else: items
              end)
            end
          element = Map.delete(element, "@type")
        end

        # 6.8)
        if Map.has_key?(element, "@index") do
          {element_index, element} = Map.pop(element, "@index")
          if node_index = get_in(node_map, [active_graph, id, "@index"]) do
            if not deep_compare(node_index, element_index) do
              raise JSON.LD.ConflictingIndexesError,
                message: "Multiple conflicting indexes have been found for the same node."
            end
          else
            node_map =
              update_in node_map, [active_graph, id], fn node ->
                Map.put(node, "@index", element_index)
              end
          end
        end

        # 6.9)
        if Map.has_key?(element, "@reverse") do
          referenced_node = %{"@id" => id}
          {reverse_map, element} = Map.pop(element, "@reverse")
          node_map =
            Enum.reduce reverse_map, node_map, fn ({property, values}, node_map) ->
              Enum.reduce values, node_map, fn (value, node_map) ->
                generate_node_map(value, node_map, node_id_map, active_graph,
                                  referenced_node, property)
              end
            end
        end

        # 6.10)
        if Map.has_key?(element, "@graph") do
          {graph, element} = Map.pop(element, "@graph")
          node_map = generate_node_map(graph, node_map, node_id_map, id)
        end

        # 6.11)
        element
        |> Enum.sort_by(fn {property, _} -> property end)
        |> Enum.reduce(node_map, fn ({property, value}, node_map) ->
             if blank_node_id?(property) do
               property = generate_blank_node_id(node_id_map, property)
             end
             unless Map.has_key?(node_map[active_graph][id], property) do
               node_map = update_in node_map, [active_graph, id], fn node ->
                 Map.put(node, property, [])
               end
             end
             generate_node_map(value, node_map, node_id_map, active_graph, id, property)
           end)
    end
  end

  defp deep_compare(v1, v2) when is_map(v1) and is_map(v2) do
    Enum.count(v1) == Enum.count(v2) &&
      Enum.all?(v1, fn {k, v} ->
        Map.has_key?(v2, k) && deep_compare(v, v2[k])
      end)
  end
  defp deep_compare(v1, v2) when is_list(v1) and is_list(v2) do
    Enum.count(v1) == Enum.count(v2) && MapSet.new(v1) == MapSet.new(v2)
  end
  defp deep_compare(v, v), do: true
  defp deep_compare(_, _), do: false


  defp new_list do
    Agent.start_link fn -> %{"@list" => []} end
  end

  defp terminate_list(pid) do
    Agent.stop pid
  end

  defp get_list(pid) do
    Agent.get pid, fn list_node -> list_node end
  end

  defp append_to_list(pid, element) do
    Agent.update pid, fn list_node ->
      Map.update(list_node, "@list", [element], fn list -> list ++ [element] end)
    end
  end

end
