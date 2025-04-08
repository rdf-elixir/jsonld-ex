defmodule JSON.LD.IRIExpansion do
  @moduledoc """
  Implementation of the JSON-LD 1.1 IRI Expansion algorithm.

  <https://www.w3.org/TR/json-ld11-api/#iri-expansion>
  """

  import JSON.LD.Utils

  alias JSON.LD.{Context, Options}
  alias RDF.IRI

  # to allow this to be used in function guard clauses, we redefine this here
  @keywords JSON.LD.keywords()

  @spec expand_iri(String.t(), Context.t(), Options.t(), boolean, boolean, map | nil, map | nil) ::
          {String.t() | nil, Context.t(), map} | String.t() | nil
  def expand_iri(
        value,
        active_context,
        options \\ Options.new(),
        doc_relative \\ false,
        vocab \\ false,
        local_context \\ nil,
        defined \\ nil
      )

  # 1) If value is a keyword or null, return value as is.
  def expand_iri(value, active_context, _options, _, _, local_context, defined)
      when is_nil(value) or value in @keywords do
    # We need this unspecified behaviour to differentiate scenarios where the changed context doesn't need to be returned
    if local_context || defined do
      {value, active_context, defined}
    else
      value
    end
  end

  def expand_iri(value, active_context, options, doc_relative, vocab, local_context, defined)
      when is_binary(value) do
    # 2) If value has the form of a keyword (i.e., it matches the ABNF rule "@"1*ALPHA from [RFC5234]), a processor SHOULD generate a warning and return null.
    {result, active_context, defined} =
      if keyword_form?(value) do
        {nil, active_context, defined}
      else
        # 3)
        {active_context, defined} =
          if local_context && local_context[value] && defined[value] != true do
            local_def = local_context[value]

            Context.TermDefinition.create(
              active_context,
              local_context,
              value,
              local_def,
              defined,
              options
            )
          else
            {active_context, defined}
          end

        {result, active_context, defined} =
          cond do
            # 4) If active context has a term definition for value, and the associated IRI mapping is a keyword, return that keyword.
            (term_def = active_context.term_defs[value]) && JSON.LD.keyword?(term_def.iri_mapping) ->
              {term_def.iri_mapping || :halt, active_context, defined}

            # 5) If vocab is true and the active context has a term definition for value, return the associated IRI mapping.
            vocab && Map.has_key?(active_context.term_defs, value) ->
              result =
                ((term_def = active_context.term_defs[value]) && term_def.iri_mapping) || :halt

              {result, active_context, defined}

            # 6) If value contains a colon (:) anywhere after the first character, it is either an IRI, a compact IRI, or a blank node identifier:
            value |> String.slice(1..-1//1) |> String.contains?(":") ->
              case compact_iri_parts(value) do
                [prefix, suffix] ->
                  # 6.3)
                  {active_context, defined} =
                    if local_context && local_context[prefix] && defined[prefix] != true do
                      local_def = local_context[prefix]

                      Context.TermDefinition.create(
                        active_context,
                        local_context,
                        prefix,
                        local_def,
                        defined,
                        options
                      )
                    else
                      {active_context, defined}
                    end

                  result =
                    cond do
                      # 6.4)
                      (prefix_def = active_context.term_defs[prefix]) &&
                        prefix_def.iri_mapping &&
                          prefix_def.prefix_flag ->
                        prefix_def.iri_mapping <> suffix

                      # 6.5)
                      IRI.absolute?(value) ->
                        value

                      true ->
                        nil
                    end

                  {result, active_context, defined}

                nil ->
                  # 6.2)
                  {value, active_context, defined}
              end

            true ->
              {nil, active_context, defined}
          end

        cond do
          result == :halt ->
            {nil, active_context, defined}

          result ->
            {result, active_context, defined}

          # 7) If vocab is true, and active context has a vocabulary mapping, return the result of concatenating the vocabulary mapping with value.
          vocab && active_context.vocabulary_mapping ->
            vocabulary_mapping = active_context.vocabulary_mapping
            {vocabulary_mapping <> value, active_context, defined}

          # 8) Otherwise, if document relative is true, set value to the result of resolving value against the base IRI. Only the basic algorithm in section 5.2 of [RFC3986] is used; neither Syntax-Based Normalization nor Scheme-Based Normalization are performed. Characters additionally allowed in IRI references are treated in the same way that unreserved characters are treated in URI references, per section 6.5 of [RFC3987].
          doc_relative ->
            {absolute_iri(value, Context.base(active_context)), active_context, defined}

          # 9) Return value as is.
          true ->
            {value, active_context, defined}
        end
      end

    if local_context do
      {result, active_context, defined}
    else
      result
    end
  end

  def expand_iri(invalid, _, _, _, _, _, _), do: invalid
end
