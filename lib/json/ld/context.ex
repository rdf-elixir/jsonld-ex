defmodule JSON.LD.Context do
  @moduledoc """
  Implementation of the JSON-LD 1.1 Context Processing Algorithm.

  <https://www.w3.org/TR/json-ld11-api/#context-processing-algorithms>
  """

  import JSON.LD.{IRIExpansion, Utils}

  alias JSON.LD.Context.TermDefinition
  alias JSON.LD.Options

  alias RDF.IRI

  @type local :: map | String.t() | nil
  @type remote :: [map]
  @type value :: map | String.t() | nil

  @type t :: %__MODULE__{
          term_defs: map,
          base_iri: String.t() | nil | :not_present,
          original_base_url: String.t() | nil,
          api_base_iri: String.t() | nil,
          inverse_context: map | nil,
          previous_context: t | nil,
          vocab: nil,
          default_language: String.t() | nil,
          base_direction: String.t() | nil
        }

  defstruct term_defs: %{},
            base_iri: :not_present,
            original_base_url: nil,
            # This is the base IRI set via options
            api_base_iri: nil,
            vocab: nil,
            default_language: nil,
            base_direction: nil,
            inverse_context: nil,
            previous_context: nil

  @max_contexts_loaded Application.compile_env(:json_ld, :max_contexts_loaded, 50)

  @spec base(t) :: String.t() | nil
  def base(%__MODULE__{base_iri: :not_present, api_base_iri: api_base_iri}),
    do: api_base_iri

  def base(%__MODULE__{base_iri: base_iri}),
    do: base_iri

  @spec language(t, String.t()) :: String.t() | nil
  def language(active, term) do
    case Map.get(active.term_defs, term, %TermDefinition{}).language_mapping do
      false -> active.default_language
      language -> language
    end
  end

  @spec new(Options.convertible()) :: t
  def new(options \\ %Options{}),
    do: %__MODULE__{api_base_iri: Options.new(options).base}

  @spec create(map, Options.convertible()) :: t
  def create(%{"@context" => json_ld_context}, options),
    do: options |> new() |> update(json_ld_context, options)

  defp init_options(options) do
    options
    # used to detect cyclical context inclusions
    |> Keyword.put_new(:remote_contexts, [])
    # used to allow changes to protected terms,
    |> Keyword.put_new(:override_protected, false)
    # to mark term definitions associated with non-propagated contexts
    |> Keyword.put_new(:propagate, true)
    #  used to limit recursion when validating possibly recursive scoped contexts..
    |> Keyword.put_new(:validate_scoped_context, true)
  end

  @spec update(t, [local] | local, Options.convertible()) :: t
  def update(active, local, options \\ []) do
    {processor_options, options} = Options.extract(options)
    update(active, local, init_options(options), processor_options)
  end

  @spec update(t, [local] | local, keyword, Options.convertible()) :: t
  def update(%__MODULE__{} = active, local, options, processor_options) when is_list(local) do
    # 1) Initialize result to the result of cloning active context, with inverse context set to null
    result = %{active | inverse_context: nil}

    # 3) If propagate is false, and result does not have a previous context, set previous context in result to active context
    result =
      if options[:propagate] == false && is_nil(active.previous_context) do
        %{result | previous_context: active}
      else
        result
      end

    {remote, options} = options |> init_options() |> Keyword.pop(:remote_contexts)
    # 5) For each item context in local context
    Enum.reduce(local, result, fn context, result ->
      do_update(result, context, remote, options, processor_options)
    end)
  end

  # 2) If local context has a @propagate entry, its value MUST be boolean true or false, set propagate to that value
  def update(
        %__MODULE__{} = active,
        %{"@propagate" => propagate} = local,
        options,
        processor_options
      ) do
    # 4) If local context is not an array, set it to an array containing only local context.
    update(active, [local], Keyword.put(options, :propagate, propagate), processor_options)
  end

  # 4) If local context is not an array, set it to an array containing only local context.
  def update(%__MODULE__{} = active, local, options, processor_options),
    do: update(active, [local], options, processor_options)

  # 5.1) If context is null
  @spec do_update(t, local, remote, keyword, Options.t()) :: t
  defp do_update(%__MODULE__{} = active, nil, _, options, processor_options) do
    # 5.1.1) If override protected is false and active context contains any protected term definitions, an invalid context nullification has been detected and processing is aborted.

    if not options[:override_protected] and
         active.term_defs |> Map.values() |> Enum.any?(& &1.protected) do
      raise JSON.LD.InvalidContextNullificationError, message: "invalid context nullification"
    else
      # 5.1.2) Initialize result as a newly-initialized active context, setting both base IRI and original base URL to the value of original base URL in active context, and, if propagate is false, previous context in result to the previous value of result.
      %{
        new(processor_options)
        | base_iri: active.original_base_url || :not_present,
          original_base_url: active.original_base_url,
          previous_context: if(!options[:propagate], do: active)
      }
    end
  end

  # 5.2) If context is a string
  defp do_update(%__MODULE__{} = active, context, remote, options, processor_options)
       when is_binary(context) do
    # 5.2.1) Initialize context to the result of resolving context against base URL. If base URL is not a valid IRI, then context MUST be a valid IRI, otherwise a loading document failed error has been detected and processing is aborted.
    context = absolute_iri(context, base(active))

    # 5.2.2) If validate scoped context is false, and remote contexts already includes context do not process context further and continue to any next context in local context.
    if not options[:validate_scoped_context] and context in remote do
      context
    else
      # 5.2.3) If the number of entries in the remote contexts array exceeds a processor defined limit, a context overflow error has been detected and processing is aborted;
      if length(remote) > @max_contexts_loaded do
        raise JSON.LD.ContextOverflowError, message: "context overflow: #{context}"
      end

      # 5.2.3) otherwise, add context to remote contexts.
      remote = [context | remote]

      # 5.2.5)
      {loaded_context, _document_url} = dereference_context(context, processor_options)

      # 5.2.6)
      update(
        active,
        loaded_context,
        Keyword.put(options, :remote_contexts, remote),
        processor_options
      )
    end
  end

  # 5.4) Otherwise, context is a context definition
  defp do_update(%__MODULE__{} = active, local, remote, options, processor_options)
       when is_map(local) do
    {import_ctx, local} = Map.pop(local, "@import", :not_present)
    local = process_import(import_ctx, local, active, processor_options)

    {version, local} = Map.pop(local, "@version", :not_present)
    {base, local} = Map.pop(local, "@base", :not_present)
    {vocab, local} = Map.pop(local, "@vocab", :not_present)
    {language, local} = Map.pop(local, "@language", :not_present)
    {direction, local} = Map.pop(local, "@direction", :not_present)
    {propagate, local} = Map.pop(local, "@propagate", :not_present)
    {protected, local} = Map.pop(local, "@protected", false)

    active
    |> check_version(version, processor_options.processing_mode)
    |> set_base(base, remote)
    |> set_vocab(vocab, processor_options)
    |> set_language(language)
    |> set_direction(direction, processor_options.processing_mode)
    |> validate_propagate(propagate, processor_options.processing_mode)
    |> create_term_definitions(
      local,
      options
      |> Keyword.put(:protected, protected)
      |> Keyword.put(:remote_contexts, remote),
      processor_options
    )
  end

  # 5.3) If context is not a map, an invalid local context error has been detected and processing is aborted.
  defp do_update(_, context, _, _, _) do
    raise JSON.LD.InvalidLocalContextError,
      message: "#{inspect(context)} is not a valid @context value"
  end

  defp dereference_import(url, options) do
    # 5.6.4) (5.6.5 and 5.6.6 is done as part of dereference_context)
    {document, _url} = dereference_context(url, options)

    case document do
      # 5.6.7)
      %{"@import" => _} ->
        raise JSON.LD.InvalidContextEntryError,
          message: "#{inspect(document)} must not include @import entry"

      document ->
        document
    end
  end

  defp dereference_context(context_url, options) do
    document_loader = Options.document_loader(options)

    {document, url} =
      case document_loader.load(context_url, options) do
        {:ok, result} ->
          {result.document, result.document_url}

        {:error, reason} ->
          raise JSON.LD.LoadingRemoteContextFailedError,
            message: "Could not load remote context (#{context_url}): #{inspect(reason)}"
      end

    document =
      cond do
        is_map(document) ->
          document

        is_binary(document) ->
          case Jason.decode(document) do
            {:ok, result} ->
              result

            {:error, reason} ->
              raise JSON.LD.InvalidRemoteContextError,
                message: "Context is not a valid JSON document: #{inspect(reason)}"
          end

        true ->
          raise JSON.LD.InvalidRemoteContextError,
            message: "Context is not a valid JSON object: #{inspect(document)}"
      end

    {
      document["@context"] ||
        raise(JSON.LD.InvalidRemoteContextError,
          message: "Invalid remote context: No @context key in #{inspect(document)}"
        ),
      url
    }
  end

  defp check_version(active, :not_present, _), do: active

  # 5.5.2) If processing mode is set to json-ld-1.0, a processing mode conflict error has been detected and processing is aborted.
  defp check_version(_, 1.1, "json-ld-1.0") do
    raise JSON.LD.ProcessingModeConflictError, message: "processing mode conflict"
  end

  defp check_version(active, 1.1, _), do: active

  # 5.5.1) If the associated value is not 1.1, an invalid @version value has been detected, and processing is aborted.
  defp check_version(_, invalid, _) do
    raise JSON.LD.InvalidVersionValueError.exception(value: invalid)
  end

  defp process_import(:not_present, context, _, _), do: context

  # 5.6.1) If processing mode is json-ld-1.0, an invalid context entry error has been detected and processing is aborted.
  defp process_import(import, _, _, %Options{processing_mode: "json-ld-1.0"}) do
    raise JSON.LD.InvalidContextEntryError,
      message: "invalid context entry: @import with value #{inspect(import)}"
  end

  # 5.6.2) Otherwise, if the value of @import is not a string, an invalid @import value error has been detected and processing is aborted.
  defp process_import(import, _, _, _) when not is_binary(import) do
    raise JSON.LD.InvalidImportValueError, value: import
  end

  defp process_import(import, context, active, options) do
    import
    # 5.6.3) Initialize import to the result of resolving the value of @import against base URL.
    |> absolute_iri(base(active))
    # 5.6.4) Dereference import using the LoadDocumentCallback, passing import for url, and http://www.w3.org/ns/json-ld#context for profile and for requestProfile.
    |> dereference_import(options)
    |> case do
      # 5.6.8) Set context to the result of merging context into import context, replacing common entries with those from context.
      %{} = import_context ->
        Map.merge(import_context, context)

      invalid ->
        raise JSON.LD.InvalidRemoteContextError,
          message: "Context is not a valid JSON document: #{inspect(invalid)}"
    end
  end

  # 5.7)
  defp set_base(active, :not_present, _), do: active

  defp set_base(active, _, remote) when is_list(remote) and length(remote) > 0,
    do: active

  defp set_base(active, nil, _), do: %__MODULE__{active | base_iri: nil}

  defp set_base(active, base, _) when is_binary(base) do
    cond do
      IRI.absolute?(base) ->
        %__MODULE__{active | base_iri: base}

      active_base = base(active) ->
        %__MODULE__{active | base_iri: absolute_iri(base, active_base)}

      true ->
        raise JSON.LD.InvalidBaseIRIError,
          message: "#{inspect(base)} is a relative IRI, but no active base IRI defined"
    end
  end

  defp set_base(_, invalid, _) do
    raise JSON.LD.InvalidBaseIRIError, message: "#{inspect(invalid)} is not a valid base IRI"
  end

  defp set_vocab(active, :not_present, _), do: active

  # 5.8.2) If value is null, remove any vocabulary mapping from result.
  defp set_vocab(active, nil, _), do: %__MODULE__{active | vocab: nil}

  # 5.8.3) Otherwise, if value is an IRI or blank node identifier, the vocabulary mapping of result is set to the result of IRI expanding value using true for document relative.
  defp set_vocab(active, vocab, options) do
    cond do
      # Note: The use of blank node identifiers to value for @vocab is obsolete, and may be removed in a future version of JSON-LD.
      blank_node_id?(vocab) ->
        %__MODULE__{active | vocab: vocab}

      not IRI.absolute?(vocab) and options.processing_mode == "json-ld-1.0" ->
        raise JSON.LD.InvalidVocabMappingError,
          message: "@vocab must be an absolute IRI in 1.0 mode: #{inspect(vocab)}"

      is_binary(vocab) ->
        # SPEC ISSUE: vocab must be set to true
        %__MODULE__{active | vocab: expand_iri(vocab, active, options, true, true)}

      true ->
        raise JSON.LD.InvalidVocabMappingError,
          message: "#{inspect(vocab)} is not a valid vocabulary mapping"
    end
  end

  defp set_language(active, :not_present), do: active

  # 5.9.2) If value is null, remove any default language from result.
  defp set_language(active, nil), do: %__MODULE__{active | default_language: nil}

  # 5.9.3) Otherwise, if value is a string, the default language of result is set to value.
  # Note: Processors MAY normalize language tags to lower case.
  defp set_language(active, language) when is_binary(language),
    do: %__MODULE__{active | default_language: String.downcase(language)}

  # 5.9.3) If it is not a string, an invalid default language error has been detected and processing is aborted.
  defp set_language(_, language) do
    raise JSON.LD.InvalidDefaultLanguageError,
      message: "#{inspect(language)} is not a valid language"
  end

  defp set_direction(active, :not_present, _), do: active

  # 5.10.1) If processing mode is json-ld-1.0, an invalid context entry error has been detected and processing is aborted.
  defp set_direction(_, direction, "json-ld-1.0") do
    raise JSON.LD.InvalidContextEntryError,
      message: "invalid context entry: @direction with value #{inspect(direction)}"
  end

  # 5.10.3) If value is null, remove any default language from result.
  defp set_direction(active, nil, _), do: %__MODULE__{active | base_direction: nil}

  # 5.10.4) Otherwise, if value is a string, the base direction of result is set to value. If it is not null, "ltr", or "rtl", an invalid base direction error has been detected and processing is aborted.
  defp set_direction(active, direction, _) when direction in ~w[ltr rtl],
    do: %__MODULE__{active | base_direction: String.to_atom(direction)}

  # 5.9.3) If it is not a string, an invalid default language error has been detected and processing is aborted.
  defp set_direction(_, direction, _) do
    raise JSON.LD.InvalidBaseDirectionError,
      message: "invalid @direction value #{inspect(direction)}; must be 'ltr' or 'rtl'"
  end

  defp validate_propagate(active, :not_present, _), do: active

  # 5.11.1) If processing mode is json-ld-1.0, an invalid context entry error has been detected and processing is aborted.
  defp validate_propagate(_, propagate, "json-ld-1.0") do
    raise JSON.LD.InvalidContextEntryError,
      message: "invalid context entry: @propagate with value #{inspect(propagate)}"
  end

  # 5.11.2) Otherwise, if the value of @propagate is not boolean true or false, an invalid @propagate value error has been detected and processing is aborted.
  defp validate_propagate(_, propagate, _) when not is_boolean(propagate) do
    raise JSON.LD.InvalidPropagateValueError.exception(value: propagate)
  end

  # Note: The previous context is actually set earlier in this algorithm (step 2 and 3)
  defp validate_propagate(active, _, _), do: active

  defp create_term_definitions(active, local, opts, processing_options, defined \\ %{}) do
    {active, _} =
      Enum.reduce(local, {active, defined}, fn {term, value}, {active, defined} ->
        create_term_definition(active, local, term, value, defined, processing_options, opts)
      end)

    active
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

  defp init_term_definition_opts(opts) do
    opts
    # base_url is provided via Options.api_base_url
    |> Keyword.put_new(:protected, false)
    |> Keyword.put_new(:override_protected, false)
    |> Keyword.put_new(:remote_contexts, [])
    |> Keyword.put_new(:validate_scoped_context, true)
  end

  @doc """
  Expands the given input according to the steps in the JSON-LD _Create Term Definition_ Algorithm.

  see <https://www.w3.org/TR/json-ld11-api/#create-term-definition>
  """
  @spec create_term_definition(t, map, String.t(), value, map, Options.t(), keyword) :: {t, map}
  def create_term_definition(active, local, term, value, defined, popts, opts \\ [])

  # 2)
  def create_term_definition(_, _, "", _, _, _, _) do
    raise JSON.LD.InvalidTermDefinitionError,
      message: "the empty string is not a valid term definition"
  end

  def create_term_definition(active, local, term, value, defined, popts, opts) do
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
            active = %__MODULE__{active | term_defs: term_defs}

            # 2)
            do_create_term_definition(
              active,
              local,
              term,
              validate_term_def_value(value),
              previous_definition,
              Map.put(defined, term, false),
              popts,
              init_term_definition_opts(opts)
            )
        end
    end
  end

  defp do_create_term_definition(
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
  defp do_create_term_definition(
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
         do_create_term_definition(
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
  defp do_create_term_definition(
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
    do_create_term_definition(
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
  defp do_create_term_definition(
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
    definition = %TermDefinition{
      prefix_flag: false,
      protected: protected_term_def?(value, opts[:protected], popts.processing_mode),
      reverse_property: false
    }

    {definition, active, defined} =
      handle_type_definition(definition, active, local, value, defined, popts)

    {done, definition, active, defined} =
      handle_reverse_definition(definition, active, local, value, defined, popts)

    {done, definition, active, defined} =
      unless done do
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
      else
        {done, definition, active, defined}
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
        %__MODULE__{active | term_defs: Map.put(active.term_defs, term, definition)},
        Map.put(defined, term, true)
      }
    else
      {active, defined}
    end
  end

  # 9)
  defp do_create_term_definition(_, _, term, value, _, _, _, _) do
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
        {%TermDefinition{definition | type_mapping: expanded_type}, active, defined}

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
            %TermDefinition{definition | iri_mapping: expanded_reverse}
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
              %TermDefinition{definition | container_mapping: [container]}

            _ ->
              raise JSON.LD.InvalidReversePropertyError,
                message:
                  "#{inspect(reverse)} is not a valid reverse property; reverse properties only support set- and index-containers"
          end

        # 13.6) & 13.7)
        {true, %TermDefinition{definition | reverse_property: true}, active, defined}
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
             %TermDefinition{
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
                do_create_term_definition(
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
              {false, %TermDefinition{definition | iri_mapping: prefix_def.iri_mapping <> suffix},
               active, defined}
            else
              {false, %TermDefinition{definition | iri_mapping: term}, active, defined}
            end

          nil ->
            {false, %TermDefinition{definition | iri_mapping: term}, active, defined}
        end

      # 16) Otherwise if the term contains a slash (/): Term is a relative IRI reference
      String.contains?(term, "/") ->
        term_iri = expand_iri(term, active, popts, false, true)

        if IRI.absolute?(term_iri) do
          {false, %TermDefinition{definition | iri_mapping: term_iri}, active, defined}
        else
          raise JSON.LD.InvalidIRIMappingError,
            message: "expected term #{inspect(term)} to expand to an absolute IRI"
        end

      # 17)
      term == "@type" ->
        {false, %TermDefinition{definition | iri_mapping: "@type"}, active, defined}

      # 18)
      true ->
        if active.vocab do
          {false, %TermDefinition{definition | iri_mapping: active.vocab <> term}, active,
           defined}
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

    %TermDefinition{
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
          %TermDefinition{definition | index_mapping: index}
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
        update(
          active,
          context,
          [
            override_protected: true,
            validate_scoped_context: false,
            remote_contexts: opts[:remote_contexts]
          ],
          popts
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
    %TermDefinition{definition | context: if(is_nil(context), do: [nil], else: context)}
  end

  defp handle_context_definition(definition, _, _, _, _, _),
    do: definition

  # 22)
  defp handle_language_definition(definition, %{"@language" => language} = value) do
    unless Map.has_key?(value, "@type") do
      case language do
        language when is_binary(language) ->
          %TermDefinition{definition | language_mapping: String.downcase(language)}

        language when is_nil(language) ->
          %TermDefinition{definition | language_mapping: nil}

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
        %TermDefinition{definition | direction_mapping: direction && String.to_atom(direction)}
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
        %TermDefinition{definition | nest_value: nest}
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
        %TermDefinition{definition | prefix_flag: prefix}
    end
  end

  defp handle_prefix_definition(definition, _, _, _), do: definition

  @doc """
  Inverse Context Creation algorithm

  See <https://www.w3.org/TR/json-ld11-api/#inverse-context-creation>
  """
  @spec inverse(t) :: map
  def inverse(%__MODULE__{} = context) do
    # 2) Initialize default language to @none. If the active context has a default language, set default language to the default language from the active context normalized to lower case.
    default_language =
      (context.default_language && String.downcase(context.default_language)) || "@none"

    # 3) For each key term and value term definition in the active context:
    context.term_defs
    #    ordered by shortest term first (breaking ties by choosing the lexicographically least term)
    |> Enum.sort(fn {term1, _}, {term2, _} ->
      case {String.length(term1), String.length(term2)} do
        {length, length} -> term1 < term2
        {length1, length2} -> length1 < length2
      end
    end)
    |> Enum.reduce(%{}, fn {term, term_def}, result ->
      # 3.1) If the term definition is null, term cannot be selected during compaction, so continue to the next term.
      if term_def do
        # 3.2) Initialize container to @none. If the container mapping is not empty, set container to the concatenation of all values of the container mapping in lexicographical order.
        container =
          if term_def.container_mapping && !Enum.empty?(term_def.container_mapping) do
            term_def.container_mapping |> Enum.sort() |> Enum.join()
          else
            "@none"
          end

        # 3.3) Initialize var to the value of the IRI mapping for the term definition.
        var = term_def.iri_mapping

        type_map = get_in(result, [var, container, "@type"]) || %{}
        language_map = get_in(result, [var, container, "@language"]) || %{}
        any_map = get_in(result, [var, container, "@any"]) || %{"@none" => term}

        {type_map, language_map} =
          case term_def do
            # 3.10) If the term definition indicates that the term represents a reverse property
            %TermDefinition{reverse_property: true} ->
              {Map.put_new(type_map, "@reverse", term), language_map}

            # 3.11) Otherwise, if term definition has a type mapping which is @none
            %TermDefinition{type_mapping: "@none"} ->
              {
                Map.put_new(type_map, "@any", term),
                Map.put_new(language_map, "@any", term)
              }

            # 3.12) Otherwise, if term definition has a type mapping
            %TermDefinition{type_mapping: type_mapping} when type_mapping != false ->
              {Map.put_new(type_map, type_mapping, term), language_map}

            # 3.13) Otherwise, if term definition has both a language mapping and a direction mapping:
            %TermDefinition{
              language_mapping: language_mapping,
              direction_mapping: direction_mapping
            }
            when language_mapping != false and direction_mapping != false ->
              lang_dir =
                case {language_mapping, direction_mapping} do
                  {nil, nil} -> "@null"
                  {language_mapping, nil} -> String.downcase(language_mapping)
                  _ -> String.downcase("#{language_mapping}_#{direction_mapping}")
                end

              {type_map, Map.put_new(language_map, lang_dir, term)}

            # 3.14) Otherwise, if term definition has a language mapping (might be null)
            %TermDefinition{language_mapping: language_mapping} when language_mapping != false ->
              language = (language_mapping && String.downcase(language_mapping)) || "@null"
              {type_map, Map.put_new(language_map, language, term)}

            # 3.15) Otherwise, if term definition has a direction mapping (might be null)
            %TermDefinition{direction_mapping: direction_mapping} when direction_mapping != false ->
              direction = (direction_mapping && "_#{direction_mapping}") || "@none"
              {type_map, Map.put_new(language_map, direction, term)}

            _ ->
              # 3.16) Otherwise, if active context has a default base direction
              if context.base_direction do
                lang_dir = String.downcase("#{default_language}_#{context.base_direction}")

                {
                  Map.put_new(type_map, "@none", term),
                  language_map
                  |> Map.put_new(lang_dir, term)
                  |> Map.put_new("@none", term)
                }
              else
                # 3.17) Otherwise
                {
                  Map.put_new(type_map, "@none", term),
                  language_map
                  |> Map.put_new(default_language, term)
                  |> Map.put_new("@none", term)
                }
              end
          end

        result
        |> Map.put_new(var, %{})
        |> Map.update(var, %{}, fn container_map ->
          Map.put(container_map, container, %{
            "@type" => type_map,
            "@language" => language_map,
            "@any" => any_map
          })
        end)
      else
        result
      end
    end)
  end

  @spec set_inverse(t) :: t
  def set_inverse(%__MODULE__{inverse_context: nil} = context) do
    %__MODULE__{context | inverse_context: inverse(context)}
  end

  def set_inverse(%__MODULE__{} = context), do: context

  @spec empty?(t) :: boolean
  def empty?(%__MODULE__{
        term_defs: term_defs,
        vocab: nil,
        base_iri: :not_present,
        default_language: nil
      })
      when map_size(term_defs) == 0,
      do: true

  def empty?(_),
    do: false
end
