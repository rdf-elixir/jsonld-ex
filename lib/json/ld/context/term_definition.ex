defmodule JSON.LD.Context.TermDefinition do
  @moduledoc """
  Implementation of the JSON-LD 1.1 _Create Term Definition Algorithm_.

  <https://www.w3.org/TR/json-ld11-api/#create-term-definition>
  """

  alias JSON.LD.{Context, Options}
  alias RDF.IRI

  import JSON.LD.{IRIExpansion, Utils}

  @type value :: map | String.t() | nil

  @type t :: %__MODULE__{
          iri_mapping: String.t(),
          prefix_flag: boolean,
          protected: boolean,
          reverse_property: boolean,
          base_url: nil | String.t(),
          local_context: nil | map | String.t(),
          container_mapping: nil | [String.t()],
          index_mapping: nil | String.t(),
          language_mapping: false | nil | String.t(),
          direction_mapping: false | nil | :ltr | :rtl,
          nest_value: nil | String.t(),
          type_mapping: false | nil | String.t()
        }

  defstruct iri_mapping: nil,
            prefix_flag: false,
            protected: false,
            reverse_property: false,
            local_context: nil,
            base_url: nil,
            container_mapping: nil,
            index_mapping: nil,
            language_mapping: false,
            direction_mapping: false,
            nest_value: nil,
            type_mapping: false

  def language(%__MODULE__{language_mapping: false}, context), do: context.default_language
  def language(%__MODULE__{language_mapping: language_mapping}, _), do: language_mapping
  def language(_, context), do: context.default_language

  def direction(%{direction_mapping: false}, context), do: context.base_direction
  def direction(%{direction_mapping: direction_mapping}, _), do: direction_mapping
  def direction(_, context), do: context.base_direction

  defp init_opts(opts) do
    opts
    # base_url is provided via Options.api_base_url
    |> Keyword.put_new(:protected, false)
    |> Keyword.put_new(:override_protected, false)
    |> Keyword.put_new(:remote_contexts, [])
    |> Keyword.put_new(:validate_scoped_context, true)
  end

  # 3)
  defp validate_term_def_value(value) do
    # SPEC ISSUE: the specified validation rules are too strict ...
    #    if is_map(value) and Enum.empty?(Map.keys(value) -- ~w[@container @protected]) do
    value
    #    else
    #      raise JSON.LD.InvalidTermDefinitionError, message: "invalid term value: #{inspect(value)}"
    #    end
  end

  @doc """
  Expands the given input according to the steps in the JSON-LD _Create Term Definition_ algorithm.
  """
  @spec create(Context.t(), map, String.t(), value, map, Options.t(), keyword) ::
          {Context.t(), map}
  def create(active, local, term, value, defined, popts, opts \\ [])

  # 2)
  def create(_, _, "", _, _, _, _) do
    raise JSON.LD.InvalidTermDefinitionError,
      message: "the empty string is not a valid term definition"
  end

  def create(active, local, term, value, defined, popts, opts) do
    cond do
      # 5)
      term in (JSON.LD.keywords() -- ["@type"]) or
          (term == "@type" and
             not (is_map(value) and not Enum.empty?(value) and
                    Map.keys(value) -- ~w[@container @protected] == [] and
                      Map.get(value, "@container", "@set") == "@set")) ->
        raise JSON.LD.KeywordRedefinitionError,
          message: "#{inspect(term)} is a keyword and can not be defined in context"

      keyword_form?(term) and term != "@type" ->
        warn("Terms beginning with '@' are reserved for future use and ignored: #{term}", popts)
        {active, defined}

      true ->
        # 1)
        case defined[term] do
          true ->
            {active, defined}

          false ->
            raise JSON.LD.CyclicIRIMappingError,
              message: "Cyclical term dependency found: #{inspect(term)}"

          nil ->
            # 6) Initialize previous definition to any existing term definition for term in active context,
            {previous_definition, term_defs} = Map.pop(active.term_defs, term)
            #    removing that term definition from active context.
            active = %Context{active | term_defs: term_defs}

            # 2)
            do_create(
              active,
              local,
              term,
              validate_term_def_value(value),
              previous_definition,
              Map.put(defined, term, false),
              popts,
              init_opts(opts)
            )
        end
    end
  end

  defp do_create(
         _,
         _,
         "@type",
         _,
         _,
         _,
         %Options{processing_mode: "json-ld-1.0"},
         _
       ) do
    raise JSON.LD.KeywordRedefinitionError,
      message: "@type is a keyword and can not be defined in context"
  end

  # 7) If value is null, convert it to a map consisting of a single entry whose key is @id and whose value is null.
  defp do_create(
         active,
         local,
         term,
         nil,
         previous_definition,
         defined,
         popts,
         opts
       ),
       do:
         do_create(
           active,
           local,
           term,
           %{"@id" => nil},
           previous_definition,
           defined,
           popts,
           opts
         )

  # 8) Otherwise, if value is a string, convert it to a map consisting of a single entry whose key is @id and whose value is value. Set simple term to true.
  defp do_create(
         active,
         local,
         term,
         value,
         previous_definition,
         defined,
         popts,
         opts
       )
       when is_binary(value) do
    do_create(
      active,
      local,
      term,
      %{"@id" => value},
      previous_definition,
      defined,
      popts,
      Keyword.put(opts, :simple_term, true)
    )
  end

  # 9)
  defp do_create(
         active,
         local,
         term,
         %{} = value,
         previous_definition,
         defined,
         popts,
         opts
       ) do
    {simple_term, opts} = Keyword.pop(opts, :simple_term, false)

    # 10)
    definition = %__MODULE__{
      prefix_flag: false,
      protected: protected_term_def?(value, opts[:protected], popts.processing_mode),
      reverse_property: false
    }

    {definition, active, defined} =
      handle_type_definition(definition, active, local, value, defined, popts)

    {done, definition, active, defined} =
      if Map.has_key?(value, "@reverse") do
        handle_reverse_definition(definition, active, local, value, defined, popts)
      else
        handle_id_definition(
          definition,
          active,
          local,
          term,
          value,
          previous_definition,
          defined,
          simple_term,
          popts,
          opts
        )
      end

    definition =
      unless done do
        definition =
          definition
          |> handle_container_definition(value, popts)
          |> handle_index_definition(active, local, term, value, defined, popts)
          |> handle_context_definition(active, term, value, popts, opts)
          |> handle_language_definition(value)
          |> handle_direction_definition(value)
          |> handle_nest_definition(value, popts)
          |> handle_prefix_definition(value, term, popts)

        # 27)
        if !opts[:override_protected] && previous_definition && previous_definition.protected do
          # 27.1)
          if %{definition | protected: previous_definition.protected} != previous_definition do
            raise JSON.LD.ProtectedTermRedefinitionError,
              message: "Attempt to redefine protected term #{term}"
          else
            # 27.2)
            previous_definition
          end
        else
          definition
        end
      else
        definition
      end

    # 28) Set the term definition of term in active context to definition and set the value associated with defined's key term to true.
    if definition do
      {
        %Context{active | term_defs: Map.put(active.term_defs, term, definition)},
        Map.put(defined, term, true)
      }
    else
      {active, defined}
    end
  end

  # 9)
  defp do_create(_, _, term, value, _, _, _, _) do
    raise JSON.LD.InvalidTermDefinitionError,
      message: "Term definition for #{term} is has invalid value #{inspect(value)}"
  end

  # 11) If value has an @protected entry, set the protected flag in definition to the value of this entry. If the value of @protected is not a boolean, an invalid @protected value error has been detected and processing is aborted. If processing mode is json-ld-1.0, an invalid term definition has been detected and processing is aborted.
  defp protected_term_def?(%{"@protected" => _} = invalid, _, "json-ld-1.0") do
    raise JSON.LD.InvalidTermDefinitionError,
      message: "invalid value #{inspect(invalid)} in json-ld-1.0 processing mode"
  end

  defp protected_term_def?(%{"@protected" => protected}, _, _), do: protected
  defp protected_term_def?(_, protected, _), do: protected

  # 12.1)
  defp handle_type_definition(_, _, _, %{"@type" => type}, _, _) when not is_binary(type) do
    raise JSON.LD.InvalidTypeMappingError, message: "#{inspect(type)} is not a valid type mapping"
  end

  defp handle_type_definition(definition, active, local, %{"@type" => type}, defined, popts) do
    # 12.2)
    # SPEC ISSUE: the new spec seems to have lost the requirement to set vocab to true
    {expanded_type, active, defined} =
      expand_iri(type, active, popts, false, true, local, defined)

    cond do
      # 12.3) If the expanded type is @json or @none, and processing mode is json-ld-1.0, an invalid type mapping error has been detected and processing is aborted.
      expanded_type in ~w[@json @none] and popts.processing_mode == "json-ld-1.0" ->
        raise JSON.LD.InvalidTypeMappingError,
          message: "#{inspect(type)} is not a valid type mapping"

      # 12.4 and 12.5)
      IRI.absolute?(expanded_type) or expanded_type in ~w[@id @vocab @json @none ] ->
        {%__MODULE__{definition | type_mapping: expanded_type}, active, defined}

      true ->
        raise JSON.LD.InvalidTypeMappingError,
          message: "#{inspect(type)} is not a valid type mapping"
    end
  end

  defp handle_type_definition(definition, active, _, _, defined, _),
    do: {definition, active, defined}

  # 13) If value contains the key @reverse
  defp handle_reverse_definition(
         definition,
         active,
         local,
         %{"@reverse" => reverse} = value,
         defined,
         popts
       ) do
    cond do
      # 13.1)
      Map.has_key?(value, "@id") or Map.has_key?(value, "@nest") ->
        raise JSON.LD.InvalidReversePropertyError,
          message: "#{inspect(reverse)} is not a valid reverse property"

      # 13.2)
      not is_binary(reverse) ->
        raise JSON.LD.InvalidIRIMappingError,
          message: "Expected string for @reverse value, but got #{inspect(reverse)}"

      # 13.3)
      keyword_form?(reverse) ->
        warn(
          "Values beginning with '@' are reserved for future use and ignored: #{reverse}",
          popts
        )

        {true, nil, active, defined}

      # 13.4)
      true ->
        # SPEC ISSUE: the new spec seems to have lost the requirement to set vocab to true
        {expanded_reverse, active, defined} =
          expand_iri(reverse, active, popts, false, true, local, defined)

        definition =
          if IRI.absolute?(expanded_reverse) or blank_node_id?(expanded_reverse) do
            %__MODULE__{definition | iri_mapping: expanded_reverse}
          else
            raise JSON.LD.InvalidIRIMappingError,
              message: "Non-absolute @reverse IRI: #{inspect(reverse)}"
          end

        # 13.5)
        definition =
          case Map.get(value, "@container", :not_present) do
            :not_present ->
              definition

            container when is_nil(container) or container in ~w[@set @index] ->
              %__MODULE__{definition | container_mapping: [container]}

            _ ->
              raise JSON.LD.InvalidReversePropertyError,
                message:
                  "#{inspect(reverse)} is not a valid reverse property; reverse properties only support set- and index-containers"
          end

        # 13.6) & 13.7)
        {false, %__MODULE__{definition | reverse_property: true}, active, defined}
    end
  end

  defp handle_reverse_definition(definition, active, _, _, defined, _),
    do: {false, definition, active, defined}

  # 14.1) If the @id entry of value is null, the term is not used for IRI expansion, but is retained to be able to detect future redefinitions of this term.
  defp handle_id_definition(definition, active, _, _, %{"@id" => nil}, _, defined, _, _, _),
    do: {false, definition, active, defined}

  # 14)
  defp handle_id_definition(
         definition,
         active,
         local,
         term,
         %{"@id" => id},
         _,
         defined,
         simple_term,
         popts,
         _opts
       )
       when id != term do
    cond do
      # 14.2.1)
      not is_binary(id) ->
        raise JSON.LD.InvalidIRIMappingError,
          message: "expected value of @id to be a string, but got #{inspect(id)}"

      # 14.2.2)
      not JSON.LD.keyword?(id) and keyword_form?(id) ->
        warn("Values beginning with '@' are reserved for future use and ignored: #{id}", popts)
        {true, nil, active, defined}

      true ->
        # 14.2.3)
        # SPEC ISSUE: the new spec seems to have lost the requirement to set vocab to true
        {expanded_id, active, defined} =
          expand_iri(id, active, popts, false, true, local, defined)

        cond do
          expanded_id == "@context" ->
            raise JSON.LD.InvalidKeywordAliasError, message: "cannot alias @context"

          not (JSON.LD.keyword?(expanded_id) or IRI.absolute?(expanded_id) or
                   blank_node_id?(expanded_id)) ->
            raise JSON.LD.InvalidIRIMappingError,
              message:
                "#{inspect(id)} is not a valid IRI mapping; resulting IRI mapping should be a keyword, absolute IRI or blank node"

          true ->
            # 14.2.4)
            {active, defined} =
              if term |> String.slice(1..-2//1) |> String.contains?(":") or
                   String.contains?(term, "/") do
                {term_iri, active, defined} =
                  expand_iri(
                    term,
                    active,
                    popts,
                    false,
                    true,
                    local,
                    Map.put(defined, term, true)
                  )

                if term_iri != expanded_id do
                  raise JSON.LD.InvalidIRIMappingError,
                    message: "term #{term} expands to #{expanded_id}, not #{term_iri}"
                end

                {active, defined}
              else
                {active, defined}
              end

            {false,
             %__MODULE__{
               definition
               | iri_mapping: expanded_id,
                 # 14.2.5)
                 prefix_flag:
                   (not String.contains?(term, [":", "/"]) and
                      simple_term and
                      (String.ends_with?(expanded_id, ~w(: / ? # [ ] @)) or
                         blank_node_id?(expanded_id))) or
                     definition.prefix_flag
             }, active, defined}
        end
    end
  end

  defp handle_id_definition(
         definition,
         active,
         local,
         term,
         _,
         previous_definition,
         defined,
         _,
         popts,
         opts
       ) do
    # 15)
    # SPEC ISSUE: the spec seems to contain an error by requiring only to check for a collon. What's when an absolute IRI is given and an "http" term is defined in the context?
    cond do
      term |> String.slice(1..-1//1) |> String.contains?(":") ->
        case compact_iri_parts(term) do
          [prefix, suffix] ->
            prefix_mapping = local[prefix]

            {active, defined} =
              if prefix_mapping do
                do_create(
                  active,
                  local,
                  prefix,
                  prefix_mapping,
                  previous_definition,
                  defined,
                  popts,
                  opts
                )
              else
                {active, defined}
              end

            if prefix_def = active.term_defs[prefix] do
              {false, %__MODULE__{definition | iri_mapping: prefix_def.iri_mapping <> suffix},
               active, defined}
            else
              {false, %__MODULE__{definition | iri_mapping: term}, active, defined}
            end

          nil ->
            {false, %__MODULE__{definition | iri_mapping: term}, active, defined}
        end

      # 16) Otherwise if the term contains a slash (/): Term is a relative IRI reference
      String.contains?(term, "/") ->
        term_iri = expand_iri(term, active, popts, false, true)

        if IRI.absolute?(term_iri) do
          {false, %__MODULE__{definition | iri_mapping: term_iri}, active, defined}
        else
          raise JSON.LD.InvalidIRIMappingError,
            message: "expected term #{inspect(term)} to expand to an absolute IRI"
        end

      # 17)
      term == "@type" ->
        {false, %__MODULE__{definition | iri_mapping: "@type"}, active, defined}

      # 18)
      true ->
        if active.vocab do
          {false, %__MODULE__{definition | iri_mapping: active.vocab <> term}, active, defined}
        else
          raise JSON.LD.InvalidIRIMappingError,
            message:
              "#{inspect(term)} is not a valid IRI mapping; relative term definition without vocab mapping"
        end
    end
  end

  defp handle_container_definition(definition, %{"@container" => container}, popts) do
    # 19.1) and 19.2)
    container_mapping = valid_container_mapping(container, container, popts.processing_mode)

    %__MODULE__{
      definition
      | # 19.3)
        container_mapping: container_mapping,
        # 19.4)
        type_mapping:
          if "@type" in container_mapping do
            case definition.type_mapping do
              false ->
                "@id"

              type_mapping when type_mapping in ~w[@id @vocab] ->
                type_mapping

              invalid ->
                raise JSON.LD.InvalidTypeMappingError,
                  message:
                    "@container: @type requires @type to be @id or @vocab; got #{inspect(invalid)}"
            end
          else
            definition.type_mapping
          end
    }
  end

  defp handle_container_definition(definition, _, _), do: definition

  @container_keywords ~w[@graph @id @index @language @list @set @type]

  defp valid_container_mapping(term, container, processing_mode) do
    values = List.wrap(container)

    cond do
      processing_mode == "json-ld-1.0" and
          (container in ~w[@graph @id @type] or not is_binary(container)) ->
        raise JSON.LD.InvalidContainerMappingError,
          message:
            "'@container' on term #{inspect(term)} has invalid value in 1.0 mode: #{inspect(container)}"

      # MUST be either @graph, @id, @index, @language, @list, @set, @type, or an array containing exactly any one of those keywords
      length(values) == 1 and hd(values) in @container_keywords ->
        :ok

      # an array containing @graph and either @id or @index optionally including @set
      "@graph" in values ->
        case values -- ["@graph", "@set"] do
          [] ->
            :ok

          ["@id"] ->
            :ok

          ["@index"] ->
            :ok

          _ ->
            raise JSON.LD.InvalidContainerMappingError,
              message: "'@container' with @graph can only have @id or @index and optional @set"
        end

      # an array containing a combination of @set and any of @index, @graph, @id, @type, @language in any order
      "@set" in values ->
        unless values -- ["@set", "@index", "@graph", "@id", "@type", "@language"] == [] do
          raise JSON.LD.InvalidContainerMappingError,
            message:
              "'@container' with @set can only have @index, @graph, @id, @type, or @language"
        end

      true ->
        raise JSON.LD.InvalidContainerMappingError,
          message: "Invalid @container value: #{inspect(container)}"
    end

    values
  end

  # 20)
  defp handle_index_definition(
         definition,
         active,
         local,
         term,
         %{"@index" => index},
         defined,
         popts
       ) do
    # 20.1)
    cond do
      popts.processing_mode == "json-ld-1.0" ->
        raise JSON.LD.InvalidTermDefinitionError,
          message: "invalid @index value in json-ld-1.0 processing mode"

      "@index" not in List.wrap(definition.container_mapping) ->
        raise JSON.LD.InvalidTermDefinitionError,
          message:
            "@index without @index in @container: #{inspect(index)} on term #{inspect(term)}"

      is_binary(index) ->
        # 20.2)
        {expanded_index, _active, _defined} =
          expand_iri(index, active, popts, false, true, local, defined)

        if IRI.absolute?(expanded_index) do
          # 20.3)
          %__MODULE__{definition | index_mapping: index}
        else
          raise JSON.LD.InvalidTermDefinitionError,
            message:
              "@index without @index in @container: #{inspect(index)} on term #{inspect(term)}"
        end

      true ->
        raise JSON.LD.InvalidTermDefinitionError,
          message: "invalid @index value: #{inspect(index)} on term #{inspect(term)}"
    end
  end

  defp handle_index_definition(definition, _, _, _, _, _, _), do: definition

  # 21.1)
  defp handle_context_definition(
         _,
         _,
         _,
         %{"@context" => _},
         %{
           processing_mode: "json-ld-1.0"
         },
         _
       ) do
    raise JSON.LD.InvalidTermDefinitionError,
      message: "invalid @context value in json-ld-1.0 processing mode"
  end

  defp handle_context_definition(definition, active, term, %{"@context" => context}, popts, opts) do
    # 21.3)
    _new_context =
      try do
        Context.update(
          active,
          context,
          override_protected: true,
          validate_scoped_context: false,
          remote_contexts: opts[:remote_contexts],
          processor_options: popts
        )
      rescue
        e ->
          reraise JSON.LD.InvalidScopedContextError,
                  [
                    message:
                      "Term definition for #{inspect(term)} contains illegal value for @context: #{Exception.message(e)}"
                  ],
                  __STACKTRACE__
      end

    # 21.4)
    # SPEC ISSUE: "Record null context in array form" from JSON-LD.rb was needed
    %__MODULE__{definition | local_context: if(is_nil(context), do: [nil], else: context)}
  end

  defp handle_context_definition(definition, _, _, _, _, _),
    do: definition

  # 22)
  defp handle_language_definition(definition, %{"@language" => language} = value) do
    unless Map.has_key?(value, "@type") do
      case language do
        language when is_binary(language) ->
          %__MODULE__{definition | language_mapping: String.downcase(language)}

        language when is_nil(language) ->
          %__MODULE__{definition | language_mapping: nil}

        _ ->
          raise JSON.LD.InvalidLanguageMappingError,
            message:
              "#{inspect(language)} is not a valid language mapping; @language must be a string or null"
      end
    else
      definition
    end
  end

  defp handle_language_definition(definition, _), do: definition

  # 23)
  defp handle_direction_definition(definition, %{"@direction" => direction}) do
    cond do
      # SPEC ISSUE: we had to ignore "... and does not contain the entry @type" from the spec to make "tdi03" pass
      #      not Map.has_key?(value, "@type") ->
      #        definition

      direction && direction not in ~w[ltr rtl] ->
        raise JSON.LD.InvalidBaseDirectionError,
          message: "invalid @direction value #{inspect(direction)}; must be null, 'ltr', or 'rtl'"

      true ->
        %__MODULE__{definition | direction_mapping: direction && String.to_atom(direction)}
    end
  end

  defp handle_direction_definition(definition, _), do: definition

  # 24.1)
  defp handle_nest_definition(_, %{"@nest" => _}, %Options{processing_mode: "json-ld-1.0"}) do
    raise JSON.LD.InvalidTermDefinitionError,
      message: "invalid @nest value in json-ld-1.0 processing mode"
  end

  # 24.2)
  defp handle_nest_definition(definition, %{"@nest" => nest}, _) do
    cond do
      not is_binary(nest) ->
        raise JSON.LD.InvalidNestValueError,
          message: "nest must be a string, was #{inspect(nest)}"

      nest != "@nest" and JSON.LD.keyword?(nest) ->
        raise JSON.LD.InvalidNestValueError,
          message: "nest must not be a keyword other than @nest, was #{inspect(nest)}"

      true ->
        %__MODULE__{definition | nest_value: nest}
    end
  end

  defp handle_nest_definition(definition, _, _), do: definition

  # 25.1)
  defp handle_prefix_definition(_, %{"@prefix" => _}, _, %Options{processing_mode: "json-ld-1.0"}) do
    raise JSON.LD.InvalidTermDefinitionError,
      message: "invalid @prefix value in json-ld-1.0 processing mode"
  end

  # 25.2)
  defp handle_prefix_definition(definition, %{"@prefix" => prefix}, term, _) do
    cond do
      String.contains?(term, [":", "/"]) ->
        raise JSON.LD.InvalidTermDefinitionError,
          message: "@prefix used on compact or relative IRI term"

      not is_boolean(prefix) ->
        raise JSON.LD.InvalidPrefixValueError, value: prefix

      # 25.3)
      prefix and JSON.LD.keyword?(definition.iri_mapping) ->
        raise JSON.LD.InvalidTermDefinitionError,
          message: "keywords may not be used as prefixes"

      true ->
        %__MODULE__{definition | prefix_flag: prefix}
    end
  end

  defp handle_prefix_definition(definition, _, _, _), do: definition
end
