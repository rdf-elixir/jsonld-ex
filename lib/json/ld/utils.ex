defmodule JSON.LD.Utils do

  @doc """
  Resolves a relative IRI against a base IRI.

  as specified in [section 5.1 Establishing a Base URI of RFC3986](http://tools.ietf.org/html/rfc3986#section-5.1).
  Only the basic algorithm in [section 5.2 of RFC3986](http://tools.ietf.org/html/rfc3986#section-5.2)
  is used; neither Syntax-Based Normalization nor Scheme-Based Normalization are performed.

  Characters additionally allowed in IRI references are treated in the same way that unreserved
  characters are treated in URI references, per [section 6.5 of RFC3987](http://tools.ietf.org/html/rfc3987#section-6.5)
  """
# TODO: This should be part of a dedicated RDF.IRI implementation and properly tested.
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
# TODO: This should be part of a dedicated RDF.IRI implementation and properly tested.
  def absolute_iri?(value), do: RDF.uri?(value)

# TODO: This should be part of a dedicated RDF.IRI implementation and properly tested.
  def relative_iri?(value),
    do: not (JSON.LD.keyword?(value) or absolute_iri?(value) or blank_node_id?(value))

  def compact_iri_parts(compact_iri, exclude_bnode \\ true) do
    with [prefix, suffix] <- String.split(compact_iri, ":", parts: 2) do
      if not(String.starts_with?(suffix, "//")) and
         not(exclude_bnode and prefix == "_"),
      do: [prefix, suffix]
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

  def list?(%{"@list" => _}), do: true
  def list?(_),          do: false
  def index?(%{"@index" => _}), do: true
  def index?(_),          do: false
  def value?(%{"@value" => _}), do: true
  def value?(_),          do: false

end
