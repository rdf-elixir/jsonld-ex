defmodule JSON.LD.LoadingDocumentFailedError do
  @moduledoc """
  The document could not be loaded or parsed as JSON.
  """
  defexception code: "loading document failed", message: nil
end

defmodule JSON.LD.InvalidIndexValueError do
  @moduledoc """
  An @index member was encountered whose value was not a string.
  """
  defexception code: "invalid @index value", message: nil
end

defmodule JSON.LD.ConflictingIndexesError do
  @moduledoc """
  Multiple conflicting indexes have been found for the same node.
  """
  defexception code: "conflicting indexes", message: nil
end

defmodule JSON.LD.InvalidIdValueError do
  @moduledoc """
  An @id member was encountered whose value was not a string.
  """
  defexception code: "invalid @id value", message: nil
end

defmodule JSON.LD.InvalidLocalContextError do
  @moduledoc """
  An invalid local context was detected.
  """
  defexception code: "invalid local context", message: nil
end

defmodule JSON.LD.MultipleContextLinkHeadersError do
  @moduledoc """
  Multiple HTTP Link Headers [RFC5988] using the http://www.w3.org/ns/json-ld#context link relation have been detected.
  """
  defexception code: "multiple context link headers", message: nil
end

defmodule JSON.LD.LoadingRemoteContextFailedError do
  @moduledoc """
  There was a problem encountered loading a remote context.
  """
  defexception code: "loading remote context failed", message: nil
end

defmodule JSON.LD.InvalidRemoteContextError do
  @moduledoc """
  No valid context document has been found for a referenced, remote context.
  """
  defexception code: "invalid remote context", message: nil
end

defmodule JSON.LD.ContextOverflowError do
  @moduledoc """
  Maximum number of @context URLs exceeded.
  """
  defexception code: "context overflow", message: nil
end

defmodule JSON.LD.InvalidBaseIRIError do
  @moduledoc """
  An invalid base IRI has been detected, i.e., it is neither an absolute IRI nor null.
  """
  defexception code: "invalid base IRI", message: nil
end

defmodule JSON.LD.InvalidVocabMappingError do
  @moduledoc """
  An invalid vocabulary mapping has been detected, i.e., it is neither an absolute IRI nor null.
  """
  defexception code: "invalid vocab mapping", message: nil
end

defmodule JSON.LD.InvalidDefaultLanguageError do
  @moduledoc """
  The value of the default language is not a string or null and thus invalid.
  """
  defexception code: "invalid default language", message: nil
end

defmodule JSON.LD.KeywordRedefinitionError do
  @moduledoc """
  A keyword redefinition has been detected.
  """
  defexception code: "keyword redefinition", message: nil
end

defmodule JSON.LD.InvalidTermDefinitionError do
  @moduledoc """
  An invalid term definition has been detected.
  """
  defexception code: "invalid term definition", message: nil
end

defmodule JSON.LD.InvalidReversePropertyError do
  @moduledoc """
  An invalid reverse property definition has been detected.
  """
  defexception code: "invalid reverse property", message: nil
end

defmodule JSON.LD.InvalidIRIMappingError do
  @moduledoc """
  A local context contains a term that has an invalid or missing IRI mapping..
  """
  defexception code: "invalid IRI mapping", message: nil
end

defmodule JSON.LD.CyclicIRIMappingError do
  @moduledoc """
  A cycle in IRI mappings has been detected.
  """
  defexception code: "cyclic IRI mapping", message: nil
end

defmodule JSON.LD.InvalidKeywordAliasError do
  @moduledoc """
  An invalid keyword alias definition has been encountered.
  """
  defexception code: "invalid keyword alias", message: nil
end

defmodule JSON.LD.InvalidTypeMappingError do
  @moduledoc """
  An @type member in a term definition was encountered whose value could not be expanded to an absolute IRI.
  """
  defexception code: "invalid type mapping", message: nil
end

defmodule JSON.LD.InvalidLanguageMappingError do
  @moduledoc """
  An @language member in a term definition was encountered whose value was neither a string nor null and thus invalid.
  """
  defexception code: "invalid language mapping", message: nil
end

defmodule JSON.LD.CollidingKeywordsError do
  @moduledoc """
  Two properties which expand to the same keyword have been detected. This might occur if a keyword and an alias thereof are used at the same time.
  """
  defexception code: "colliding keywords", message: nil
end

defmodule JSON.LD.InvalidContainerMappingError do
  @moduledoc """
  An @container member was encountered whose value was not one of the following strings: @list, @set, or @index.
  """
  defexception code: "invalid container mapping", message: nil
end

defmodule JSON.LD.InvalidTypeValueError do
  @moduledoc """
  An invalid value for an @type member has been detected, i.e., the value was neither a string nor an array of strings.
  """
  defexception code: "invalid type value", message: nil
end

defmodule JSON.LD.InvalidValueObjectError do
  @moduledoc """
  A value object with disallowed members has been detected.
  """
  defexception code: "invalid value object", message: nil
end

defmodule JSON.LD.InvalidValueObjectValueError do
  @moduledoc """
  An invalid value for the @value member of a value object has been detected, i.e., it is neither a scalar nor null.
  """
  defexception code: "invalid value object value", message: nil
end

defmodule JSON.LD.InvalidLanguageTaggedStringError do
  @moduledoc """
  A language-tagged string with an invalid language value was detected.
  """
  defexception code: "invalid language-tagged string", value: nil

  def message(%__MODULE__{value: value}) do
    "#{inspect(value)} is not a valid language-tag"
  end
end

defmodule JSON.LD.InvalidLanguageTaggedValueError do
  @moduledoc """
  A number, true, or false with an associated language tag was detected.
  """
  defexception code: "invalid language-tagged value", message: nil
end

defmodule JSON.LD.InvalidTypedValueError do
  @moduledoc """
  A typed value with an invalid type was detected.
  """
  defexception code: "invalid typed value", message: nil
end

defmodule JSON.LD.InvalidSetOrListObjectError do
  @moduledoc """
  A set object or list object with disallowed members has been detected.
  """
  defexception code: "invalid set or list object", message: nil
end

defmodule JSON.LD.InvalidLanguageMapValueError do
  @moduledoc """
  An invalid value in a language map has been detected. It has to be a string or an array of strings.
  """
  defexception code: "invalid language map value", message: nil
end

defmodule JSON.LD.CompactionToListOfListsError do
  @moduledoc """
  The compacted document contains a list of lists as multiple lists have been compacted to the same term.
  """
  defexception code: "compaction to list of lists", message: nil
end

defmodule JSON.LD.InvalidReversePropertyMapError do
  @moduledoc """
  CollidingKeywordsError
  """
  defexception code: "invalid reverse property map", message: nil
end

defmodule JSON.LD.InvalidReverseValueError do
  @moduledoc """
  An invalid value for an @reverse member has been detected, i.e., the value was not a JSON object.
  """
  defexception code: "invalid @reverse value", message: nil
end

defmodule JSON.LD.InvalidReversePropertyValueError do
  @moduledoc """
  An invalid value for a reverse property has been detected. The value of an inverse property must be a node object.
  """
  defexception code: "invalid reverse property value", message: nil
end

defmodule JSON.LD.InvalidContextNullificationError do
  @moduledoc """
  An attempt was made to nullify a context containing protected term definitions.
  """
  defexception code: "invalid context nullification", message: nil
end

defmodule JSON.LD.ProtectedTermRedefinitionError do
  @moduledoc """
  An attempt was made to redefine a protected term.
  """
  defexception code: "protected term redefinition", message: nil
end

defmodule JSON.LD.InvalidContextEntryError do
  @moduledoc """
  An entry in a context is invalid due to processing mode incompatibility.
  """
  defexception code: "invalid context entry", message: nil
end

defmodule JSON.LD.InvalidScopedContextError do
  @moduledoc """
  The local context defined within a term definition is invalid.
  """
  defexception code: "invalid scoped context", message: nil
end

defmodule JSON.LD.InvalidImportValueError do
  @moduledoc """
  An invalid value for @import has been found.
  """
  defexception code: "invalid @import value", value: nil

  def message(%__MODULE__{code: code, value: value}) do
    "#{code}: #{inspect(value)}"
  end
end

defmodule JSON.LD.InvalidNestValueError do
  @moduledoc """
  An invalid value for @nest has been found.
  """
  defexception code: "invalid @nest value", message: nil
end

defmodule JSON.LD.InvalidIncludedValueError do
  @moduledoc """
  An included block contains an invalid value.
  """
  defexception code: "invalid @included value", message: nil
end

defmodule JSON.LD.InvalidBaseDirectionError do
  @moduledoc """
  The value of @direction is not "ltr", "rtl", or null and thus invalid.
  """
  defexception code: "invalid base direction", message: nil
end

defmodule JSON.LD.InvalidPrefixValueError do
  @moduledoc """
  An invalid value for @prefix has been found.
  """
  defexception code: "invalid @prefix value", value: nil

  def message(%__MODULE__{code: code, value: value}) do
    "#{code}: must be a boolean, was #{inspect(value)}"
  end
end

defmodule JSON.LD.InvalidVersionValueError do
  @moduledoc """
  The @version entry was used in a context with an out of range value.
  """
  defexception code: "invalid @version value", value: nil

  def message(%__MODULE__{code: code, value: value}) do
    "#{code}: #{inspect(value)}"
  end
end

defmodule JSON.LD.InvalidPropagateValueError do
  @moduledoc """
  An invalid value for @propagate has been found.
  """
  defexception code: "invalid @propagate value", value: nil

  def message(%__MODULE__{code: code, value: value}) do
    "#{code}: #{inspect(value)}"
  end
end

defmodule JSON.LD.IRIConfusedWithPrefixError do
  @moduledoc """
  When compacting an IRI would result in an IRI which could be confused with a compact IRI (because its IRI scheme matches a term definition and it has no IRI authority).
  """
  defexception code: "IRI confused with prefix", message: nil
end

defmodule JSON.LD.InvalidJSONLiteralError do
  @moduledoc """
  An invalid JSON literal was detected.
  """
  defexception code: "invalid JSON literal", value: nil

  def message(%__MODULE__{code: code, value: value}) do
    "#{code}: #{inspect(value)}"
  end
end

defmodule JSON.LD.ProcessingModeConflictError do
  @moduledoc """
  An attempt was made to change the processing mode which is incompatible with the previous specified version.
  """
  defexception code: "processing mode conflict", message: nil
end
