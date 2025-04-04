defmodule JSON.LD.Utils do
  @moduledoc nil

  alias RDF.IRI
  require Logger

  def valid_uri?(uri) do
    RDF.IRI.Validation.valid?(uri)
  end

  def valid_language?(string) do
    String.match?(string, ~r/^[a-zA-Z]+(-[a-zA-Z0-9]+)*$/)
  end

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
    case String.split(compact_iri, ":", parts: 2) do
      [prefix, suffix] ->
        if not String.starts_with?(suffix, "//") and not (exclude_bnode and prefix == "_"),
          do: [prefix, suffix]

      _ ->
        nil
    end
  end

  def keyword_form?(value), do: String.match?(value, ~r/^@[a-zA-Z]+$/)

  @doc """
  Checks if the given value is a blank node identifier.

  A blank node identifier is a string that can be used as an identifier for a
  blank node within the scope of a JSON-LD document.

  Blank node identifiers begin with `_:`

  see <https://www.w3.org/TR/json-ld-api/#dfn-blank-node-identifier>
  """
  @spec blank_node_id?(any) :: boolean
  def blank_node_id?("_:" <> _), do: true
  def blank_node_id?(_), do: false

  @spec scalar?(any) :: boolean
  def scalar?(value) when is_binary(value) or is_number(value) or is_boolean(value), do: true
  def scalar?(_), do: false

  @spec list?(map | nil) :: boolean
  def list?(%{"@list" => _}), do: true
  def list?(_), do: false

  @spec set?(map | nil) :: boolean
  def set?(%{"@set" => _}), do: true
  def set?(_), do: false

  @spec index?(map | nil) :: boolean
  def index?(%{"@index" => _}), do: true
  def index?(_), do: false

  @spec value?(map | nil) :: boolean
  def value?(%{"@value" => _}), do: true
  def value?(_), do: false

  # https://www.w3.org/TR/json-ld11/#dfn-node-object
  @spec id_node?(map | nil) :: boolean
  def id_node?(%{"@id" => _}), do: true
  def id_node?(_), do: false

  # https://www.w3.org/TR/json-ld11/#dfn-node-object
  @spec node?(map | nil) :: boolean
  def node?(value) when is_map(value) do
    not (value?(value) or list?(value) or set?(value))
  end

  def node?(_), do: false

  @spec graph?(map | any) :: boolean
  def graph?(value) when is_map(value) do
    Map.keys(value) -- ~w[@context @id @index] == ["@graph"]
  end

  def graph?(_), do: false

  @spec simple_graph?(map | any) :: boolean
  def simple_graph?(value) do
    graph?(value) and not Map.has_key?(value, "@id")
  end

  def deep_merge(map1, map2) do
    Map.merge(map1, map2, fn
      _key, value1, value2 when is_map(value1) and is_map(value2) -> deep_merge(value1, value2)
      _key, value1, value2 -> List.wrap(value1) ++ List.wrap(value2)
    end)
  end

  def to_list(value) when is_list(value), do: value
  def to_list(value), do: [value]

  def maybe_sort(enum, true), do: Enum.sort(enum)
  def maybe_sort(enum, false), do: enum

  def maybe_sort(enum, true, fun), do: Enum.sort(enum, fun)
  def maybe_sort(enum, false, _fun), do: enum

  def maybe_sort_by(enum, true, fun), do: Enum.sort_by(enum, fun)
  def maybe_sort_by(enum, false, _fun), do: enum

  def warn(message, %JSON.LD.Options{warn: method}), do: warn(message, method)
  def warn(message, :default), do: warn(message, JSON.LD.Options.warn_default())
  def warn(message, :log), do: warn(message, &Logger.warning/1)
  def warn(message, :raise), do: raise(message)
  def warn(_message, :ignore), do: :ok
  def warn(message, nil), do: warn(message, :default)
  def warn(message, true), do: warn(message, :default)
  def warn(message, false), do: warn(message, :ignore)
  def warn(message, fun) when is_function(fun), do: fun.(message)
end
