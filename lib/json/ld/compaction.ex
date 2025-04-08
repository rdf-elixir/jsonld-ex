defmodule JSON.LD.Compaction do
  @moduledoc """
  Implementation of the JSON-LD 1.1 Compaction Algorithms.

  <https://www.w3.org/TR/json-ld11-api/#compaction-algorithm>
  """

  import JSON.LD.Utils

  alias JSON.LD.{Context, IRIExpansion, Options}

  def compact(
        element,
        active_context,
        active_property,
        options,
        compact_arrays \\ false,
        ordered \\ false
      )

  # 2) If element is a scalar, it is already in its most compact form, so simply return element.
  def compact(element, _, _, _, _, _)
      when is_binary(element) or is_number(element) or is_boolean(element),
      do: element

  # 3) If element is an array
  def compact(element, active_context, active_property, options, compact_arrays, ordered)
      when is_list(element) do
    # 3.1) and 3.2)
    result =
      Enum.flat_map(element, fn item ->
        case compact(item, active_context, active_property, options, compact_arrays, ordered) do
          nil -> []
          compacted_item -> [compacted_item]
        end
      end)

    # 3.3)
    term_def = active_context.term_defs[active_property]
    container_mapping = List.wrap(term_def && term_def.container_mapping)

    if not compact_arrays or
         active_property in ~w[@graph @set] or
         "@list" in container_mapping or
         "@set" in container_mapping do
      result
    else
      case result do
        [value] -> value
        result -> result
      end
    end
  end

  # 4) Otherwise element is a map.
  def compact(element, active_context, active_property, options, compact_arrays, ordered)
      when is_map(element) do
    # 1) Initialize type-scoped context to active context. This is used for compacting values that may be relevant to any previous type-scoped context.
    type_scoped_context = active_context

    # 5) If active context has a previous context, the active context is not propagated. If element does not contain an @value entry, and element does not consist of a single @id entry, set active context to previous context from active context, as the scope of a term-scoped context does not apply when processing new node objects.
    active_context =
      if (previous_context = active_context.previous_context) &&
           !Map.has_key?(element, "@value") &&
           !(map_size(element) == 1 and Map.has_key?(element, "@id")) do
        previous_context
      else
        active_context
      end

    # 6) If the term definition for active property in active context has a local context:
    #   Regarding errata "Which context should be used to get the term definition in compaction algorithm step 6?" - https://w3c.github.io/json-ld-api/errata/
    #   we follow JSON-LD.rb in using type_scoped_context
    term_def = type_scoped_context.term_defs[active_property]

    active_context =
      if local_context = term_def && term_def.local_context do
        # SPEC ISSUE: we follow the JSON-LD.rb in ignoring setting "base URL from the term definition for active property in active context" here
        Context.update(
          active_context,
          local_context,
          override_protected: true,
          processor_options: options
        )
      else
        active_context
      end
      |> Context.set_inverse()

    term_def = active_context.term_defs[active_property]

    cond do
      # 7) If element has an @value or @id entry and the result of using the Value Compaction algorithm, passing active context, active property, and element as value is a scalar, or the term definition for active property has a type mapping of @json, return that result.
      Map.has_key?(element, "@value") or Map.has_key?(element, "@id") ->
        result = compact_value(element, active_context, active_property, options)

        if scalar?(result) || (term_def && term_def.type_mapping == "@json") do
          result
        else
          do_compact_non_scalar(
            element,
            active_context,
            type_scoped_context,
            active_property,
            compact_arrays,
            ordered,
            options
          )
        end

      # 8) If element is a list object, and the container mapping for active property in active context includes @list, return the result of using this algorithm recursively, passing active context, active property, value of @list in element for element, and the compactArrays and ordered flags.
      list?(element) and "@list" in List.wrap(term_def && term_def.container_mapping) ->
        compact(
          element["@list"],
          active_context,
          active_property,
          options,
          compact_arrays,
          ordered
        )

      true ->
        do_compact_non_scalar(
          element,
          active_context,
          type_scoped_context,
          active_property,
          compact_arrays,
          ordered,
          options
        )
    end
  end

  defp do_compact_non_scalar(
         element,
         active_context,
         type_scoped_context,
         active_property,
         compact_arrays,
         ordered,
         options
       ) do
    # 9) Initialize inside reverse to true if active property equals @reverse, otherwise to false.
    inside_reverse = active_property == "@reverse"

    # 11) If element has an @type entry, create a new array compacted types initialized by transforming each expanded type of that entry into its compacted form by IRI compacting expanded type. Then, for each term in compacted types ordered lexicographically:
    active_context =
      if expanded_types = element["@type"] do
        expanded_types
        |> List.wrap()
        |> Enum.map(&compact_iri(&1, active_context, options))
        |> Enum.sort()
        |> Enum.reduce(active_context, fn term, context ->
          term_def = type_scoped_context.term_defs[term]

          if local_context = term_def && term_def.local_context do
            Context.update(context, local_context, propagate: false, processor_options: options)
          else
            context
          end
        end)
      else
        active_context
      end
      |> Context.set_inverse()

    # 12)
    sorted =
      if ordered,
        do: Enum.sort_by(element, fn {expanded_property, _} -> expanded_property end),
        else: element

    Enum.reduce(sorted, %{}, fn {expanded_property, expanded_value}, result ->
      cond do
        # 12.1)
        expanded_property == "@id" ->
          # 12.1.1)
          compacted_value =
            if is_binary(expanded_value) do
              compact_iri(expanded_value, active_context, options, nil, false)
            else
              raise "undefined state: string expected"
            end

          # 12.1.2)
          alias = compact_iri(expanded_property, active_context, options)

          # 12.1.3)
          Map.put(result, alias, compacted_value)

        # 12.2)
        expanded_property == "@type" ->
          type_scoped_context = Context.set_inverse(type_scoped_context)

          compacted_value =
            cond do
              # 12.2.1)
              is_binary(expanded_value) ->
                compact_iri(expanded_value, type_scoped_context, options)

              # 12.2.2)
              is_list(expanded_value) ->
                Enum.map(expanded_value, &compact_iri(&1, type_scoped_context, options))
            end

          # 12.2.3)
          alias = compact_iri(expanded_property, active_context, options)

          # 12.2.4)
          term_def = active_context.term_defs[alias]
          container_mapping = List.wrap(term_def && term_def.container_mapping)

          as_array =
            (options.processing_mode == "json-ld-1.1" and "@set" in container_mapping) or
              !compact_arrays

          # 12.2.5)
          Map.put(
            result,
            alias,
            case compacted_value do
              [compacted_value] when not as_array -> compacted_value
              compacted_value when as_array and not is_list(compacted_value) -> [compacted_value]
              compacted_value -> compacted_value
            end
          )

        # 12.3)
        expanded_property == "@reverse" ->
          # 12.3.1)
          compacted_value =
            compact(
              expanded_value,
              active_context,
              "@reverse",
              options,
              compact_arrays,
              ordered
            )

          # 12.3.2)
          {compacted_value, result} =
            Enum.reduce(compacted_value, {%{}, result}, fn {property, value},
                                                           {compacted_value, result} ->
              term_def = active_context.term_defs[property]

              if term_def && term_def.reverse_property do
                as_array = term_def.container_mapping == "@set" or !compact_arrays

                {compacted_value, merge_compacted_value(result, property, value, as_array)}
              else
                {Map.put(compacted_value, property, value), result}
              end
            end)

          # 12.3.3)
          unless Enum.empty?(compacted_value) do
            alias = compact_iri("@reverse", active_context, options)
            Map.put(result, alias, compacted_value)
          else
            result
          end

        # 12.4)
        expanded_property == "@preserve" ->
          # 12.4.1)
          compacted_value =
            compact(
              expanded_value,
              active_context,
              "@reverse",
              options,
              compact_arrays,
              ordered
            )

          if compacted_value == [] do
            result
          else
            Map.put(result, "@preserve", compacted_value)
          end

        # 12.5)
        expanded_property == "@index" &&
            ((term_def = active_context.term_defs[active_property]) &&
               "@index" in List.wrap(term_def.container_mapping)) ->
          result

        # 12.6)
        expanded_property in ~w[@direction @index @value @language] ->
          # 12.6.1)
          alias = compact_iri(expanded_property, active_context, options)
          # 12.6.2)
          Map.put(result, alias, expanded_value)

        true ->
          # 12.7)
          if expanded_value == [] do
            # 12.7.1)
            item_active_property =
              compact_iri(
                expanded_property,
                active_context,
                options,
                expanded_value,
                true,
                inside_reverse
              )

            # 12.7.2)
            term_def = active_context.term_defs[item_active_property]

            if nest_term = term_def && term_def.nest_value do
              # 12.7.2.1) If nest term is not @nest, or a term in the active context that expands to @nest, an invalid @nest value error has been detected, and processing is aborted.
              nest_term_def = active_context.term_defs[nest_term]

              if nest_term != "@nest" and
                   (is_nil(nest_term_def) or nest_term_def.iri_mapping != "@nest") do
                raise JSON.LD.InvalidNestValueError,
                  message:
                    "Invalid @nest value: #{nest_term}. The value must be '@nest' or a term that expands to '@nest'"
              end

              # 12.7.2.2 and 12.7.2.2) with 12.7.3 and 12.7.4) in nest case
              Map.update(result, nest_term, %{item_active_property => []}, fn value ->
                merge_compacted_value(value, item_active_property, [], true)
              end)
            else
              # 12.7.3 and 12.7.4) (non-nest case)
              merge_compacted_value(result, item_active_property, [], true)
            end
          else
            # 12.8)
            Enum.reduce(expanded_value, result, fn expanded_item, result ->
              # 12.8.1)
              item_active_property =
                compact_iri(
                  expanded_property,
                  active_context,
                  options,
                  expanded_item,
                  true,
                  inside_reverse
                )

              # 12.8.2) ~ 12.8.3)
              term_def = active_context.term_defs[item_active_property]

              nest_result =
                if nest_term = term_def && term_def.nest_value do
                  # 12.8.2.1) If nest term is not @nest, or a term in the active context that expands to @nest, an invalid @nest value error has been detected, and processing is aborted.
                  nest_term_def = active_context.term_defs[nest_term]

                  if nest_term != "@nest" and
                       (is_nil(nest_term_def) or nest_term_def.iri_mapping != "@nest") do
                    raise JSON.LD.InvalidNestValueError,
                      message:
                        "Invalid @nest value: #{nest_term}. The value must be '@nest' or a term that expands to '@nest'"
                  end

                  # 12.8.2.2 and 12.8.2.3)
                  Map.get(result, nest_term, %{})
                end

              # 12.8.4)
              term_def = active_context.term_defs[item_active_property]
              container = (term_def && term_def.container_mapping) || []

              # 12.8.5)
              as_array =
                "@set" in container or item_active_property in ~w[@graph @list] or
                  !compact_arrays

              # 12.8.6)
              compacted_item =
                cond do
                  list?(expanded_item) -> expanded_item["@list"]
                  graph?(expanded_item) -> expanded_item["@graph"]
                  true -> expanded_item
                end
                |> compact(
                  active_context,
                  item_active_property,
                  options,
                  compact_arrays,
                  ordered
                )

              cond do
                # 12.8.7)
                list?(expanded_item) ->
                  # 12.8.7.1)
                  compacted_item =
                    if not is_list(compacted_item),
                      do: [compacted_item],
                      else: compacted_item

                  # 12.8.7.2)
                  if "@list" not in container do
                    # 12.8.7.2.1)
                    compacted_item = %{
                      compact_iri("@list", active_context, options) => compacted_item
                    }

                    # 12.8.7.2.2)
                    compacted_item =
                      if Map.has_key?(expanded_item, "@index") do
                        Map.put(
                          compacted_item,
                          compact_iri("@index", active_context, options),
                          expanded_item["@index"]
                        )
                      else
                        compacted_item
                      end

                    # 12.8.7.2.3)
                    if nest_result do
                      # We add nest_result from 12.8.2 here, since we can't add it be reference as specified
                      Map.put(
                        result,
                        nest_term,
                        merge_compacted_value(
                          nest_result,
                          item_active_property,
                          compacted_item,
                          as_array
                        )
                      )
                    else
                      merge_compacted_value(
                        result,
                        item_active_property,
                        compacted_item,
                        as_array
                      )
                    end
                  else
                    # 12.8.7.3)
                    if nest_result do
                      # We add nest_result from 12.8.2 here, since we can't add it be reference as specified
                      Map.put(
                        result,
                        nest_term,
                        Map.put(nest_result, item_active_property, compacted_item)
                      )
                    else
                      Map.put(result, item_active_property, compacted_item)
                    end
                  end

                # 12.8.8) We assume an explicit "Otherwise" here, since expanded item can not be a list and graph object at the same time.
                #         This allows us to handle nest_result in isolation here.
                graph?(expanded_item) ->
                  cond do
                    # 12.8.8.1)
                    "@graph" in container and "@id" in container ->
                      # 12.8.8.1.1)
                      map_object = (nest_result || result)[item_active_property] || %{}

                      # 12.8.8.1.2)
                      expanded_id = expanded_item["@id"]

                      map_key =
                        compact_iri(
                          expanded_id || "@none",
                          active_context,
                          options,
                          nil,
                          !expanded_id
                        )

                      # 12.8.8.1.3)
                      map_object =
                        merge_compacted_value(map_object, map_key, compacted_item, as_array)

                      if nest_result do
                        # We add nest_result from 12.8.2 here, since we can't add it be reference as specified
                        Map.put(
                          result,
                          nest_term,
                          Map.put(nest_result, item_active_property, map_object)
                        )
                      else
                        Map.put(result, item_active_property, map_object)
                      end

                    # 12.8.8.2)
                    "@graph" in container and "@index" in container and
                        simple_graph?(expanded_item) ->
                      # 12.8.8.2.1)
                      map_object = (nest_result || result)[item_active_property] || %{}

                      # 12.8.8.2.2)
                      map_key = expanded_item["@index"] || "@none"

                      # 12.8.8.2.3)
                      map_object =
                        merge_compacted_value(map_object, map_key, compacted_item, as_array)

                      if nest_result do
                        # We add nest_result from 12.8.2 here, since we can't add it be reference as specified
                        Map.put(
                          result,
                          nest_term,
                          Map.put(nest_result, item_active_property, map_object)
                        )
                      else
                        Map.put(result, item_active_property, map_object)
                      end

                    # 12.8.8.3)
                    "@graph" in container and simple_graph?(expanded_item) ->
                      # 12.8.8.3.1)
                      compacted_item =
                        if is_list(compacted_item) and length(compacted_item) > 1,
                          do: %{
                            compact_iri("@included", active_context, options) => compacted_item
                          },
                          else: compacted_item

                      # 12.8.8.3.2)
                      if nest_result do
                        # We add nest_result from 12.8.2 here, since we can't add it be reference as specified
                        Map.put(
                          result,
                          nest_term,
                          merge_compacted_value(
                            nest_result,
                            item_active_property,
                            compacted_item,
                            as_array
                          )
                        )
                      else
                        merge_compacted_value(
                          result,
                          item_active_property,
                          compacted_item,
                          as_array
                        )
                      end

                    # 12.8.8.4)
                    true ->
                      # 12.8.8.4.1)
                      compacted_item = %{
                        compact_iri("@graph", active_context, options) => compacted_item
                      }

                      # 12.8.8.4.2)
                      compacted_item =
                        if Map.has_key?(expanded_item, "@id") do
                          Map.put(
                            compacted_item,
                            compact_iri("@id", active_context, options),
                            compact_iri(expanded_item["@id"], active_context, options, nil, false)
                          )
                        else
                          compacted_item
                        end

                      # 12.8.8.4.3)
                      compacted_item =
                        if Map.has_key?(expanded_item, "@index") do
                          Map.put(
                            compacted_item,
                            compact_iri("@index", active_context, options),
                            expanded_item["@index"]
                          )
                        else
                          compacted_item
                        end

                      # 12.8.8.4.4)
                      if nest_result do
                        # We add nest_result from 12.8.2 here, since we can't add it be reference as specified
                        Map.put(
                          result,
                          nest_term,
                          merge_compacted_value(
                            nest_result,
                            item_active_property,
                            compacted_item,
                            as_array
                          )
                        )
                      else
                        merge_compacted_value(
                          result,
                          item_active_property,
                          compacted_item,
                          as_array
                        )
                      end
                  end

                # 12.8.9)
                container -- ~w[@language @index @id @type] != container and
                    "@graph" not in container ->
                  # 12.8.9.1)
                  map_object = (nest_result || result)[item_active_property] || %{}

                  # 12.8.9.2)
                  container_key =
                    ~w[@language @index @id @type]
                    |> Enum.find(&(&1 in container))
                    |> compact_iri(active_context, options)

                  # 12.8.9.3)
                  index_key = (term_def && term_def.index_mapping) || "@index"

                  {compacted_item, map_key} =
                    cond do
                      # 12.8.9.4)
                      # This is the specified version, which fails in several test suite cases
                      #                      "@language" in container and value?(expanded_item) ->
                      #                        {compacted_item["@value"], expanded_item["@language"]}
                      # SPEC ISSUE: the case when compacted_item is not a map is not specified
                      # SPEC ISSUE: we're using the logic from JSON-LD.rb; which diverges also in other aspects
                      "@language" in container ->
                        {
                          if(value?(expanded_item),
                            do: expanded_item["@value"],
                            else: compacted_item
                          ),
                          expanded_item["@language"]
                        }

                      # 12.8.9.5)
                      "@index" in container and index_key == "@index" ->
                        {compacted_item, expanded_item["@index"]}

                      # 12.8.9.6)
                      "@index" in container and index_key != "@index" ->
                        # SPEC ISSUE: the case when compacted_item is not a map (needed to pass tpi05) is not specified (we're using the logic from JSON-LD.rb)
                        if is_map(compacted_item) do
                          # 12.8.9.6.1)
                          # errata "No roundtrip with property-based data indexing" - https://w3c.github.io/json-ld-api/errata/
                          container_key =
                            index_key
                            |> IRIExpansion.expand_iri(active_context, options, false, true)
                            |> compact_iri(active_context, options)

                          # 12.8.9.6.2)
                          [map_key | remaining] = to_list(compacted_item[container_key])

                          # 12.8.9.6.3)
                          # SPEC ISSUE: the case when map_key is not a string (needed to pass tpi06) is not specified (we're using the logic from JSON-LD.rb)
                          if is_binary(map_key) do
                            # SPEC ISSUE: This step is very confusing: why add the same elements again? We follow JSON-LD.rb here ...
                            compacted_item =
                              case remaining do
                                [] -> Map.delete(compacted_item, container_key)
                                [remaining] -> Map.put(compacted_item, container_key, remaining)
                                remaining -> Map.put(compacted_item, container_key, remaining)
                              end

                            {compacted_item, map_key}
                          else
                            {compacted_item, compact_iri("@none", active_context, options)}
                          end
                        else
                          {compacted_item, compact_iri("@none", active_context, options)}
                        end

                      # 12.8.9.7)
                      "@id" in container ->
                        {
                          Map.delete(compacted_item, container_key),
                          compacted_item[container_key]
                        }

                      # 12.8.9.8)
                      "@type" in container ->
                        # 12.8.9.8.1)
                        if is_map(compacted_item) do
                          [map_key | remaining] = to_list(compacted_item[container_key])

                          # 12.8.9.8.2) and 12.8.9.8.3)
                          # SPEC ISSUE: This step is very confusing: why add the same elements again? We follow JSON-LD.rb here ...
                          compacted_item =
                            case remaining do
                              [] -> Map.delete(compacted_item, container_key)
                              [remaining] -> Map.put(compacted_item, container_key, remaining)
                              remaining -> Map.put(compacted_item, container_key, remaining)
                            end

                          # 12.8.9.8.4)
                          compacted_item =
                            if map_size(compacted_item) == 1 and
                                 Map.has_key?(expanded_item, "@id") do
                              compact(
                                %{"@id" => expanded_item["@id"]},
                                active_context,
                                item_active_property,
                                options
                              )
                            else
                              compacted_item
                            end

                          {compacted_item, map_key}
                        else
                          {compacted_item, nil}
                        end

                      true ->
                        {compacted_item, nil}
                    end

                  # 12.8.9.9)
                  map_key = map_key || compact_iri("@none", active_context, options)

                  # 12.8.9.10)
                  map_object =
                    merge_compacted_value(map_object, map_key, compacted_item, as_array)

                  if nest_result do
                    # We add nest_result from 12.8.2 here, since we can't add it be reference as specified
                    Map.put(
                      result,
                      nest_term,
                      Map.put(nest_result, item_active_property, map_object)
                    )
                  else
                    Map.put(result, item_active_property, map_object)
                  end

                # 12.8.10)
                true ->
                  if nest_result do
                    # We add nest_result from 12.8.2 here, since we can't add it be reference as specified
                    Map.put(
                      result,
                      nest_term,
                      merge_compacted_value(
                        nest_result,
                        item_active_property,
                        compacted_item,
                        as_array
                      )
                    )
                  else
                    merge_compacted_value(
                      result,
                      item_active_property,
                      compacted_item,
                      as_array
                    )
                  end
              end
            end)
          end
      end
    end)
  end

  defp merge_compacted_value(map, key, value, as_array) do
    Map.update(map, key, if(as_array and not is_list(value), do: [value], else: value), fn
      old_value when is_list(old_value) and is_list(value) -> old_value ++ value
      old_value when is_list(old_value) -> old_value ++ [value]
      old_value when is_list(value) -> [old_value | value]
      old_value -> [old_value, value]
    end)
  end

  @doc """
  IRI Compaction

  See <https://www.w3.org/TR/json-ld11-api/#iri-compaction>
  """
  @spec compact_iri(any, Context.t(), Options.t(), any | nil, boolean, boolean) :: any | nil
  def compact_iri(
        var,
        active_context,
        options,
        value \\ nil,
        # SPEC ISSUE: the default is defined inconsistently
        # https://www.w3.org/TR/json-ld11-api/#iri-compaction says false
        # https://www.w3.org/TR/json-ld11-api/#dfn-iri-compacting says true
        vocab \\ true,
        reverse \\ false
      )

  # 1) If var is null, return null.
  def compact_iri(nil, _, _, _, _, _), do: nil

  # 2) If the active context has a null inverse context, set inverse context in active context to the result of calling the Inverse Context Creation algorithm using active context.
  def compact_iri(_var, %{inverse_context: nil}, _options, _value, _vocab, _reverse) do
    #    compact_iri(var, Context.set_inverse(active_context), value, vocab, reverse)
    raise """
    We've encountered an uninitialized inverse context, which shouldn't happen.
    Please raise an issue at https://github.com/rdf-elixir/jsonld-ex/issues with the input document that caused this error.
    """
  end

  def compact_iri(var, active_context, options, value, vocab, reverse) do
    processing_mode = options.processing_mode

    # 3) Initialize inverse context to the value of inverse context in active context.
    inverse_context = active_context.inverse_context

    # 4) If vocab is true and var is an entry of inverse context:
    term =
      if vocab && Map.has_key?(inverse_context, var) do
        # 4.1) Initialize default language based on the active context's default language, normalized to lower case and default base direction:
        default_language =
          if active_context.base_direction do
            "#{active_context.default_language}_#{active_context.base_direction}"
          else
            active_context.default_language || "@none"
          end
          |> String.downcase()

        # 4.2) If value is a map containing an @preserve entry, use the first element from the value of @preserve as value.
        value =
          case value do
            %{"@preserve" => preserve} -> List.first(preserve)
            _ -> value
          end

        # 4.4) Initialize type/language to @language, and type/language value to @null. These two variables will keep track of the preferred type mapping or language mapping for a term, based on what is compatible with value.
        type_language = "@language"
        type_language_value = "@null"

        # 4.3) and 4.5)
        containers = if index?(value) and not graph?(value), do: ~w[@index @index@set], else: []

        {containers, type_language, type_language_value} =
          cond do
            # 4.6) If reverse is true, set type/language to @type, type/language value to @reverse, and append @set to containers.
            reverse ->
              containers = containers ++ ["@set"]
              type_language = "@type"
              type_language_value = "@reverse"
              {containers, type_language, type_language_value}

            # 4.7) Otherwise, if value is a list object, then set type/language and type/language value to the most specific values that work for all items in the list as follows:
            list?(value) ->
              # 4.7.1) If @index is not an entry in value, then append @list to containers.
              containers = if not index?(value), do: containers ++ ["@list"], else: containers

              # 4.7.2) Initialize list to the array associated with the @list entry in value.
              list = value["@list"]

              # 4.7.3) Initialize common type and common language to null. If list is empty, set common language to default language.
              {common_type, common_language} = {nil, if(Enum.empty?(list), do: default_language)}

              {type_language, type_language_value} =
                if Enum.empty?(list) do
                  {type_language, type_language_value}
                else
                  # 4.7.4) For each item in list:
                  {common_type, common_language} =
                    Enum.reduce_while(list, {common_type, common_language}, fn
                      item, {common_type, common_language} ->
                        # 4.7.4.1) Initialize item language to @none and item type to @none.
                        {item_type, item_language} = {"@none", "@none"}

                        # 4.7.4.2) If item contains an @value entry:
                        {item_type, item_language} =
                          if Map.has_key?(item, "@value") do
                            cond do
                              # 4.7.4.2.1) If item contains an @direction entry, then set item language to the concatenation of the item's @language entry (if any) the item's @direction, separated by an underscore ("_"), normalized to lower case.
                              Map.has_key?(item, "@direction") ->
                                {item_type,
                                 String.downcase("#{item["@language"]}_#{item["@direction"]}")}

                              # 4.7.4.2.2) Otherwise, if item contains an @language entry, then set item language to its associated value, normalized to lower case.
                              Map.has_key?(item, "@language") ->
                                {item_type, String.downcase(item["@language"])}

                              # 4.7.4.2.3) Otherwise, if item contains a @type entry, set item type to its associated value.
                              Map.has_key?(item, "@type") ->
                                {item["@type"], item_language}

                              # 4.7.4.2.4) Otherwise, set item language to @null.
                              true ->
                                {item_type, "@null"}
                            end

                            # 4.7.4.3) Otherwise, set item type to @id.
                          else
                            {"@id", item_language}
                          end

                        common_language =
                          cond do
                            # 4.7.4.4) If common language is null, set it to item language.
                            is_nil(common_language) ->
                              item_language

                            # 4.7.4.5) Otherwise, if item language does not equal common language and item contains a @value entry, then set common language to @none because list items have conflicting languages.
                            item_language != common_language and Map.has_key?(item, "@value") ->
                              "@none"

                            true ->
                              common_language
                          end

                        common_type =
                          cond do
                            # 4.7.4.6) If common type is null, set it to item type.
                            is_nil(common_type) -> item_type
                            # 4.7.4.7) Otherwise, if item type does not equal common type, then set common type to @none because list items have conflicting types.
                            item_type != common_type -> "@none"
                            true -> common_type
                          end

                        # 4.7.4.8) If common language is @none and common type is @none, then stop processing items in the list because it has been detected that there is no common language or type amongst the items.
                        if common_language == "@none" and common_type == "@none" do
                          {:halt, {common_type, common_language}}
                        else
                          {:cont, {common_type, common_language}}
                        end
                    end)

                  # 4.7.5) If common language is null, set common language to @none.
                  common_language = common_language || "@none"

                  # 4.7.6) If common type is null, set it to @none.
                  common_type = common_type || "@none"

                  # 4.7.7) If common type is not @none then set type/language to @type and type/language value to common type.
                  if common_type != "@none" do
                    type_language = "@type"
                    type_language_value = common_type
                    {type_language, type_language_value}
                  else
                    # 4.7.8) Otherwise, set type/language value to common language.
                    type_language_value = common_language
                    {type_language, type_language_value}
                  end
                end

              {containers, type_language, type_language_value}

            # 4.8) Otherwise, if value is a graph object, prefer a mapping most appropriate for the particular value.
            graph?(value) ->
              # 4.8.1) If value contains an @index entry, append the values @graph@index and @graph@index@set to containers.
              containers =
                if Map.has_key?(value, "@index"),
                  do: containers ++ ~w[@graph@index @graph@index@set],
                  else: containers

              # 4.8.2) If value contains an @id entry, append the values @graph@id and @graph@id@set to containers.
              containers =
                if Map.has_key?(value, "@id"),
                  do: containers ++ ~w[@graph@id @graph@id@set],
                  else: containers

              # 4.8.3) Append the values @graph @graph@set, and @set to containers.
              containers = containers ++ ~w[@graph @graph@set @set]

              # 4.8.4) If value does not contain an @index entry, append the values @graph@index and @graph@index@set to containers.
              containers =
                if not Map.has_key?(value, "@index"),
                  do: containers ++ ~w[@graph@index @graph@index@set],
                  else: containers

              # 4.8.5) If the value does not contain an @id entry, append the values @graph@id and @graph@id@set to containers.
              containers =
                if not Map.has_key?(value, "@id"),
                  do: containers ++ ~w[@graph@id @graph@id@set],
                  else: containers

              # 4.8.6) Append the values @index and @index@set to containers.
              containers = containers ++ ~w[@index @index@set]

              # 4.8.7) Set type/language to @type and set type/language value to @id.
              {containers, "@type", "@id"}

            # 4.9) Otherwise
            true ->
              # 4.9.1) If value is a value object:
              {containers, type_language, type_language_value} =
                if value?(value) do
                  cond do
                    # 4.9.1.1) If value contains an @direction entry and does not contain an @index entry, then set type/language value to the concatenation of the value's @language entry (if any) and the value's @direction entry, separated by an underscore ("_"), normalized to lower case. Append @language and @language@set to containers.
                    Map.has_key?(value, "@direction") and not Map.has_key?(value, "@index") ->
                      type_language_value =
                        String.downcase("#{value["@language"]}_#{value["@direction"]}")

                      containers = containers ++ ~w[@language @language@set]
                      {containers, type_language, type_language_value}

                    # 4.9.1.2) Otherwise, if value contains an @language entry and does not contain an @index entry, then set type/language value to the value of @language normalized to lower case, and append @language, and @language@set to containers.
                    Map.has_key?(value, "@language") and not Map.has_key?(value, "@index") ->
                      type_language_value = String.downcase(value["@language"])
                      containers = containers ++ ~w[@language @language@set]
                      {containers, type_language, type_language_value}

                    # 4.9.1.3) Otherwise, if value contains an @type entry, then set type/language value to its associated value and set type/language to @type.
                    Map.has_key?(value, "@type") ->
                      {containers, "@type", value["@type"]}

                    true ->
                      {containers, type_language, type_language_value}
                  end

                  # 4.9.2) Otherwise, set type/language to @type and set type/language value to @id, and append @id, @id@set, @type, and @set@type, to containers.
                else
                  containers = containers ++ ~w[@id @id@set @type @set@type]
                  {containers, "@type", "@id"}
                end

              # 4.9.3) Append @set to containers.
              containers = containers ++ ["@set"]
              {containers, type_language, type_language_value}
          end

        # 4.10) Append @none to containers. This represents the non-existence of a container mapping, and it will be the last container mapping value to be checked as it is the most generic.
        containers = containers ++ ["@none"]

        # 4.11) If processing mode is not json-ld-1.0 and value is not a map or does not contain an @index entry, append @index and @index@set to containers.
        containers =
          if processing_mode != "json-ld-1.0" and not index?(value) do
            containers ++ ~w[@index @index@set]
          else
            containers
          end

        # 4.12) If processing mode is not json-ld-1.0 and value is a map containing only an @value entry, append @language and @language@set to containers.
        containers =
          if processing_mode != "json-ld-1.0" and value?(value) and map_size(value) == 1 do
            containers ++ ~w[@language and @language@set]
          else
            containers
          end

        # 4.13) If type/language value is null, set type/language value to @null. This is the key under which null values are stored in the inverse context entry.
        type_language_value = type_language_value || "@null"

        # 4.14) Initialize preferred values to an empty array. This array will indicate, in order, the preferred values for a term's type mapping or language mapping.
        preferred_values = []

        # 4.15) If type/language value is @reverse, append @reverse to preferred values.
        preferred_values =
          if type_language_value == "@reverse",
            do: preferred_values ++ ["@reverse"],
            else: preferred_values

        # 4.16) If type/language value is @id or @reverse and value is a map containing an @id entry
        {preferred_values, type_language} =
          if type_language_value in ~w[@id @reverse] and is_map(value) and
               Map.has_key?(value, "@id") do
            # 4.16.1) If the result of IRI compacting the value of the @id entry in value has a term definition in the active context with an IRI mapping that equals the value of the @id entry in value, then append @vocab, @id, and @none, in that order, to preferred values.

            compact_id = compact_iri(value["@id"], active_context, options)
            term_def = active_context.term_defs[compact_id]

            if term_def && term_def.iri_mapping == value["@id"] do
              {preferred_values ++ ~w[@vocab @id @none], type_language}
            else
              # 4.16.2) Otherwise, append @id, @vocab, and @none, in that order, to preferred values.
              {preferred_values ++ ~w[@id @vocab @none], type_language}
            end
          else
            # 4.17) Otherwise, append type/language value and @none, in that order, to preferred values. If value is a list object with an empty array as the value of @list, set type/language to @any.
            {
              preferred_values ++ [type_language_value, "@none"],
              if list?(value) and value["@list"] == [] do
                "@any"
              else
                type_language
              end
            }
          end

        # 4.18) Append @any to preferred values.
        preferred_values = preferred_values ++ ["@any"]

        # 4.19) If preferred values contains any entry having an underscore ("_"), append the substring of that entry from the underscore to the end of the string to preferred values.
        preferred_values =
          if lang_dir = Enum.find(preferred_values, &String.contains?(&1, "_")) do
            preferred_values ++ ["_" <> (lang_dir |> String.split("_") |> List.last())]
          else
            preferred_values
          end

        # 4.20) Initialize term to the result of the Term Selection algorithm, passing var, containers, type/language, and preferred values.
        select_term(active_context, var, containers, type_language, preferred_values)
      end

    cond do
      # 4.21) If term is not null, return term.
      not is_nil(term) ->
        term

      # 5) At this point, there is no simple term that var can be compacted to. If vocab is true and active context has a vocabulary mapping:
      # 5.1) If var begins with the vocabulary mapping's value but is longer, then initialize suffix to the substring of var that does not match. If suffix does not have a term definition in active context, then return suffix.
      vocab && active_context.vocabulary_mapping &&
          String.starts_with?(var, active_context.vocabulary_mapping) ->
        suffix = String.replace_prefix(var, active_context.vocabulary_mapping, "")

        if suffix != "" && is_nil(active_context.term_defs[suffix]) do
          String.replace_prefix(var, active_context.vocabulary_mapping, "")
        else
          create_compact_iri(var, active_context, value, vocab)
        end

      true ->
        create_compact_iri(var, active_context, value, vocab)
    end
  end

  defp create_compact_iri(var, active_context, value, vocab) do
    # 6) The var could not be compacted using the active context's vocabulary mapping. Try to create a compact IRI, starting by initializing compact IRI to null. This variable will be used to store the created compact IRI, if any.
    # 7) For each term definition definition in active context:
    compact_iri =
      active_context.term_defs
      |> Enum.flat_map(fn {term, term_def} ->
        cond do
          # 7.1) If the IRI mapping of definition is null, its IRI mapping equals var, its IRI mapping is not a substring at the beginning of var, or definition does not have a true prefix flag, definition's key cannot be used as a prefix. Continue with the next definition.
          is_nil(term_def) or is_nil(term_def.iri_mapping) or term_def.iri_mapping == var or
            not String.starts_with?(var, term_def.iri_mapping) or
              term_def.prefix_flag != true ->
            []

          true ->
            # 7.2) Initialize candidate by concatenating definition key, a colon (:), and the substring of var that follows after the value of the definition's IRI mapping.
            candidate =
              term <>
                ":" <> (String.split_at(var, String.length(term_def.iri_mapping)) |> elem(1))

            # 7.3) If either compact IRI is null, candidate is shorter or the same length but lexicographically less than compact IRI and candidate does not have a term definition in active context, or if that term definition has an IRI mapping that equals var and value is null, set compact IRI to candidate.
            #      Note: we're skipping the shortest_or_least comparison here and select it afterwards instead
            candidate_term_def = active_context.term_defs[candidate]

            if is_nil(candidate_term_def) or
                 (candidate_term_def.iri_mapping == var and is_nil(value)) do
              [candidate]
            else
              []
            end
        end
      end)
      # 7.3)
      |> Enum.min(&shortest_or_least?/2, fn -> nil end)

    # 8) If compact IRI is not null, return compact IRI.
    if not is_nil(compact_iri) do
      compact_iri
    else
      # 9) To ensure that the IRI var is not confused with a compact IRI, if the IRI scheme of var matches any term in active context with prefix flag set to true, and var has no IRI authority (preceded by double-forward-slash (//), an IRI confused with prefix error has been detected, and processing is aborted.
      Enum.each(active_context.term_defs, fn {term, term_def} ->
        if (term_def && term_def.prefix_flag) and String.starts_with?(var, "#{term}:") do
          raise JSON.LD.IRIConfusedWithPrefixError,
            message: "Absolute IRI '#{var}' confused with prefix '#{term}'"
        end
      end)

      # 10) If vocab is false, transform var to a relative IRI reference using the base IRI from active context, if it exists.
      if not vocab do
        relative_iri = remove_base(var, Context.base(active_context))

        # SPEC ISSUE: making this relative if it has the form of a keyword is not specified but needed for t0111
        if keyword_form?(relative_iri) do
          "./" <> relative_iri
        else
          relative_iri
        end
      else
        # 11) Finally, return var as is.
        var
      end
    end
  end

  @spec shortest_or_least?(String.t(), String.t()) :: boolean
  defp shortest_or_least?(a, b) do
    (a_len = String.length(a)) < (b_len = String.length(b)) or
      (a_len == b_len and a < b)
  end

  @spec remove_base(String.t(), String.t() | nil) :: String.t()
  defp remove_base(iri, nil), do: iri

  defp remove_base(iri, base) do
    base_len = String.length(base)

    if String.starts_with?(iri, base) and String.at(iri, base_len) in ~w(? #) do
      String.split_at(iri, base_len) |> elem(1)
    else
      case URI.parse(base) do
        %URI{path: nil} ->
          iri

        base ->
          do_remove_base(
            iri,
            %URI{
              base
              | path:
                  if(String.ends_with?(base.path, "/"),
                    do: base.path,
                    else: parent_path(base.path)
                  )
            },
            0
          )
      end
    end
  end

  @spec do_remove_base(String.t(), URI.t(), non_neg_integer) :: String.t()
  defp do_remove_base(iri, base, index) do
    base_str = URI.to_string(base)

    cond do
      String.starts_with?(iri, base_str) ->
        case String.duplicate("../", index) <>
               (String.split_at(iri, String.length(base_str)) |> elem(1)) do
          "" -> "./"
          rel -> rel
        end

      base.path == "/" ->
        iri

      true ->
        do_remove_base(iri, %URI{base | path: parent_path(base.path)}, index + 1)
    end
  end

  defp parent_path("/"), do: "/"

  defp parent_path(path) do
    case Path.dirname(String.trim_trailing(path, "/")) do
      "/" -> "/"
      parent -> parent <> "/"
    end
  end

  @doc """
  Value Compaction

  Details at <https://www.w3.org/TR/json-ld-api/#value-compaction>
  """
  @spec compact_value(any, Context.t(), String.t(), Options.t()) :: any
  def compact_value(_value, %{inverse_context: nil}, _active_property, _options) do
    #    compact_value(value, Context.set_inverse(active_context), active_property, options)
    raise """
    We've encountered an uninitialized inverse context, which shouldn't happen.
    Please raise an issue at https://github.com/rdf-elixir/jsonld-ex/issues with the input document that caused this error.
    """
  end

  def compact_value(value, active_context, active_property, options) do
    term_def = active_context.term_defs[active_property]

    # 4) Initialize language to the language mapping for active property in active context, if any, otherwise to the default language of active context.
    language = Context.TermDefinition.language(term_def, active_context)

    # 5) Initialize direction to the direction mapping for active property in active context, if any, otherwise to the default base direction of active context.
    direction = Context.TermDefinition.direction(term_def, active_context) |> to_string

    result =
      cond do
        # 6) If value has an @id entry and has no other entries other than @index:
        (id = value["@id"]) && map_size(value) == 1 ->
          cond do
            # 6.1) If the type mapping of active property is set to @id, set result to the result of IRI compacting the value associated with the @id entry using false for vocab.
            term_def && term_def.type_mapping == "@id" ->
              compact_iri(id, active_context, options, nil, false)

            # 6.2) Otherwise, if the type mapping of active property is set to @vocab, set result to the result of IRI compacting the value associated with the @id entry.
            term_def && term_def.type_mapping == "@vocab" ->
              compact_iri(id, active_context, options)

            # SPEC ISSUE: Otherwise is no longer specified
            true ->
              value
          end

        # 7) Otherwise, if value has an @type entry whose value matches the type mapping of active property, set result to the value associated with the @value entry of value.
        Map.has_key?(value, "@type") && value["@type"] == (term_def && term_def.type_mapping) ->
          value["@value"]

        # 8) Handle other type mappings
        # SPEC ISSUE: Step 8 of the spec is ambiguous about the exact behavior when
        # there's a type mismatch. The spec suggests "leave value as is" but doesn't
        # clarify if this means before or after compacting the @type value. All
        # implementations compact the @type value while keeping the expanded structure,
        # suggesting this is the intended behavior. The spec should be clearer about this.
        (term_def && term_def.type_mapping == "@none") || Map.has_key?(value, "@type") ->
          if Map.has_key?(value, "@type") do
            Map.update!(value, "@type", fn
              types when is_list(types) ->
                Enum.map(types, &compact_iri(&1, active_context, options))

              type ->
                compact_iri(type, active_context, options)
            end)
          else
            value
          end

        # 9) Otherwise, if the value of the @value entry is not a string:
        not is_binary(value_value = value["@value"]) ->
          if ((is_index = index?(value)) and "@index" in List.wrap(term_def.container_mapping)) or
               not is_index do
            value_value
          else
            value
          end

        # 10) Otherwise, if value has an @language entry whose value exactly matches language, using a case-insensitive comparison if it is not null, or is not present, if language is null, and the value has an @direction entry whose value exactly matches direction, if it is not null, or is not present, if direction is null:
        # SPEC ISSUE:
        value["@language"] |> to_string() |> String.downcase() ==
          language |> to_string() |> String.downcase() &&
            (value["@direction"] == direction || !Map.has_key?(value, "@direction")) ->
          if ((is_index = index?(value)) and "@index" in List.wrap(term_def.container_mapping)) or
               not is_index do
            value["@value"]
          else
            value
          end

        true ->
          value
      end

    # 11) If result is a map, replace each key in result with the result of IRI compacting that key.
    if is_map(result) do
      Map.new(result, fn {k, v} -> {compact_iri(k, active_context, options), v} end)
    else
      result
    end
  end

  @doc """
  Term Selection

  Note: Other than specified in W3C spec we assume here that the inverse context is already created,
  since we don't want to return an updated context. Effectively an inverse context is never needed
  in the only place where this function is used.

  <https://www.w3.org/TR/json-ld11-api/#term-selection>
  """
  @spec select_term(Context.t(), String.t(), [String.t()], String.t(), [String.t()]) ::
          String.t() | nil
  def select_term(
        %{inverse_context: inverse_context},
        var,
        containers,
        type_language,
        preferred_values
      )
      when not is_nil(inverse_context) do
    # 3)
    container_map = inverse_context[var]

    # 4)
    Enum.find_value(containers, fn container ->
      if type_language_map = container_map[container] do
        value_map = type_language_map[type_language]
        Enum.find_value(preferred_values, fn item -> value_map[item] end)
      end
    end)
  end
end
