defmodule JSON.LD.Utils do
  alias RDF.IRI

  @doc """
  Resolves a relative IRI against a base IRI.

  as specified in [section 5.1 Establishing a Base URI of RFC3986](http://tools.ietf.org/html/rfc3986#section-5.1).
  Only the basic algorithm in [section 5.2 of RFC3986](http://tools.ietf.org/html/rfc3986#section-5.2)
  is used; neither Syntax-Based Normalization nor Scheme-Based Normalization are performed.

  Characters additionally allowed in IRI references are treated in the same way that unreserved
  characters are treated in URI references, per [section 6.5 of RFC3987](http://tools.ietf.org/html/rfc3987#section-6.5)
  """
  @spec absolute_iri(String.t(), String.t() | nil) :: IRI.coercible() | nil
  def absolute_iri(value, base_iri)

  def absolute_iri(value, nil),
    do: value

  def absolute_iri(value, base_iri),
    do: value |> IRI.absolute(base_iri) |> to_string

  @spec relative_iri?(String.t()) :: boolean
  def relative_iri?(value),
    do: not (JSON.LD.keyword?(value) or IRI.absolute?(value) or blank_node_id?(value))

  @spec compact_iri_parts(String.t(), boolean) :: [String.t()] | nil
  def compact_iri_parts(compact_iri, exclude_bnode \\ true) do
    with [prefix, suffix] <- String.split(compact_iri, ":", parts: 2) do
      if not String.starts_with?(suffix, "//") and
           not (exclude_bnode and prefix == "_"),
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
  @spec blank_node_id?(String.t()) :: boolean
  def blank_node_id?("_:" <> _), do: true
  def blank_node_id?(_), do: false

  @spec scalar?(any) :: boolean
  def scalar?(value) when is_binary(value) or is_number(value) or is_boolean(value), do: true
  def scalar?(_), do: false

  @spec list?(map | nil) :: boolean
  def list?(%{"@list" => _}), do: true
  def list?(_), do: false

  @spec index?(map | nil) :: boolean
  def index?(%{"@index" => _}), do: true
  def index?(_), do: false

  @spec value?(map | nil) :: boolean
  def value?(%{"@value" => _}), do: true
  def value?(_), do: false
end
