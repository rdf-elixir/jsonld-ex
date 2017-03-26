defmodule JSON.LD.Compaction do
  @moduledoc nil

  import JSON.LD.Utils
  alias JSON.LD.Context


  def compact(input, context, options \\ %JSON.LD.Options{}) do
    with options         = JSON.LD.Options.new(options),
         active_context  = JSON.LD.context(context),
         inverse_context = Context.inverse(active_context),
         expanded        = JSON.LD.expand(input, options)
    do
      result =
        case do_compact(expanded, active_context, inverse_context, nil, options.compact_arrays) do
          [] ->
            %{}
          result when is_list(result) ->
            # TODO: Spec fixme? We're setting vocab to true, as other implementations do it, but this is not mentioned in the spec
            %{compact_iri("@graph", active_context, inverse_context, nil, true) => result}
          result ->
            result
        end
      if Context.empty?(active_context),
        do: result,
        else: Map.put(result, "@context", context["@context"] || context)
    end
  end

  defp do_compact(element, active_context, inverse_context, active_property,
                  compact_arrays \\ true)


  # 1) If element is a scalar, it is already in its most compact form, so simply return element.
  defp do_compact(element, _, _, _, _)
    when is_binary(element) or is_number(element) or is_boolean(element),
    do: element

  # 2) If element is an array
  defp do_compact(element, active_context, inverse_context, active_property, compact_arrays)
        when is_list(element) do
    result = Enum.reduce(element, [], fn (item, result) ->
      case do_compact(item, active_context, inverse_context, active_property, compact_arrays) do
        nil            -> result
        compacted_item -> [compacted_item | result]
      end
    end) |> Enum.reverse
    if compact_arrays and length(result) == 1 and
         is_nil((term_def = active_context.term_defs[active_property]) && term_def.container_mapping) do
      List.first(result)
    else
      result
    end
  end

  # 3) Otherwise element is a JSON object.
  defp do_compact(element, active_context, inverse_context, active_property, compact_arrays)
          when is_map(element) do
    # 4)
    if (Map.has_key?(element, "@value") or Map.has_key?(element, "@id")) and
        scalar?(result = compact_value(element, active_context, inverse_context, active_property)) do
      result
    else
      # 5)
      inside_reverse = active_property == "@reverse"
      # 6) + 7)
      element
      |> Enum.sort_by(fn {expanded_property , _} -> expanded_property end)
      |> Enum.reduce(%{}, fn ({expanded_property, expanded_value}, result) ->
          cond do
            # 7.1)
            expanded_property in ~w[@id @type] ->
              # 7.1.1)
              compacted_value =
                if is_binary(expanded_value) do
                  compact_iri(expanded_value, active_context, inverse_context, nil,
                               expanded_property == "@type")
                # 7.1.2)
                else
                  # 7.1.2.1)
                  # TODO: RDF.rb calls also Array#compact
                  if(is_list(expanded_value),
                    do: expanded_value,
                    else: [expanded_value])
                  # 7.1.2.2)
                  |> Enum.reduce([], fn (expanded_type, compacted_value) ->
                       compacted_value ++
                        [compact_iri(expanded_type, active_context, inverse_context, nil, true)]
                     end)
                  # 7.1.2.3)
                  |> case(do: (
                      [compacted_value] -> compacted_value
                       compacted_value  -> compacted_value))
                end
              # 7.1.3)
              alias = compact_iri(expanded_property, active_context, inverse_context, nil, true)
              # 7.1.4)
              Map.put(result, alias, compacted_value)

            # 7.2)
            expanded_property == "@reverse" ->
              # 7.2.1)
              compacted_value = do_compact(expanded_value, active_context, inverse_context, "@reverse")
              # 7.2.2)
              {compacted_value, result} =
                Enum.reduce compacted_value, {%{}, result},
                  fn ({property, value}, {compacted_value, result}) ->
                    term_def = active_context.term_defs[property]
                    # 7.2.2.1)
                    if term_def && term_def.reverse_property do
                      # 7.2.2.1.1)
                      if (!compact_arrays or term_def.container_mapping == "@set") and
                           !is_list(value) do
                        value = [value]
                      end
                      # 7.2.2.1.2) + 7.2.2.1.3)
                      {compacted_value, merge_compacted_value(result, property, value)}
                    else
                      {Map.put(compacted_value, property, value), result}
                    end
                  end
              # 7.2.3)
              unless Enum.empty?(compacted_value) do
                # 7.2.3.1)
                alias = compact_iri("@reverse", active_context, inverse_context, nil, true)
                # 7.2.3.2)
                Map.put(result, alias, compacted_value)
              else
                result
              end

            # 7.3)
            expanded_property == "@index" &&
                (term_def = active_context.term_defs[active_property]) &&
                term_def.container_mapping == "@index" ->
              result

            # 7.4)
            expanded_property in ~w[@index @value @language] ->
              # 7.4.1)
              alias = compact_iri(expanded_property, active_context, inverse_context, nil, true)
              # 7.4.2)
              Map.put(result, alias, expanded_value)

            true ->
              # 7.5)
              if expanded_value == [] do
                # 7.5.1)
                item_active_property =
                  compact_iri(expanded_property, active_context, inverse_context,
                              expanded_value, true, inside_reverse)
                # 7.5.2)
                result = Map.update(result, item_active_property, [], fn
                   value when not is_list(value) -> [value]
                   value                         -> value
                end)
              end

              # 7.6)
              Enum.reduce(expanded_value, result, fn (expanded_item, result) ->
                # 7.6.1)
                item_active_property =
                  compact_iri(expanded_property, active_context, inverse_context,
                              expanded_item, true, inside_reverse)

                # 7.6.2)
                term_def = active_context.term_defs[item_active_property]
                container = (term_def && term_def.container_mapping) || nil

                # 7.6.3)
                value = (is_map(expanded_item) && expanded_item["@list"]) || expanded_item
                compacted_item =
                  do_compact(value, active_context, inverse_context,
                              item_active_property, compact_arrays)

                # 7.6.4)
                if list?(expanded_item) do
                  # 7.6.4.1)
                  unless is_list(compacted_item),
                    do: compacted_item = [compacted_item]
                  # 7.6.4.2)
                  unless container == "@list" do
                    # 7.6.4.2.1)
                    compacted_item = %{
                      # TODO: Spec fixme? We're setting vocab to true, as other implementations do it, but this is not mentioned in the spec
                      compact_iri("@list", active_context, inverse_context, nil, true) =>
                        compacted_item}
                    # 7.6.4.2.2)
                      if Map.has_key?(expanded_item, "@index") do
                        compacted_item = Map.put(compacted_item,
                          # TODO: Spec fixme? We're setting vocab to true, as other implementations do it, but this is not mentioned in the spec
                          compact_iri("@index", active_context, inverse_context, nil, true),
                          expanded_item["@index"])
                      end
                  # 7.6.4.3)
                  else
                    if Map.has_key?(result, item_active_property),
                      do: raise JSON.LD.CompactionToListOfListsError,
                            message: "The compacted document contains a list of lists as multiple lists have been compacted to the same term."
                  end
                end

                # 7.6.5)
                if container in ~w[@language @index] do
                  map_object = result[item_active_property] || %{}
                  if container == "@language" and
                      is_map(compacted_item) and Map.has_key?(compacted_item, "@value"),
                    do: compacted_item = compacted_item["@value"]
                  map_key = expanded_item[container]
                  map_object = merge_compacted_value(map_object, map_key, compacted_item)
                  Map.put(result, item_active_property, map_object)

                # 7.6.6)
                else
                  if !is_list(compacted_item) and (!compact_arrays or
                        container in ~w[@set @list] or expanded_property in ~w[@list @graph]),
                    do: compacted_item = [compacted_item]
                  merge_compacted_value(result, item_active_property, compacted_item)
                end
              end)
          end
      end)
    end
  end

  defp merge_compacted_value(map, key, value) do
    Map.update map, key, value, fn
      old_value when is_list(old_value) and is_list(value) ->
        old_value ++ value
      old_value when is_list(old_value) ->
        old_value ++ [value]
      old_value when is_list(value) ->
        [old_value | value]
      old_value ->
        [old_value, value]
    end
  end


  @doc """
  IRI Compaction

  Details at <https://www.w3.org/TR/json-ld-api/#iri-compaction>
  """
  def compact_iri(iri, active_context, inverse_context,
                  value \\ nil, vocab \\ false, reverse \\ false)

  # 1) If iri is null, return null.
  def compact_iri(nil, _, _, _, _, _), do: nil

  def compact_iri(iri, active_context, inverse_context, value, vocab, reverse) do
    # 2) If vocab is true and iri is a key in inverse context:
    term = if vocab && Map.has_key?(inverse_context, iri) do
      # 2.1) Initialize default language to active context's default language, if it has one, otherwise to @none.
      default_language = active_context.default_language || "@none"
      # 2.3) Initialize type/language to @language, and type/language value to @null. These two variables will keep track of the preferred type mapping or language mapping for a term, based on what is compatible with value.
      type_language = "@language"
      type_language_value = "@null"
      # 2.2) Initialize containers to an empty array. This array will be used to keep track of an ordered list of preferred container mappings for a term, based on what is compatible with value.
      # 2.4) If value is a JSON object that contains the key @index, then append the value @index to containers.
      containers = if index?(value), do: ["@index"], else: []
      cond do
        # 2.5) If reverse is true, set type/language to @type, type/language value to @reverse, and append @set to containers.
        reverse ->
          containers = containers ++ ["@set"]
          type_language = "@type"
          type_language_value = "@reverse"
        # 2.6) Otherwise, if value is a list object, then set type/language and type/language value to the most specific values that work for all items in the list as follows:
        list?(value) ->
          # 2.6.1) If @index is a not key in value, then append @list to containers.
          if not index?(value),
            do: containers = containers ++ ["@list"]
          # 2.6.2) Initialize list to the array associated with the key @list in value.
          list = value["@list"]
          # 2.6.3) Initialize common type and common language to null. If list is empty, set common language to default language.
          {common_type, common_language} = {nil, nil}
          if Enum.empty?(list) do
            common_language = default_language
          else
            # 2.6.4) For each item in list:
            {common_type, common_language} = Enum.reduce_while list, {common_type, common_language},
              fn (item, {common_type, common_language}) ->
                # 2.6.4.1) Initialize item language to @none and item type to @none.
                {item_type, item_language} = {"@none", "@none"}
                # 2.6.4.2) If item contains the key @value:
                if Map.has_key?(item, "@value") do
                  cond do
                    # 2.6.4.2.1) If item contains the key @language, then set item language to its associated value.
                    Map.has_key?(item, "@language") ->
                      item_language = item["@language"]
                    # 2.6.4.2.2) Otherwise, if item contains the key @type, set item type to its associated value.
                    Map.has_key?(item, "@type") ->
                      item_type = item["@type"]
                    # 2.6.4.2.3) Otherwise, set item language to @null.
                    true ->
                      item_language = "@null"
                  end
                # 2.6.4.3) Otherwise, set item type to @id.
                else
                  item_type = "@id"
                end
                cond do
                  # 2.6.4.4) If common language is null, set it to item language.
                  is_nil(common_language) ->
                    common_language = item_language
                  # 2.6.4.5) Otherwise, if item language does not equal common language and item contains the key @value, then set common language to @none because list items have conflicting languages.
                  item_language != common_language and Map.has_key?(item, "@value") ->
                    common_language = "@none"
                  true ->
                end
                cond do
                  # 2.6.4.6) If common type is null, set it to item type.
                  is_nil(common_type) ->
                    common_type = item_type
                  # 2.6.4.7) Otherwise, if item type does not equal common type, then set common type to @none because list items have conflicting types.
                  item_type != common_type ->
                    common_type = "@none"
                  true ->
                end
                # 2.6.4.8) If common language is @none and common type is @none, then stop processing items in the list because it has been detected that there is no common language or type amongst the items.
                if common_language == "@none" and common_type == "@none" do
                  {:halt, {common_type, common_language}}
                else
                  {:cont, {common_type, common_language}}
                end
              end
            # 2.6.5) If common language is null, set it to @none.
            if is_nil(common_language), do: common_language = "@none"
            # 2.6.6) If common type is null, set it to @none.
            if is_nil(common_type), do: common_type = "@none"
            # 2.6.7) If common type is not @none then set type/language to @type and type/language value to common type.
            if common_type != "@none" do
              type_language = "@type"
              type_language_value = common_type
            # 2.6.8) Otherwise, set type/language value to common language.
            else
              type_language_value = common_language
            end
          end
        # 2.7) Otherwise
        true ->
          # 2.7.1) If value is a value object:
          if is_map(value) and Map.has_key?(value, "@value") do
          # 2.7.1.1) If value contains the key @language and does not contain the key @index, then set type/language value to its associated value and append @language to containers.
            if Map.has_key?(value, "@language") and not Map.has_key?(value, "@index") do
              type_language_value = value["@language"]
              containers = containers ++ ["@language"]
            else
            # 2.7.1.2) Otherwise, if value contains the key @type, then set type/language value to its associated value and set type/language to @type.
              if Map.has_key?(value, "@type") do
                type_language_value = value["@type"]
                type_language = "@type"
              end
            end
          # 2.7.2) Otherwise, set type/language to @type and set type/language value to @id.
          else
            type_language = "@type"
            type_language_value = "@id"
          end
          # 2.7.3) Append @set to containers.
          containers = containers ++ ["@set"]
      end
      # 2.8) Append @none to containers. This represents the non-existence of a container mapping, and it will be the last container mapping value to be checked as it is the most generic.
      containers = containers ++ ["@none"]
      # 2.9) If type/language value is null, set it to @null. This is the key under which null values are stored in the inverse context entry.
      if is_nil(type_language_value), do: type_language_value = "@null"
      # 2.10) Initialize preferred values to an empty array. This array will indicate, in order, the preferred values for a term's type mapping or language mapping.
      preferred_values = []
      # 2.11) If type/language value is @reverse, append @reverse to preferred values.
      if type_language_value == "@reverse",
        do: preferred_values = preferred_values ++ ["@reverse"]
      # 2.12) If type/language value is @id or @reverse and value has an @id member:
      if type_language_value in ~w[@id @reverse] and is_map(value) and Map.has_key?(value, "@id") do
        # 2.12.1) If the result of using the IRI compaction algorithm, passing active context, inverse context, the value associated with the @id key in value for iri, true for vocab, and true for document relative has a term definition in the active context with an IRI mapping that equals the value associated with the @id key in value, then append @vocab, @id, and @none, in that order, to preferred values.
        # TODO: Spec fixme? document_relative is not a specified parameter of compact_iri
        compact_id = compact_iri(value["@id"], active_context, inverse_context, nil, true)
        if (term_def = active_context.term_defs[compact_id]) && term_def.iri_mapping == value["@id"] do
          preferred_values = preferred_values ++ ~w[@vocab @id @none]
        # 2.12.2) Otherwise, append @id, @vocab, and @none, in that order, to preferred values.
        else
          preferred_values = preferred_values ++ ~w[@id @vocab @none]
        end
      # 2.13) Otherwise, append type/language value and @none, in that order, to preferred values.
      else
        preferred_values = preferred_values ++ [type_language_value, "@none"]
      end
      # 2.14) Initialize term to the result of the Term Selection algorithm, passing inverse context, iri, containers, type/language, and preferred values.
      select_term(inverse_context, iri, containers, type_language, preferred_values)
    end
    cond do
      # 2.15) If term is not null, return term.
      not is_nil(term) ->
        term
      # 3) At this point, there is no simple term that iri can be compacted to. If vocab is true and active context has a vocabulary mapping:
      # 3.1) If iri begins with the vocabulary mapping's value but is longer, then initialize suffix to the substring of iri that does not match. If suffix does not have a term definition in active context, then return suffix.
      vocab && active_context.vocab &&
          String.starts_with?(iri, active_context.vocab) &&
          (suffix = String.replace_prefix(iri, active_context.vocab, "")) != "" &&
          is_nil(active_context.term_defs[suffix]) ->
        suffix
      true ->
        # 4) The iri could not be compacted using the active context's vocabulary mapping. Try to create a compact IRI, starting by initializing compact IRI to null. This variable will be used to tore the created compact IRI, if any.
        compact_iri =
        # 5) For each key term and value term definition in the active context:
          Enum.reduce(active_context.term_defs, nil, fn ({term, term_def}, compact_iri) ->
            cond do
              # 5.1) If the term contains a colon (:), then continue to the next term because terms with colons can't be used as prefixes.
              String.contains?(term, ":") ->
                compact_iri
              # 5.2) If the term definition is null, its IRI mapping equals iri, or its IRI mapping is not a substring at the beginning of iri, the term cannot be used as a prefix because it is not a partial match with iri. Continue with the next term.
              is_nil(term_def) || term_def.iri_mapping == iri ||
                  not String.starts_with?(iri, term_def.iri_mapping) ->
                compact_iri
              true ->
                # 5.3) Initialize candidate by concatenating term, a colon (:), and the substring of iri that follows after the value of the term definition's IRI mapping.
                candidate = term <> ":" <> (String.split_at(iri, String.length(term_def.iri_mapping)) |> elem(1))
                # 5.4) If either compact IRI is null or candidate is shorter or the same length but lexicographically less than compact IRI and candidate does not have a term definition in active context or if the term definition has an IRI mapping that equals iri and value is null, set compact IRI to candidate.
                # TODO: Spec fixme: The specified expression is pretty ambiguous without brackets ...
                # TODO: Spec fixme: "if the term definition has an IRI mapping that equals iri" is already catched in 5.2, so will never happen here ...
                if (is_nil(compact_iri) or shortest_or_least?(candidate, compact_iri)) and
                     (is_nil(active_context.term_defs[candidate]) or
                        (term_def.iri_mapping == iri and is_nil(value))) do
                  candidate
                else
                  compact_iri
                end
            end
          end)
        cond do
          # 6) If compact IRI is not null, return compact IRI.
          not is_nil(compact_iri) ->
            compact_iri
          # 7) If vocab is false then transform iri to a relative IRI using the document's base IRI.
          not vocab ->
            remove_base(iri, active_context.base_iri)
          # 8) Finally, return iri as is.
          true ->
            iri
        end
    end
  end

  defp shortest_or_least?(a, b) do
    (a_len = String.length(a)) < (b_len = String.length(b)) or
      (a_len == b_len and a < b)
  end

  defp remove_base(iri, nil), do: iri

  defp remove_base(iri, base) do
    base_len = String.length(base)
    if String.starts_with?(iri, base) and String.at(iri, base_len) in ~w(? #) do
      String.split_at(iri, base_len) |> elem(1)
    else
      case URI.parse(base) do
        %URI{path: nil} -> iri
        base ->
          do_remove_base(iri, %URI{base | path: Path.dirname(base.path)}, 0)
      end
    end
  end

  defp do_remove_base(iri, base, index) do
    base_str = URI.to_string(base)
    cond do
      String.starts_with?(iri, base_str) ->
        case String.duplicate("../", index) <>
                (String.split_at(iri, String.length(base_str)) |> elem(1)) do
          ""  -> "./"
          rel -> rel
        end
      base.path == "/" -> iri
      true ->
        do_remove_base(iri, %URI{base | path: Path.dirname(base.path)}, index + 1)
    end
  end


  @doc """
  Value Compaction

  Details at <https://www.w3.org/TR/json-ld-api/#value-compaction>
  """
  def compact_value(value, active_context, inverse_context, active_property) do
    term_def = active_context.term_defs[active_property]
    # 1) Initialize number members to the number of members value contains.
    number_members = Enum.count(value)
    # 2) If value has an @index member and the container mapping associated to active property is set to @index, decrease number members by 1.
    number_members =
      if term_def != nil and Map.has_key?(value, "@index") and
          term_def.container_mapping == "@index",
        do: number_members - 1, else: number_members
    # 3) If number members is greater than 2, return value as it cannot be compacted.
    unless number_members > 2 do
      {type_mapping, language_mapping} = if term_def,
          do: {term_def.type_mapping, term_def.language_mapping},
          else: {nil, nil}
      cond do
        # 4) If value has an @id member
        id = Map.get(value, "@id") ->
          cond do
            # 4.1) If number members is 1 and the type mapping of active property is set to @id, return the result of using the IRI compaction algorithm, passing active context, inverse context, and the value of the @id member for iri.
            number_members == 1 and type_mapping == "@id" ->
              compact_iri(id, active_context, inverse_context)
            # 4.2) Otherwise, if number members is 1 and the type mapping of active property is set to @vocab, return the result of using the IRI compaction algorithm, passing active context, inverse context, the value of the @id member for iri, and true for vocab.
            number_members == 1 and type_mapping == "@vocab" ->
              compact_iri(id, active_context, inverse_context, nil, true)
            # 4.3) Otherwise, return value as is.
            true ->
              value
          end
        # 5) Otherwise, if value has an @type member whose value matches the type mapping of active property, return the value associated with the @value member of value.
        (type = Map.get(value, "@type")) && type == type_mapping ->
          value["@value"]
        # 6) Otherwise, if value has an @language member whose value matches the language mapping of active property, return the value associated with the @value member of value.
        (language = Map.get(value, "@language")) &&
          # TODO: Spec fixme: doesn't specify to check default language as well
          language in [language_mapping, active_context.default_language] ->
          value["@value"]
        true ->
          # 7) Otherwise, if number members equals 1 and either the value of the @value member is not a string, or the active context has no default language, or the language mapping of active property is set to null,, return the value associated with the @value member.
          if number_members == 1 and
              (not is_binary(value_value = value["@value"]) or
              !active_context.default_language or
              # TODO: Spec fixme: doesn't specify to check default language as well
              Context.language(active_context, active_property) == nil) do
              value_value
            # 8) Otherwise, return value as is.
            else
              value
            end
      end
    else
      value
    end
  end

  @doc """
  Term Selection

  Details at <https://www.w3.org/TR/json-ld-api/#term-selection>
  """
  def select_term(inverse_context, iri, containers, type_language, preferred_values) do
    container_map = inverse_context[iri]
    Enum.find_value containers, fn container ->
      if type_language_map = container_map[container] do
        value_map = type_language_map[type_language]
        Enum.find_value preferred_values, fn item -> value_map[item] end
      end
    end
  end

end
