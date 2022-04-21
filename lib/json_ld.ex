defmodule JSON.LD do
  use RDF.Serialization.Format

  import RDF.Sigils

  alias JSON.LD.{Compaction, Context, Expansion, Flattening, Options}

  @id ~I<http://www.w3.org/ns/formats/JSON-LD>
  @name :jsonld
  @extension "jsonld"
  @media_type "application/ld+json"

  @keywords ~w[
    @base
    @container
    @context
    @default
    @graph
    @id
    @index
    @language
    @list
    @reverse
    @set
    @type
    @value
    @vocab
    :
  ]

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
  @spec keyword?(String.t()) :: boolean
  def keyword?(value) when is_binary(value) and value in @keywords, do: true
  def keyword?(_value), do: false

  @doc """
  Expands the given input according to the steps in the JSON-LD Expansion Algorithm.

  > Expansion is the process of taking a JSON-LD document and applying a `@context`
  > such that all IRIs, types, and values are expanded so that the `@context` is
  > no longer necessary.

  -- <https://www.w3.org/TR/json-ld/#expanded-document-form>

  Details at <http://json-ld.org/spec/latest/json-ld-api/#expansion-algorithm>
  """
  defdelegate expand(input, options \\ %Options{}), to: Expansion

  @doc """
  Compacts the given input according to the steps in the JSON-LD Compaction Algorithm.

  > Compaction is the process of applying a developer-supplied context to shorten
  > IRIs to terms or compact IRIs and JSON-LD values expressed in expanded form
  > to simple values such as strings or numbers. Often this makes it simpler to
  > work with document as the data is expressed in application-specific terms.
  > Compacted documents are also typically easier to read for humans.

  -- <https://www.w3.org/TR/json-ld/#compacted-document-form>

  Details at <https://www.w3.org/TR/json-ld-api/#compaction-algorithms>
  """
  defdelegate compact(input, context, options \\ %Options{}), to: Compaction

  @doc """
  Flattens the given input according to the steps in the JSON-LD Flattening Algorithm.

  > Flattening collects all properties of a node in a single JSON object and labels
  > all blank nodes with blank node identifiers. This ensures a shape of the data
  > and consequently may drastically simplify the code required to process JSON-LD
  > in certain applications.

  -- <https://www.w3.org/TR/json-ld/#flattened-document-form>

  Details at <https://www.w3.org/TR/json-ld-api/#flattening-algorithms>
  """
  defdelegate flatten(input, context \\ nil, options \\ %Options{}), to: Flattening

  @doc """
  Generator function for `JSON.LD.Context`s.

  You can either pass a map with a `"@context"` key having the JSON-LD context
  object its value, or the JSON-LD context object directly.
  """
  @spec context(map, Options.t()) :: Context.t()
  def context(args, opts \\ %Options{})

  def context(%{"@context" => _} = object, options),
    do: Context.create(object, options)

  def context(context, options),
    do: Context.create(%{"@context" => context}, options)

  @doc """
  Generator function for JSON-LD node maps.
  """
  defdelegate node_map(input, node_id_map \\ nil), to: Flattening
end
