defmodule JSON.LD.Context do
  @moduledoc """
  Implementation of the JSON-LD 1.1 _Context Processing Algorithm_.

  <https://www.w3.org/TR/json-ld11-api/#context-processing-algorithms>
  """

  import JSON.LD.{IRIExpansion, Utils}

  alias JSON.LD.Context.TermDefinition
  alias JSON.LD.Options

  alias RDF.IRI

  @type local :: map | String.t() | nil
  @type remote :: [map]

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
  @dialyzer {:nowarn_function, set_vocab: 3}
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

  defp create_term_definitions(active, local, opts, popts, defined \\ %{}) do
    {active, _} =
      Enum.reduce(local, {active, defined}, fn {term, value}, {active, defined} ->
        TermDefinition.create(active, local, term, value, defined, popts, opts)
      end)

    active
  end

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
