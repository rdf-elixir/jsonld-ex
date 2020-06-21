defmodule JSON.LD.Context do
  import JSON.LD.{IRIExpansion, Utils}

  alias JSON.LD.Context.TermDefinition
  alias JSON.LD.Options

  alias RDF.IRI

  @type local :: map | String.t() | nil
  @type remote :: [map]
  @type value :: map | String.t() | nil

  @type t :: %__MODULE__{
          term_defs: map,
          default_language: String.t() | nil,
          vocab: nil,
          base_iri: String.t() | boolean | nil,
          api_base_iri: String.t() | nil
        }

  defstruct term_defs: %{},
            default_language: nil,
            vocab: nil,
            base_iri: false,
            api_base_iri: nil

  @spec base(t) :: String.t() | nil
  def base(%__MODULE__{base_iri: false, api_base_iri: api_base_iri}),
    do: api_base_iri

  def base(%__MODULE__{base_iri: base_iri}),
    do: base_iri

  @spec new(Options.t()) :: t
  def new(options \\ %Options{}),
    do: %__MODULE__{api_base_iri: Options.new(options).base}

  @spec create(map, Options.t()) :: t
  def create(%{"@context" => json_ld_context}, options),
    do: options |> new() |> update(json_ld_context, [], options)

  @spec update(t, [local] | local, remote, Options.t()) :: t
  def update(active, local, remote \\ [], options \\ %Options{})

  def update(%__MODULE__{} = active, local, remote, options) when is_list(local) do
    Enum.reduce(local, active, fn local, result ->
      do_update(result, local, remote, options)
    end)
  end

  # 2) If local context is not an array, set it to an array containing only local context.
  def update(%__MODULE__{} = active, local, remote, options),
    do: update(active, [local], remote, options)

  # 3.1) If context is null, set result to a newly-initialized active context and continue with the next context. The base IRI of the active context is set to the IRI of the currently being processed document (which might be different from the currently being processed context), if available; otherwise to null. If set, the base option of a JSON-LD API Implementation overrides the base IRI.
  @spec do_update(t, local, remote, Options.t()) :: t
  defp do_update(%__MODULE__{}, nil, _remote, options),
    do: new(options)

  # 3.2) If context is a string, [it's interpreted as a remote context]
  defp do_update(%__MODULE__{} = active, local, remote, options) when is_binary(local) do
    # 3.2.1)
    local = absolute_iri(local, base(active))

    # 3.2.2)
    if local in remote do
      raise JSON.LD.RecursiveContextInclusionError,
        message: "Recursive context inclusion: #{local}"
    end

    remote = remote ++ [local]

    # 3.2.3)
    document_loader = options.document_loader || JSON.LD.DocumentLoader.Default

    document =
      case apply(document_loader, :load, [local, options]) do
        {:ok, result} ->
          result.document

        {:error, reason} ->
          raise JSON.LD.LoadingRemoteContextFailedError,
            message: "Could not load remote context (#{local}): #{inspect(reason)}"
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

    local =
      document["@context"] ||
        raise JSON.LD.InvalidRemoteContextError,
          message: "Invalid remote context: No @context key in #{inspect(document)}"

    # 3.2.4) - 3.2.5)
    do_update(active, local, remote, options)
  end

  # 3.4) - 3.8)
  defp do_update(%__MODULE__{} = active, local, remote, _) when is_map(local) do
    with {base, local} <- Map.pop(local, "@base", false),
         {vocab, local} <- Map.pop(local, "@vocab", false),
         {language, local} <- Map.pop(local, "@language", false) do
      active
      |> set_base(base, remote)
      |> set_vocab(vocab)
      |> set_language(language)
      |> create_term_definitions(local)
    end
  end

  # 3.3) If context is not a JSON object, an invalid local context error has been detected and processing is aborted.
  defp do_update(_, local, _, _) do
    raise JSON.LD.InvalidLocalContextError,
      message: "#{inspect(local)} is not a valid @context value"
  end

  @spec set_base(t, boolean, remote) :: t
  defp set_base(active, false, _),
    do: active

  defp set_base(active, _, remote) when is_list(remote) and length(remote) > 0,
    do: active

  defp set_base(active, base, _) do
    cond do
      # TODO: this slightly differs from the spec, due to our false special value for base_iri; add more tests
      is_nil(base) or IRI.absolute?(base) ->
        %__MODULE__{active | base_iri: base}

      active.base_iri ->
        %__MODULE__{active | base_iri: absolute_iri(base, active.base_iri)}

      true ->
        raise JSON.LD.InvalidBaseIRIError,
          message: "#{inspect(base)} is a relative IRI, but no active base IRI defined"
    end
  end

  @spec set_vocab(t, boolean | nil) :: t
  defp set_vocab(active, false), do: active

  defp set_vocab(active, vocab) do
    if is_nil(vocab) or IRI.absolute?(vocab) or blank_node_id?(vocab) do
      %__MODULE__{active | vocab: vocab}
    else
      raise JSON.LD.InvalidVocabMappingError,
        message: "#{inspect(vocab)} is not a valid vocabulary mapping"
    end
  end

  @spec set_language(t, boolean | nil) :: t
  defp set_language(active, false), do: active

  defp set_language(active, nil),
    do: %__MODULE__{active | default_language: nil}

  defp set_language(active, language) when is_binary(language),
    do: %__MODULE__{active | default_language: String.downcase(language)}

  defp set_language(_, language) do
    raise JSON.LD.InvalidDefaultLanguageError,
      message: "#{inspect(language)} is not a valid language"
  end

  @spec language(t, String.t()) :: String.t() | nil
  def language(active, term) do
    case Map.get(active.term_defs, term, %TermDefinition{}).language_mapping do
      false -> active.default_language
      language -> language
    end
  end

  @spec create_term_definitions(t, map, map) :: t
  defp create_term_definitions(active, local, defined \\ %{}) do
    {active, _} =
      Enum.reduce(local, {active, defined}, fn {term, value}, {active, defined} ->
        create_term_definition(active, local, term, value, defined)
      end)

    active
  end

  @doc """
  Expands the given input according to the steps in the JSON-LD Create Term Definition Algorithm.

  see <https://www.w3.org/TR/json-ld-api/#create-term-definition>
  """
  @spec create_term_definition(t, map, String.t(), value, map) :: {t, map}
  def create_term_definition(active, local, term, value, defined)

  def create_term_definition(active, _, "@base", _, defined), do: {active, defined}
  def create_term_definition(active, _, "@vocab", _, defined), do: {active, defined}
  def create_term_definition(active, _, "@language", _, defined), do: {active, defined}

  def create_term_definition(active, local, term, value, defined) do
    # 3)
    if term in JSON.LD.keywords() do
      raise JSON.LD.KeywordRedefinitionError,
        message: "#{inspect(term)} is a keyword and can not be defined in context"
    end

    # 1)
    case defined[term] do
      true ->
        {active, defined}

      # , message: "#{inspect term} .."
      false ->
        raise JSON.LD.CyclicIRIMappingError

      nil ->
        # 2)
        do_create_term_definition(active, local, term, value, Map.put(defined, term, false))
    end
  end

  @spec do_create_term_definition(t, map, String.t(), value, map) :: {t, map}
  defp do_create_term_definition(active, _local, term, nil, defined) do
    {
      # (if Map.has_key?(active.term_defs, term),
      #   do: put_in(active, [:term_defs, term], nil),
      #   else: raise "NotImplemented"),
      %__MODULE__{active | term_defs: Map.put(active.term_defs, term, nil)},
      Map.put(defined, term, true)
    }
  end

  defp do_create_term_definition(active, local, term, %{"@id" => nil}, defined),
    do: do_create_term_definition(active, local, term, nil, defined)

  defp do_create_term_definition(active, local, term, value, defined) when is_binary(value),
    do: do_create_term_definition(active, local, term, %{"@id" => value}, defined)

  defp do_create_term_definition(active, local, term, %{} = value, defined) do
    # 9)
    definition = %TermDefinition{}

    {definition, active, defined} =
      do_create_type_definition(definition, active, local, value, defined)

    {done, definition, active, defined} =
      do_create_reverse_definition(definition, active, local, value, defined)

    {definition, active, defined} =
      unless done do
        {definition, active, defined} =
          do_create_id_definition(definition, active, local, term, value, defined)

        definition = do_create_container_definition(definition, value)
        definition = do_create_language_definition(definition, value)

        {definition, active, defined}
      else
        {definition, active, defined}
      end

    # 18 / 11.6) Set the term definition of term in active context to definition and set the value associated with defined's key term to true.
    {
      %__MODULE__{active | term_defs: Map.put(active.term_defs, term, definition)},
      Map.put(defined, term, true)
    }
  end

  defp do_create_term_definition(_, _, _, value, _) do
    raise JSON.LD.InvalidTermDefinitionError,
      message: "#{inspect(value)} is not a valid term definition"
  end

  # 10.1)
  # TODO: RDF.rb implementation says: "SPEC FIXME: @type may be nil"
  @spec do_create_type_definition(TermDefinition.t(), map, map, value, map) ::
          {TermDefinition.t(), t, map}
  defp do_create_type_definition(_, _, _, %{"@type" => type}, _) when not is_binary(type) do
    raise JSON.LD.InvalidTypeMappingError, message: "#{inspect(type)} is not a valid type mapping"
  end

  # 10.2) and 10.3)
  defp do_create_type_definition(definition, active, local, %{"@type" => type}, defined) do
    {expanded_type, active, defined} = expand_iri(type, active, false, true, local, defined)

    if IRI.absolute?(expanded_type) or expanded_type in ~w[@id @vocab] do
      {%TermDefinition{definition | type_mapping: expanded_type}, active, defined}
    else
      raise JSON.LD.InvalidTypeMappingError,
        message: "#{inspect(type)} is not a valid type mapping"
    end
  end

  defp do_create_type_definition(definition, active, _, _, defined),
    do: {definition, active, defined}

  @spec do_create_reverse_definition(TermDefinition.t(), t, map, value, map) ::
          {boolean, TermDefinition.t(), t, map}
  # 11) If value contains the key @reverse
  defp do_create_reverse_definition(
         definition,
         active,
         local,
         %{"@reverse" => reverse} = value,
         defined
       ) do
    cond do
      # 11.1)
      Map.has_key?(value, "@id") ->
        raise JSON.LD.InvalidReversePropertyError,
          message: "#{inspect(reverse)} is not a valid reverse property"

      # 11.2)
      not is_binary(reverse) ->
        raise JSON.LD.InvalidIRIMappingError,
          message: "Expected String for @reverse value. got #{inspect(reverse)}"

      # 11.3)
      true ->
        {expanded_reverse, active, defined} =
          expand_iri(reverse, active, false, true, local, defined)

        definition =
          if IRI.absolute?(expanded_reverse) or blank_node_id?(expanded_reverse) do
            %TermDefinition{definition | iri_mapping: expanded_reverse}
          else
            raise JSON.LD.InvalidIRIMappingError,
              message: "Non-absolute @reverse IRI: #{inspect(reverse)}"
          end

        # 11.4)
        definition =
          case Map.get(value, "@container", {false}) do
            {false} ->
              definition

            container when is_nil(container) or container in ~w[@set @index] ->
              %TermDefinition{definition | container_mapping: container}

            _ ->
              raise JSON.LD.InvalidReversePropertyError,
                message:
                  "#{inspect(reverse)} is not a valid reverse property; reverse properties only support set- and index-containers"
          end

        # 11.5) & 11.6)
        {true, %TermDefinition{definition | reverse_property: true}, active, defined}
    end
  end

  defp do_create_reverse_definition(definition, active, _, _, defined),
    do: {false, definition, active, defined}

  # 13)
  @spec do_create_id_definition(TermDefinition.t(), t, map, String.t(), map, map) ::
          {TermDefinition.t(), t, map}
  defp do_create_id_definition(definition, active, local, term, %{"@id" => id}, defined)
       when id != term do
    # 13.1)
    if is_binary(id) do
      # 13.2)
      {expanded_id, active, defined} = expand_iri(id, active, false, true, local, defined)

      cond do
        expanded_id == "@context" ->
          raise JSON.LD.InvalidKeywordAliasError, message: "cannot alias @context"

        JSON.LD.keyword?(expanded_id) or IRI.absolute?(expanded_id) or blank_node_id?(expanded_id) ->
          {%TermDefinition{definition | iri_mapping: expanded_id}, active, defined}

        true ->
          raise JSON.LD.InvalidIRIMappingError,
            message:
              "#{inspect(id)} is not a valid IRI mapping; resulting IRI mapping should be a keyword, absolute IRI or blank node"
      end
    else
      raise JSON.LD.InvalidIRIMappingError,
        message: "expected value of @id to be a string, but got #{inspect(id)}"
    end
  end

  defp do_create_id_definition(definition, active, local, term, _, defined) do
    # 14)
    # TODO: The W3C spec seems to contain an error by requiring only to check for a collon. What's when an absolute IRI is given and an "http" term is defined in the context?
    if String.contains?(term, ":") do
      case compact_iri_parts(term) do
        [prefix, suffix] ->
          prefix_mapping = local[prefix]

          {active, defined} =
            if prefix_mapping do
              do_create_term_definition(active, local, prefix, prefix_mapping, defined)
            else
              {active, defined}
            end

          if prefix_def = active.term_defs[prefix] do
            {%TermDefinition{definition | iri_mapping: prefix_def.iri_mapping <> suffix}, active,
             defined}
          else
            {%TermDefinition{definition | iri_mapping: term}, active, defined}
          end

        nil ->
          {%TermDefinition{definition | iri_mapping: term}, active, defined}
      end

      # 15)
    else
      if active.vocab do
        {%TermDefinition{definition | iri_mapping: active.vocab <> term}, active, defined}
      else
        raise JSON.LD.InvalidIRIMappingError,
          message:
            "#{inspect(term)} is not a valid IRI mapping; relative term definition without vocab mapping"
      end
    end
  end

  # 16.1)
  @spec do_create_container_definition(TermDefinition.t(), map) :: TermDefinition.t()
  defp do_create_container_definition(_, %{"@container" => container})
       when container not in ~w[@list @set @index @language] do
    raise JSON.LD.InvalidContainerMappingError,
      message:
        "#{inspect(container)} is not a valid container mapping; @container must be either @list, @set, @index, or @language"
  end

  # 16.2)
  defp do_create_container_definition(definition, %{"@container" => container}),
    do: %TermDefinition{definition | container_mapping: container}

  defp do_create_container_definition(definition, _),
    do: definition

  # 17)
  @spec do_create_language_definition(TermDefinition.t(), map) :: TermDefinition.t()
  defp do_create_language_definition(definition, %{"@language" => language} = value) do
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
    end
  end

  defp do_create_language_definition(definition, _), do: definition

  @doc """
  Inverse Context Creation algorithm

  Details at <https://www.w3.org/TR/json-ld-api/#inverse-context-creation>
  """
  @spec inverse(t) :: map
  def inverse(%__MODULE__{} = context) do
    # 2) Initialize default language to @none. If the active context has a default language, set default language to it.
    default_language = context.default_language || "@none"

    # 3) For each key term and value term definition in the active context, ordered by shortest term first (breaking ties by choosing the lexicographically least term)
    context.term_defs
    |> Enum.sort_by(fn {term, _} -> String.length(term) end)
    |> Enum.reduce(%{}, fn {term, term_def}, result ->
      # 3.1) If the term definition is null, term cannot be selected during compaction, so continue to the next term.
      if term_def do
        # 3.2) Initialize container to @none. If there is a container mapping in term definition, set container to its associated value.
        container = term_def.container_mapping || "@none"

        # 3.3) Initialize iri to the value of the IRI mapping for the term definition.
        iri = term_def.iri_mapping

        type_map = get_in(result, [iri, container, "@type"]) || %{}
        language_map = get_in(result, [iri, container, "@language"]) || %{}

        {type_map, language_map} =
          case term_def do
            # 3.8) If the term definition indicates that the term represents a reverse property
            %TermDefinition{reverse_property: true} ->
              {Map.put_new(type_map, "@reverse", term), language_map}

            # 3.9) Otherwise, if term definition has a type mapping
            %TermDefinition{type_mapping: type_mapping} when type_mapping != false ->
              {Map.put_new(type_map, type_mapping, term), language_map}

            # 3.10) Otherwise, if term definition has a language mapping (might be null)
            %TermDefinition{language_mapping: language_mapping} when language_mapping != false ->
              language = language_mapping || "@null"
              {type_map, Map.put_new(language_map, language, term)}

            # 3.11) Otherwise
            _ ->
              language_map = Map.put_new(language_map, default_language, term)
              language_map = Map.put_new(language_map, "@none", term)
              type_map = Map.put_new(type_map, "@none", term)
              {type_map, language_map}
          end

        result
        |> Map.put_new(iri, %{})
        |> Map.update(iri, %{}, fn container_map ->
          Map.put(container_map, container, %{"@type" => type_map, "@language" => language_map})
        end)
      else
        result
      end
    end)
  end

  @spec empty?(t) :: boolean
  def empty?(%__MODULE__{term_defs: term_defs, vocab: nil, base_iri: false, default_language: nil})
      when map_size(term_defs) == 0,
      do: true

  def empty?(_),
    do: false
end
