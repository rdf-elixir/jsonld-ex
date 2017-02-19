defmodule JSON.LD do

  # see https://www.w3.org/TR/2014/REC-json-ld-20140116/#syntax-tokens-and-keywords
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

  def keywords, do: @keywords

  def keyword?(value) when is_binary(value) and value in @keywords, do: true
  def keyword?(value), do: false


  defdelegate expand(json_ld_object, opts \\ []),
    to: JSON.LD.Expansion

  defdelegate expand_iri(value, active_context, doc_relative \\ false,
                          vocab \\ false, local_context \\ nil, defined \\ nil),
    to: JSON.LD.IRIExpansion


  @doc """
  Generator function for `JSON.LD.Context`s.
  """
  def context(args, opts \\ [])

  def context(%{"@context" => _} = object, opts),
    do: JSON.LD.Context.create(object, opts)

  def context(context, opts),
    do: JSON.LD.Context.create(%{"@context" => context}, opts)


  ###########################################################################

  @doc """
  Resolves a relative IRI against a base IRI.

  as specified in [section 5.1 Establishing a Base URI of RFC3986](http://tools.ietf.org/html/rfc3986#section-5.1).
  Only the basic algorithm in [section 5.2 of RFC3986](http://tools.ietf.org/html/rfc3986#section-5.2)
  is used; neither Syntax-Based Normalization nor Scheme-Based Normalization are performed.

  Characters additionally allowed in IRI references are treated in the same way that unreserved
  characters are treated in URI references, per [section 6.5 of RFC3987](http://tools.ietf.org/html/rfc3987#section-6.5)
  """
#  TODO: This should be part of a dedicated URI/IRI implementation and properly tested.
  def absolute_iri(value, base_iri)

  def absolute_iri(value, nil), do: value

  def absolute_iri(value, base_iri) do
    case URI.parse(value) do
      # absolute?
      uri = %URI{scheme: scheme} when not is_nil(scheme) -> uri
      # relative
      _ ->
        URI.merge(base_iri, value)
    end
    |> to_string
  end


  @doc """
  Checks if the given value is an absolute IRI.

  An absolute IRI is defined in [RFC3987](http://www.ietf.org/rfc/rfc3987.txt)
  containing a scheme along with a path and optional query and fragment segments.

  see <https://www.w3.org/TR/json-ld-api/#dfn-absolute-iri>
  """
#  TODO: This should be part of a dedicated URI/IRI implementation and properly tested.
  def absolute_iri?(value), do: RDF.uri?(value)

  def compact_iri_parts(compact_iri, exclude_bnode \\ true) do
    with [prefix, suffix] when not(binary_part(suffix, 0, 2) == "//") and
                               not(exclude_bnode and prefix == "_") <-
            String.split(compact_iri, ":", parts: 2) do
      [prefix, suffix]
    else
     _ -> nil
    end
  end


  @doc """
  Checks if the given value is a blank node identifier.

  A blank node identifier is a string that can be used as an identifier for a
  blank node within the scope of a JSON-LD document.

  Blank node identifiers begin with `_:`

  see <https://www.w3.org/TR/json-ld-api/#dfn-blank-node-identifier>
  """
  def blank_node_id?("_:" <> _), do: true
  def blank_node_id?(_),         do: false


  def scalar?(value) when is_binary(value) or is_number(value) or
                          is_boolean(value), do: true
  def scalar?(_), do: false

end
