defmodule JSON.LD do

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

  @doc """
  The set of all JSON-LD keywords.

  see <https://www.w3.org/TR/json-ld/#syntax-tokens-and-keywords>
  """
  def keywords, do: @keywords

  @doc """
  Returns if the given value is a JSON-LD keyword.
  """
  def keyword?(value) when is_binary(value) and value in @keywords, do: true
  def keyword?(value), do: false


  @doc """
  Expands the given input according to the steps in the JSON-LD Expansion Algorithm.

  > Expansion is the process of taking a JSON-LD document and applying a `@context`
  > such that all IRIs, types, and values are expanded so that the `@context` is
  > no longer necessary.

  -- <https://www.w3.org/TR/json-ld/#expanded-document-form>

  Details at <http://json-ld.org/spec/latest/json-ld-api/#expansion-algorithm>
  """
  defdelegate expand(input, options \\ %JSON.LD.Options{}),
    to: JSON.LD.Expansion


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
  defdelegate compact(input, context, options \\ %JSON.LD.Options{}),
    to: JSON.LD.Compaction


  @doc """
  Flattens the given input according to the steps in the JSON-LD Flattening Algorithm.

  > Flattening collects all properties of a node in a single JSON object and labels
  > all blank nodes with blank node identifiers. This ensures a shape of the data
  > and consequently may drastically simplify the code required to process JSON-LD
  > in certain applications.

  -- <https://www.w3.org/TR/json-ld/#flattened-document-form>

  Details at <https://www.w3.org/TR/json-ld-api/#flattening-algorithms>
  """
  defdelegate flatten(input, context \\ nil, options \\ %JSON.LD.Options{}),
    to: JSON.LD.Flattening


  @doc """
  Generator function for `JSON.LD.Context`s.

  You can either pass a map with a `"@context"` key having the JSON-LD context
  object its value, or the JSON-LD context object directly.
  """
  def context(args, opts \\ %JSON.LD.Options{})

  def context(%{"@context" => _} = object, options),
    do: JSON.LD.Context.create(object, options)

  def context(context, options),
    do: JSON.LD.Context.create(%{"@context" => context}, options)


  @doc """
  Generator function for JSON-LD node maps.
  """
  def node_map(input, node_id_map \\ nil),
    do: JSON.LD.Flattening.node_map(input, node_id_map)

end
