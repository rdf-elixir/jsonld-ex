defmodule JSON.LD do
  @moduledoc """
  An implementation of JSON-LD 1.0.

  As an implementation of the `RDF.Serialization.Format` behaviour of RDF.ex

  see <https://json-ld.org/>
  """

  use RDF.Serialization.Format

  import RDF.Sigils

  alias JSON.LD.{
    Compaction,
    Context,
    Expansion,
    Flattening,
    DocumentLoader,
    Encoder,
    Decoder,
    Options
  }

  alias JSON.LD.DocumentLoader.RemoteDocument
  alias RDF.{IRI, PropertyMap}

  @id ~I<http://www.w3.org/ns/formats/JSON-LD>
  @name :jsonld
  @extension "jsonld"
  @media_type "application/ld+json"

  @keywords ~w[
               @type
               @base
               @container
               @context
               @default
               @direction
               @graph
               @id
               @import
               @included
               @index
               @json
               @language
               @list
               @nest
               @none
               @prefix
               @propagate
               @protected
               @reverse
               @set
               @value
               @version
               @vocab
               :
              ]

  @type input :: map | [map] | String.t() | IRI.t() | RemoteDocument.t()
  @type context_convertible ::
          map | String.t() | nil | RDF.PropertyMap.t() | list(context_convertible)

  @spec options :: Options.t()
  def options, do: Options.new()

  @doc """
  The set of all JSON-LD keywords.

  see <https://www.w3.org/TR/json-ld/#syntax-tokens-and-keywords>
  """
  @spec keywords :: [String.t()]
  def keywords, do: @keywords

  @doc """
  Returns if the given value is a JSON-LD keyword.
  """
  @spec keyword?(String.t() | any) :: boolean
  def keyword?(value) when is_binary(value) and value in @keywords, do: true
  def keyword?(_value), do: false

  @doc """
  Expands the given input according to the steps in the JSON-LD Expansion Algorithm.

  > Expansion is the process of taking a JSON-LD document and applying a `@context`
  > such that all IRIs, types, and values are expanded so that the `@context` is
  > no longer necessary.

  -- <https://www.w3.org/TR/json-ld/#expanded-document-form>

  Details at <http://json-ld.org/spec/latest/json-ld-api/#expansion-algorithm>

  This is the `expand()` API function of the `JsonLdProcessor` interface as specified in
  <https://www.w3.org/TR/json-ld11-api/#the-application-programming-interface>
  """
  @spec expand(input(), Options.convertible()) :: map | [map] | nil
  def expand(input, options \\ []) do
    {processor_options, options} = Options.extract(options)
    expand(input, options, processor_options)
  end

  defp expand(%IRI{} = iri, options, processor_options),
    do: iri |> IRI.to_string() |> expand(options, processor_options)

  defp expand(url, options, processor_options) when is_binary(url) do
    case DocumentLoader.load(url, processor_options) do
      {:ok, document} -> expand(document, options, processor_options)
      {:error, error} -> raise error
    end
  end

  defp expand(%RemoteDocument{} = document, options, processor_options) do
    %{
      Context.new()
      | base_iri: processor_options.base || document.document_url,
        original_base_url: document.document_url || processor_options.base
    }
    |> expand(
      document.document,
      Keyword.put(options, :context_url, document.context_url),
      processor_options
    )
  end

  defp expand(input, options, processor_options) do
    processor_options
    |> Context.new()
    |> expand(input, options, processor_options)
  end

  defp expand(active_context, input, options, processor_options) do
    active_context =
      if processor_options.expand_context do
        context =
          case processor_options.expand_context do
            %{"@context" => context} -> context
            %{} = context -> context
            context when is_binary(context) -> context
            invalid -> raise ArgumentError, "Invalid expand context value: #{inspect(invalid)}"
          end

        Context.update(
          active_context,
          context,
          Options.set_base(processor_options, active_context.original_base_url)
        )
      else
        active_context
      end

    {active_context, options} =
      case Keyword.pop(options, :context_url) do
        {nil, options} ->
          {active_context, options}

        {context_url, options} ->
          {Context.update(active_context, context_url,
             base: context_url,
             processor_options: processor_options
           ), options}
      end

    case Expansion.expand(active_context, nil, input, options, processor_options) do
      result = %{"@graph" => graph} when map_size(result) == 1 -> graph
      nil -> []
      result when not is_list(result) -> [result]
      result -> result
    end
  end

  @doc """
  Compacts the given input according to the steps in the JSON-LD Compaction Algorithm.

  > Compaction is the process of applying a developer-supplied context to shorten
  > IRIs to terms or compact IRIs and JSON-LD values expressed in expanded form
  > to simple values such as strings or numbers. Often this makes it simpler to
  > work with document as the data is expressed in application-specific terms.
  > Compacted documents are also typically easier to read for humans.

  -- <https://www.w3.org/TR/json-ld/#compacted-document-form>

  Details at <https://www.w3.org/TR/json-ld-api/#compaction-algorithms>

  This is the `compact()` API function of the `JsonLdProcessor` interface as specified in
  <https://www.w3.org/TR/json-ld11-api/#the-application-programming-interface>
  """
  @spec compact(input(), context_convertible(), Options.convertible()) :: map
  def compact(input, context, options \\ []) do
    {processor_options, options} = Options.extract(options)
    compact(input, context, options, processor_options)
  end

  defp compact(%IRI{} = iri, context, options, processor_options),
    do: iri |> IRI.to_string() |> compact(context, options, processor_options)

  # 3)
  defp compact(url, context, options, processor_options) when is_binary(url) do
    case DocumentLoader.load(url, processor_options) do
      {:ok, document} -> compact(document, context, options, processor_options)
      {:error, error} -> raise error
    end
  end

  defp compact(input, context, _opts, popts) do
    # 4)
    expanded = JSON.LD.expand(input, %{popts | ordered: false})

    # 5)
    context_base = if match?(%RemoteDocument{}, input), do: input.document_url, else: popts.base

    # 6)
    context =
      case context do
        %{"@context" => context} -> context
        context -> context
      end

    # 7)
    active_context =
      %{
        context(context, %{popts | base: context_base})
        | # 8)
          api_base_iri: popts.base || if(popts.compact_to_relative, do: context_base)
      }
      |> Context.set_inverse()

    # 9)
    result =
      case Compaction.compact(expanded, active_context, nil, popts, popts.compact_arrays) do
        [] ->
          %{}

        result when is_list(result) ->
          %{Compaction.compact_iri("@graph", active_context, popts) => result}

        result ->
          result
      end

    cond do
      is_binary(context) -> Map.put(result, "@context", context)
      is_nil(context) || Enum.empty?(context) -> result
      true -> Map.put(result, "@context", context)
    end
  end

  @doc """
  Flattens the given input according to the steps in the JSON-LD Flattening Algorithm.

  > Flattening collects all properties of a node in a single JSON object and labels
  > all blank nodes with blank node identifiers. This ensures a shape of the data
  > and consequently may drastically simplify the code required to process JSON-LD
  > in certain applications.

  -- <https://www.w3.org/TR/json-ld/#flattened-document-form>

  Details at <https://www.w3.org/TR/json-ld-api/#flattening-algorithms>

  This is the `flatten()` API function of the `JsonLdProcessor` interface as specified in
  <https://www.w3.org/TR/json-ld11-api/#the-application-programming-interface>
  """
  @spec flatten(input(), context_convertible(), Options.convertible()) :: [map]
  def flatten(input, context \\ nil, options \\ %Options{}) do
    {processor_options, options} = Options.extract(options)
    flatten(input, context, options, processor_options)
  end

  defp flatten(%IRI{} = iri, context, options, processor_options),
    do: iri |> IRI.to_string() |> flatten(context, options, processor_options)

  # 3)
  defp flatten(url, context, options, processor_options) when is_binary(url) do
    case DocumentLoader.load(url, processor_options) do
      {:ok, document} -> flatten(document, context, options, processor_options)
      {:error, error} -> raise error
    end
  end

  defp flatten(input, context, _options, processor_options) do
    flattened =
      input
      |> expand(%{processor_options | ordered: false})
      |> Flattening.flatten(processor_options)

    if context && !Enum.empty?(flattened) do
      compact(
        flattened,
        context,
        if(
          is_nil(processor_options.base) and processor_options.compact_to_relative and
            match?(%RemoteDocument{}, input),
          do: %{processor_options | base: input.document_url},
          else: processor_options
        )
      )
    else
      flattened
    end
  end

  @doc """
  Transforms the given `RDF.Dataset` into a JSON-LD document in expanded form.

  Details at <https://www.w3.org/TR/json-ld-api/#serialize-rdf-as-json-ld-algorithm>

  This is the `toRdf()` API function of the `JsonLdProcessor` interface as specified in
  <https://www.w3.org/TR/json-ld11-api/#the-application-programming-interface>
  """
  defdelegate from_rdf(data, options \\ %Options{}), to: Encoder

  @doc """
  Transforms the given JSON-LD document into an `RDF.Dataset`.

  Details at <https://www.w3.org/TR/json-ld-api/#deserialize-json-ld-to-rdf-algorithm>

  This is the `fromRdf()` API function of the `JsonLdProcessor` interface as specified in
  <https://www.w3.org/TR/json-ld11-api/#the-application-programming-interface>
  """
  defdelegate to_rdf(input, options \\ %Options{}), to: Decoder

  @doc """
  Generator function for `JSON.LD.Context`s.

  You can either pass a map with a `"@context"` key having the JSON-LD context
  object its value, or the JSON-LD context object directly.

  This function can be used also to create `JSON.LD.Context` from a `RDF.PropertyMap`.
  """
  @spec context(context_convertible(), Options.t()) :: Context.t()
  def context(context, options \\ %Options{}) do
    context
    |> normalize_context()
    |> do_context(options)
  end

  defp do_context(%{"@context" => _} = object, options), do: Context.create(object, options)
  defp do_context(context, options), do: Context.create(%{"@context" => context}, options)

  defp normalize_context(%PropertyMap{} = property_map) do
    Map.new(property_map, fn {property, iri} ->
      {to_string(property), to_string(iri)}
    end)
  end

  defp normalize_context(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_map(value) -> {to_string(key), normalize_context(value)}
      {key, value} -> {to_string(key), value}
    end)
  end

  defp normalize_context(list) when is_list(list), do: Enum.map(list, &normalize_context/1)
  defp normalize_context(value), do: value

  @doc """
  Generator function for JSON-LD node maps.
  """
  defdelegate node_map(input, node_id_map \\ nil), to: Flattening
end
