defmodule JSON.LD do

  @keywords ~w[
    @base
    @container
    @context
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

  defdelegate expand(input, options \\ []),
    to: JSON.LD.Expansion

  defdelegate compact(input, context, options \\ []),
    to: JSON.LD.Compaction

  defdelegate flatten(input, context \\ nil, options \\ []),
    to: JSON.LD.Flattening

  @doc """
  Generator function for `JSON.LD.Context`s.

  You can either pass a map with a `"@context"` key having the JSON-LD context
  object its value, or the JSON-LD context object directly.
  """
  def context(args, opts \\ [])

  def context(%{"@context" => _} = object, opts),
    do: JSON.LD.Context.create(object, opts)

  def context(context, opts),
    do: JSON.LD.Context.create(%{"@context" => context}, opts)

end
