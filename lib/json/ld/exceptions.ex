defmodule JSON.LD.Error do
  @moduledoc """
  The base exception for all JSON-LD errors.

  See <https://w3c.github.io/json-ld-api/#jsonlderror>
  """
  @enforce_keys [:code, :message]
  defexception [:code, :message]

  def message(%__MODULE__{code: code, message: message}) do
    "#{code}: #{message}"
  end

  @doc """
  Two properties which expand to the same keyword have been detected.
  This might occur if a keyword and an alias thereof are used at the same time.
  """
  def colliding_keywords(keyword) do
    exception(
      code: "colliding keywords",
      message: "#{keyword} already exists in result"
    )
  end

  @doc """
  Multiple conflicting indexes have been found for the same node.
  """
  def conflicting_indexes(index1, index2) do
    exception(
      code: "conflicting indexes",
      message: "Conflicting indexes #{inspect(index1)} and #{inspect(index2)}"
    )
  end

  @doc """
  Maximum number of `@context` URLs exceeded.
  """
  def context_overflow(context) do
    exception(
      code: "context overflow",
      message: "Maximum number of @context URLs exceeded: #{inspect(context)}"
    )
  end

  @doc """
  A cycle in IRI mappings has been detected.
  """
  def cyclic_iri_mapping(term) do
    exception(
      code: "cyclic IRI mapping",
      message: "Cyclical term dependency found: #{inspect(term)}"
    )
  end

  @doc """
  An `@id` entry was encountered whose value was not a string.
  """
  def invalid_id_value(value) do
    exception(
      code: "invalid @id value",
      message: "#{inspect(value)} is not a valid @id value"
    )
  end

  @doc """
  An invalid value for `@import` has been found.
  """
  def invalid_import_value(value) do
    exception(
      code: "invalid @import value",
      message: "#{inspect(value)} is not a valid @import value"
    )
  end

  @doc """
  An included block contains an invalid value.
  """
  def invalid_included_value(value \\ nil) do
    message = "values of @included must expand to node objects"

    exception(
      code: "invalid @included value",
      message:
        if(value,
          do: "#{inspect(value)} is not a valid @included value; #{message}",
          else: message
        )
    )
  end

  @doc """
  An `@index` member was encountered whose value was not a string.
  """
  def invalid_index_value(value) do
    exception(
      code: "invalid @index value",
      message: "#{inspect(value)} is not a valid @index value"
    )
  end

  @doc """
  An invalid value for `@nest` has been found.
  """
  def invalid_nest_value(message) do
    exception(
      code: "invalid @nest value",
      message: message
    )
  end

  @doc """
  An invalid value for `@prefix` has been found.
  """
  def invalid_prefix_value(value) do
    exception(
      code: "invalid @prefix value",
      message: "#{inspect(value)} is not a valid @prefix value; must be a boolean"
    )
  end

  @doc """
  An invalid value for `@propagate` has been found.
  """
  def invalid_propagate_value(value) do
    exception(
      code: "invalid @propagate value",
      message: "#{inspect(value)} is not a valid @propagate value; must be a boolean"
    )
  end

  @doc """
  An invalid value for `@protected` has been found.
  """
  def invalid_protected_value(value) do
    exception(
      code: "invalid @protected value",
      message: "#{inspect(value)} is not a valid @protected value; must be a boolean"
    )
  end

  @doc """
  An invalid value for an `@reverse` entry has been detected, i.e., the value was not a map.
  """
  def invalid_reverse_value(value) do
    exception(
      code: "invalid @reverse value",
      message: "#{inspect(value)} is not a valid @reverse value; must be a map"
    )
  end

  @doc """
  The `@version` entry was used in a context with an out of range value.
  """
  def invalid_version_value(value) do
    exception(
      code: "invalid @version value",
      message: "#{inspect(value)} is not a valid @version value"
    )
  end

  @doc """
  The value of @direction is not "ltr", "rtl", or null and thus invalid.
  """
  def invalid_base_direction(direction) do
    exception(
      code: "invalid base direction",
      message:
        "#{inspect(direction)} is not a valid base direction; must be 'ltr', 'rtl', or null"
    )
  end

  @doc """
  An invalid base IRI has been detected, i.e., it is neither an absolute IRI nor null.
  """
  def invalid_base_iri(base) do
    exception(
      code: "invalid base IRI",
      message: "#{inspect(base)} is not a valid absolute IRI"
    )
  end

  def invalid_base_iri(base, :relative_without_active_base) do
    exception(
      code: "invalid base IRI",
      message: "#{inspect(base)} is a relative IRI, but no active base IRI defined"
    )
  end

  @doc """
  An `@container` entry was encountered whose value was not one of the following strings: `@list`, `@set`, `@language`, `@index`, `@id`, `@graph`, or `@type`.
  """
  def invalid_container_mapping(message) do
    exception(
      code: "invalid container mapping",
      message: message
    )
  end

  @doc """
  An entry in a context is invalid due to processing mode incompatibility.
  """
  def invalid_context_entry(message) do
    exception(
      code: "invalid context entry",
      message: message
    )
  end

  @doc """
  An attempt was made to nullify a context containing protected term definitions.
  """
  def invalid_context_nullification do
    exception(
      code: "invalid context nullification",
      message: "Cannot nullify a context containing protected term definitions"
    )
  end

  @doc """
  The value of the default language is not a string or null and thus invalid.
  """
  def invalid_default_language(language) do
    exception(
      code: "invalid default language",
      message: "#{inspect(language)} is not a valid language value"
    )
  end

  @doc """
  A local context contains a term that has an invalid or missing IRI mapping.
  """
  def invalid_iri_mapping(message) do
    exception(
      code: "invalid IRI mapping",
      message: message
    )
  end

  @doc """
  An invalid JSON literal was detected.
  """
  def invalid_json_literal(value) do
    exception(
      code: "invalid JSON literal",
      message: "#{inspect(value)} is not a valid JSON literal"
    )
  end

  @doc """
  An invalid keyword alias definition has been encountered.
  """
  def invalid_keyword_alias(message) do
    exception(
      code: "invalid keyword alias",
      message: message
    )
  end

  @doc """
  An invalid value in a language map has been detected. It MUST be a string or an array of strings.
  """
  def invalid_language_map_value(value) do
    exception(
      code: "invalid language map value",
      message: "#{inspect(value)} is not a valid language map value"
    )
  end

  @doc """
  An `@language` entry in a term definition was encountered whose value was neither a string nor null and thus invalid.
  """
  def invalid_language_mapping(language) do
    exception(
      code: "invalid language mapping",
      message:
        "#{inspect(language)} is not a valid language mapping; @language must be a string or null"
    )
  end

  @doc """
  A language-tagged string with an invalid language value was detected.
  """
  def invalid_language_tagged_string(value) do
    exception(
      code: "invalid language-tagged string",
      message: "#{inspect(value)} has an invalid language tag"
    )
  end

  @doc """
  A number, `true`, or `false` with an associated language tag was detected.
  """
  def invalid_language_tagged_value(value) do
    exception(
      code: "invalid language-tagged value",
      message: "#{inspect(value)} cannot be language-tagged"
    )
  end

  @doc """
  An invalid local context was detected.
  """
  def invalid_local_context(context) do
    exception(
      code: "invalid local context",
      message: "#{inspect(context)} is not a valid local context"
    )
  end

  @doc """
  No valid context document has been found for a referenced remote context.
  """
  def invalid_remote_context(invalid: context) do
    exception(
      code: "invalid remote context",
      message: "Context is not a valid JSON object: #{inspect(context)}"
    )
  end

  def invalid_remote_context(message) do
    exception(
      code: "invalid remote context",
      message: message
    )
  end

  @doc """
  An invalid reverse property definition has been detected.
  """
  def invalid_reverse_property(message) do
    exception(
      code: "invalid reverse property",
      message: message
    )
  end

  @doc """
  An invalid reverse property map has been detected. No keywords apart from `@context` are allowed in reverse property maps.
  """
  def invalid_reverse_property_map do
    exception(
      code: "invalid reverse property map",
      message:
        "An invalid reverse property map has been detected. No keywords apart from `@context` are allowed in reverse property maps."
    )
  end

  @doc """
  An invalid value for a reverse property has been detected. The value of an inverse property must be a node object.
  """
  def invalid_reverse_property_value(value) do
    exception(
      code: "invalid reverse property value",
      message: "invalid value for a reverse property in #{inspect(value)}"
    )
  end

  @doc """
  The local context defined within a term definition is invalid.
  """
  def invalid_scoped_context(message) do
    exception(
      code: "invalid scoped context",
      message: message
    )
  end

  @doc """
  A script element in HTML input which is the target of a fragment identifier does not have an appropriate type attribute.
  """
  def invalid_script_element(message) do
    exception(
      code: "invalid script element",
      message: message
    )
  end

  @doc """
  A set object or list object with disallowed members has been detected.
  """
  def invalid_set_or_list_object(value) do
    exception(
      code: "invalid set or list object",
      message: "set or list object with disallowed members: #{inspect(value)}"
    )
  end

  @doc """
  An invalid term definition has been detected.
  """
  def invalid_term_definition(message) do
    exception(
      code: "invalid term definition",
      message: message
    )
  end

  @doc """
  An `@type` entry in a term definition was encountered whose value could not be expanded to an IRI.
  """
  def invalid_type_mapping(message: message) do
    exception(
      code: "invalid type mapping",
      message: message
    )
  end

  def invalid_type_mapping(type) do
    exception(
      code: "invalid type mapping",
      message: "#{inspect(type)} is not a valid type mapping"
    )
  end

  @doc """
  An invalid value for an `@type` entry has been detected, i.e., the value was neither a string nor an array of strings.
  """
  def invalid_type_value(value) do
    exception(
      code: "invalid type value",
      message: "#{inspect(value)} is not a valid type value"
    )
  end

  @doc """
  A typed value with an invalid type was detected.
  """
  def invalid_typed_value(value, type) do
    exception(
      code: "invalid typed value",
      message: "#{inspect(value)} is not valid for type #{inspect(type)}"
    )
  end

  @doc """
  A value object with disallowed entries has been detected.
  """
  def invalid_value_object(message) do
    exception(
      code: "invalid value object",
      message: message
    )
  end

  @doc """
  An invalid value for the `@value` entry of a value object has been detected, i.e., it is neither a scalar nor `null`.
  """
  def invalid_value_object_value(value) do
    exception(
      code: "invalid value object value",
      message: "#{inspect(value)} is not a valid value object; must be a scalar or null"
    )
  end

  @doc """
  An invalid vocabulary mapping has been detected, i.e., it is neither an IRI nor `null`.
  """
  def invalid_vocab_mapping(message: message) do
    exception(
      code: "invalid vocab mapping",
      message: message
    )
  end

  def invalid_vocab_mapping(vocab) do
    exception(
      code: "invalid vocab mapping",
      message:
        "#{inspect(vocab)} is not a valid vocabulary mapping; must be an absolute IRI or null"
    )
  end

  @doc """
  When compacting an IRI would result in an IRI which could be confused with a compact IRI (because its IRI scheme matches a term definition and it has no IRI authority).
  """
  def iri_confused_with_prefix(iri, prefix) do
    exception(
      code: "IRI confused with prefix",
      message: "Absolute IRI '#{iri}' confused with prefix '#{prefix}'"
    )
  end

  @doc """
  A keyword redefinition has been detected.
  """
  def keyword_redefinition(message) do
    exception(
      code: "keyword redefinition",
      message: message
    )
  end

  @doc """
  The document could not be loaded or parsed as JSON.
  """
  def loading_document_failed(message) do
    exception(
      code: "loading document failed",
      message: message
    )
  end

  @doc """
  There was a problem encountered loading a remote context.
  """
  def loading_remote_context_failed(url, reason) do
    exception(
      code: "loading remote context failed",
      message: "Could not load remote context #{url}: #{inspect(reason)}"
    )
  end

  @doc """
  Multiple HTTP Link Headers using the http://www.w3.org/ns/json-ld#context link relation have been detected.
  """
  def multiple_context_link_headers do
    exception(
      code: "multiple context link headers",
      message:
        "Multiple HTTP Link Headers using the http://www.w3.org/ns/json-ld#context link relation have been detected"
    )
  end

  @doc """
  An attempt was made to change the processing mode which is incompatible with the previous specified version.
  """
  def processing_mode_conflict do
    exception(
      code: "processing mode conflict",
      message: "Processing mode conflict"
    )
  end

  @doc """
  An attempt was made to redefine a protected term.
  """
  def protected_term_redefinition(term) do
    exception(
      code: "protected term redefinition",
      message: "#{inspect(term)} is a protected term and cannot be redefined"
    )
  end
end
