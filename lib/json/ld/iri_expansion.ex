defmodule JSON.LD.IRIExpansion do
  import JSON.LD.Utils

  alias JSON.LD.Context

  # to allow this to be used in function guard clauses, we redefine this here
  @keywords JSON.LD.keywords()

  @doc """
  see http://json-ld.org/spec/latest/json-ld-api/#iri-expansion
  """
  @spec expand_iri(String.t(), Context.t(), boolean, boolean, map | nil, map | nil) ::
          {String.t(), Context.t(), map} | String.t()
  def expand_iri(
        value,
        active_context,
        doc_relative \\ false,
        vocab \\ false,
        local_context \\ nil,
        defined \\ nil
      )

  # 1) If value is a keyword or null, return value as is.
  def expand_iri(value, active_context, _, _, local_context, defined)
      when is_nil(value) or value in @keywords do
    if local_context || defined do
      {value, active_context, defined}
    else
      value
    end
  end

  def expand_iri(value, active_context, doc_relative, vocab, local_context, defined) do
    # 2)
    {active_context, defined} =
      if local_context && local_context[value] && defined[value] != true do
        local_def = local_context[value]

        Context.create_term_definition(
          active_context,
          local_context,
          value,
          local_def,
          defined
        )
      else
        {active_context, defined}
      end

    {result, active_context, defined} =
      cond do
        # 3) If vocab is true and the active context has a term definition for value,
        # return the associated IRI mapping.
        vocab && Map.has_key?(active_context.term_defs, value) ->
          result = (term_def = active_context.term_defs[value]) && term_def.iri_mapping
          {result, active_context, defined}

        # 4) If value contains a colon (:), it is either an absolute IRI, a compact IRI,
        # or a blank node identifier
        String.contains?(value, ":") ->
          case compact_iri_parts(value) do
            [prefix, suffix] ->
              # 4.3)
              {active_context, defined} =
                if local_context && local_context[prefix] && defined[prefix] != true do
                  local_def = local_context[prefix]

                  Context.create_term_definition(
                    active_context,
                    local_context,
                    prefix,
                    local_def,
                    defined
                  )
                else
                  {active_context, defined}
                end

              # 4.4)
              result =
                if prefix_def = active_context.term_defs[prefix] do
                  prefix_def.iri_mapping <> suffix
                else
                  # 4.5)
                  value
                end

              {result, active_context, defined}

            nil ->
              # 4.2)
              {value, active_context, defined}
          end

        # 5) If vocab is true, and active context has a vocabulary mapping, return the
        # result of concatenating the vocabulary mapping with value.
        vocab && active_context.vocab ->
          vocabulary_mapping = active_context.vocab
          {vocabulary_mapping <> value, active_context, defined}

        # 6) Otherwise, if document relative is true, set value to the result of resolving
        # value against the base IRI. Only the basic algorithm in section 5.2 of [RFC3986]
        # is used; neither Syntax-Based Normalization nor Scheme-Based Normalization are
        # performed. Characters additionally allowed in IRI references are treated in the
        # same way that unreserved characters are treated in URI references, per section
        # 6.5 of [RFC3987].
        doc_relative ->
          {absolute_iri(value, Context.base(active_context)), active_context, defined}

        # TODO: RDF.rb's implementation differs from the spec here, by checking if
        # base_iri is actually present in the previous clause and adding the following
        # additional clause. Another Spec error?
        #   if local_context && RDF::URI(value).relative?
        #     # If local context is not null and value is not an absolute IRI, an invalid
        #     # IRI mapping error has been detected and processing is aborted.
        #     raise JSON.LD.InvalidIRIMappingError, message: "not an absolute IRI: #{value}"
        # 7) Return value as is.
        true ->
          {value, active_context, defined}
      end

    if local_context do
      {result, active_context, defined}
    else
      result
    end
  end
end
