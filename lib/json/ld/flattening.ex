defmodule JSON.LD.Flattening do
  @moduledoc """
  Implementation of the JSON-LD 1.1 Flattening Algorithms.

  <https://www.w3.org/TR/json-ld11-api/#flattening-algorithms>
  """

  import JSON.LD.{NodeIdentifierMap, Utils}

  alias JSON.LD.{NodeIdentifierMap, Options}

  def flatten(input, options \\ %Options{}) do
    node_map = node_map(input)

    {default_graph, named_graphs} = Map.pop(node_map, "@default")

    graph_maps =
      named_graphs
      |> maybe_sort_by(options.ordered, fn {graph_name, _} -> graph_name end)
      |> Enum.reduce(default_graph, fn {graph_name, graph}, graph_maps ->
        entry =
          if Map.has_key?(graph_maps, graph_name) do
            graph_maps[graph_name]
          else
            %{"@id" => graph_name}
          end

        graph =
          Enum.reject(graph, fn {_, node} ->
            Map.has_key?(node, "@id") and map_size(node) == 1
          end)

        graph_entry =
          graph
          |> maybe_sort_by(options.ordered, fn {id, _node} -> id end)
          |> Enum.map(fn {_id, node} -> node end)

        Map.put(
          graph_maps,
          graph_name,
          Map.update(entry, "@graph", graph_entry, fn existing -> existing ++ graph_entry end)
        )
      end)

    graph_maps
    |> maybe_sort_by(options.ordered, fn {id, _node} -> id end)
    |> Enum.flat_map(fn {_, node} ->
      if Enum.count(node) == 1 and Map.has_key?(node, "@id") do
        []
      else
        [node]
      end
    end)
  end

  @spec node_map([map], pid | nil) :: map
  def node_map(input, node_id_map \\ nil)

  def node_map(input, nil) do
    {:ok, node_id_map} = NodeIdentifierMap.start_link()

    try do
      node_map(input, node_id_map)
    after
      NodeIdentifierMap.stop(node_id_map)
    end
  end

  def node_map(input, node_id_map) do
    generate_node_map(input, %{"@default" => %{}}, node_id_map)
  end

  @doc """
  Node Map Generation

  <https://www.w3.org/TR/json-ld11-api/#node-map-generation>
  """
  @spec generate_node_map(
          [map] | map,
          map,
          pid,
          String.t(),
          String.t() | nil,
          String.t() | nil,
          pid | nil
        ) :: map
  def generate_node_map(
        element,
        node_map,
        node_id_map,
        active_graph \\ "@default",
        active_subject \\ nil,
        active_property \\ nil,
        list \\ nil
      )

  # 1)
  def generate_node_map(
        element,
        node_map,
        node_id_map,
        active_graph,
        active_subject,
        active_property,
        list
      )
      when is_list(element) do
    Enum.reduce(element, node_map, fn item, node_map ->
      generate_node_map(
        item,
        node_map,
        node_id_map,
        active_graph,
        active_subject,
        active_property,
        list
      )
    end)
  end

  # 2)
  def generate_node_map(
        element,
        node_map,
        node_id_map,
        active_graph,
        active_subject,
        active_property,
        list
      )
      when is_map(element) do
    node_map = Map.put_new(node_map, active_graph, %{})
    node = node_map[active_graph][active_subject]

    # 3)
    element =
      if old_types = Map.get(element, "@type") do
        new_types =
          Enum.map(List.wrap(old_types), fn item ->
            if blank_node_id?(item) do
              generate_blank_node_id(node_id_map, item)
            else
              item
            end
          end)

        Map.put(
          element,
          "@type",
          if(is_list(old_types), do: new_types, else: List.first(new_types))
        )
      else
        element
      end

    cond do
      # 4)
      Map.has_key?(element, "@value") ->
        if is_nil(list) do
          if node do
            update_in(node_map, [active_graph, active_subject, active_property], fn
              nil -> [element]
              items -> if element not in items, do: items ++ [element], else: items
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
        {:ok, result_list} = new_list()

        {node_map, result} =
          try do
            {
              generate_node_map(
                element["@list"],
                node_map,
                node_id_map,
                active_graph,
                active_subject,
                active_property,
                result_list
              ),
              get_list(result_list)
            }
          after
            terminate_list(result_list)
          end

        if is_nil(list) do
          if node do
            update_in(node_map, [active_graph, active_subject, active_property], fn
              nil -> [result]
              items -> items ++ [result]
            end)
          else
            node_map
          end
        else
          append_to_list(list, result)
          node_map
        end

      # 6)
      true ->
        # 6.1)
        {id, element} = Map.pop(element, "@id")

        id =
          if id do
            if blank_node_id?(id), do: generate_blank_node_id(node_id_map, id), else: id

            # 6.2)
          else
            generate_blank_node_id(node_id_map)
          end

        # 6.3)
        node_map =
          if not Map.has_key?(node_map[active_graph], id) do
            Map.update!(node_map, active_graph, fn graph ->
              Map.put_new(graph, id, %{"@id" => id})
            end)
          else
            node_map
          end

        # 6.4)
        node = node_map[active_graph][id]

        # 6.5)
        node_map =
          if is_map(active_subject) do
            if not Map.has_key?(node, active_property) do
              update_in(node_map, [active_graph, id, active_property], fn
                nil ->
                  [active_subject]

                items ->
                  if active_subject not in items, do: items ++ [active_subject], else: items
              end)
            else
              node_map
            end

            # 6.6)
          else
            if not is_nil(active_property) do
              reference = %{"@id" => id}

              if is_nil(list) do
                update_in(node_map, [active_graph, active_subject, active_property], fn
                  nil -> [reference]
                  items -> if reference not in items, do: items ++ [reference], else: items
                end)
              else
                # 6.6.3)
                append_to_list(list, reference)
                node_map
              end
            else
              node_map
            end
          end

        # 6.7)
        {node_map, element} =
          if Map.has_key?(element, "@type") do
            node_map =
              Enum.reduce(element["@type"], node_map, fn type, node_map ->
                update_in(node_map, [active_graph, id, "@type"], fn
                  nil -> [type]
                  items -> if type not in items, do: items ++ [type], else: items
                end)
              end)

            {node_map, Map.delete(element, "@type")}
          else
            {node_map, element}
          end

        # 6.8)
        {node_map, element} =
          if Map.has_key?(element, "@index") do
            {element_index, element} = Map.pop(element, "@index")

            node_map =
              if node_index = get_in(node_map, [active_graph, id, "@index"]) do
                if not deep_compare(node_index, element_index) do
                  raise JSON.LD.Error.conflicting_indexes(node_index, element_index)
                end
              else
                update_in(node_map, [active_graph, id], fn node ->
                  Map.put(node, "@index", element_index)
                end)
              end

            {node_map, element}
          else
            {node_map, element}
          end

        # 6.9)
        {node_map, element} =
          if Map.has_key?(element, "@reverse") do
            referenced_node = %{"@id" => id}
            {reverse_map, element} = Map.pop(element, "@reverse")

            node_map =
              Enum.reduce(reverse_map, node_map, fn {property, values}, node_map ->
                Enum.reduce(values, node_map, fn value, node_map ->
                  generate_node_map(
                    value,
                    node_map,
                    node_id_map,
                    active_graph,
                    referenced_node,
                    property
                  )
                end)
              end)

            {node_map, element}
          else
            {node_map, element}
          end

        # 6.10)
        {node_map, element} =
          if Map.has_key?(element, "@graph") do
            {graph, element} = Map.pop(element, "@graph")
            {generate_node_map(graph, node_map, node_id_map, id), element}
          else
            {node_map, element}
          end

        # 6.11)
        {node_map, element} =
          if Map.has_key?(element, "@included") do
            {included, element} = Map.pop(element, "@included")
            {generate_node_map(included, node_map, node_id_map, active_graph), element}
          else
            {node_map, element}
          end

        # 6.12)
        element
        |> Enum.sort_by(fn {property, _} -> property end)
        |> Enum.reduce(node_map, fn {property, value}, node_map ->
          property =
            if blank_node_id?(property) do
              generate_blank_node_id(node_id_map, property)
            else
              property
            end

          node_map =
            if not Map.has_key?(node_map[active_graph][id], property) do
              update_in(node_map, [active_graph, id], fn node -> Map.put(node, property, []) end)
            else
              node_map
            end

          generate_node_map(value, node_map, node_id_map, active_graph, id, property)
        end)
    end
  end

  @spec deep_compare(map | [map], map | [map]) :: boolean
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

  @spec new_list :: Agent.on_start()
  defp new_list do
    Agent.start_link(fn -> %{"@list" => []} end)
  end

  @spec terminate_list(pid) :: :ok
  defp terminate_list(pid) do
    :ok = Agent.stop(pid)
  end

  @spec get_list(pid) :: map
  defp get_list(pid) do
    Agent.get(pid, fn list_node -> list_node end)
  end

  @spec append_to_list(pid, map) :: :ok
  defp append_to_list(pid, element) do
    Agent.update(pid, fn list_node ->
      Map.update(list_node, "@list", [element], fn list -> list ++ [element] end)
    end)
  end
end
