defmodule JSON.LD.Options do
  @moduledoc """
  Options accepted by the JSON-LD processing algorithms.

  as specified at <https://www.w3.org/TR/json-ld11-api/#the-jsonldoptions-type>
  """

  alias RDF.IRI

  @type warn_method :: :default | :ignore | :raise | :log | boolean | (binary -> any)

  @type t :: %__MODULE__{
          # The base IRI to use when expanding or compacting the document. If set, this overrides the input document's IRI.
          base: String.t() | nil,
          # If set to true, the JSON-LD processor replaces arrays with just one element with that element during compaction.
          compact_arrays: boolean,
          # Determines if IRIs are compacted relative to the base option or document location when compacting.
          compact_to_relative: boolean,
          # The callback of the loader to be used to retrieve remote documents and contexts, implementing the LoadDocumentCallback.
          # If specified, it is used to retrieve remote documents and contexts;
          # otherwise, if not specified, the processor's built-in loader is used.
          document_loader: nil,
          # A context that is used to initialize the active context when expanding a document.
          expand_context: map | nil,
          # If set to true, when extracting JSON-LD script elements from HTML, unless a specific fragment identifier is targeted, extracts all encountered JSON-LD script elements using an array form, if necessary.
          extract_all_scripts: boolean,
          # When the resulting contentType is text/html or application/xhtml+xml, this option determines the profile to use for selecting JSON-LD script elements.
          profile: String.t() | nil,
          # One or more IRIs to use in the request as a profile parameter.
          request_profile: String.t() | list(String.t()) | nil,
          # Enables
          # - special frame processing rules for the Expansion Algorithm.
          # - special rules for the Serialize RDF as JSON-LD Algorithm to use JSON-LD native types as values, where possible.
          frame_expansion: boolean,
          # If set to true, certain algorithm processing steps where indicated are ordered lexicographically. If false, order is not considered in processing.
          ordered: boolean,
          # Enables special rules for the Serialize RDF as JSON-LD Algorithm causing rdf:type properties to be kept as IRIs in the output, rather than use @type.
          use_rdf_type: boolean,
          # Causes the Serialize RDF as JSON-LD Algorithm to use native JSON values in value objects avoiding the need for an explicitly @type.
          use_native_types: boolean,
          # Determines how value objects containing a base direction are transformed to and from RDF.
          rdf_direction: String.t() | nil,
          # If set to true, the JSON-LD processor may emit blank nodes for triple predicates, otherwise they will be omitted.
          # Note: The use of blank node identifiers to label properties is obsolete, and may be removed in a future version of JSON-LD, as is the support for generalized RDF Datasets and thus the produceGeneralizedRdf option may be also be removed.
          produce_generalized_rdf: boolean,
          processing_mode: String.t(),
          warn: warn_method()
        }

  @type convertible :: t | keyword | Enum.t()

  defstruct base: nil,
            compact_arrays: true,
            compact_to_relative: true,
            document_loader: nil,
            expand_context: nil,
            extract_all_scripts: false,
            profile: nil,
            request_profile: nil,
            frame_expansion: false,
            ordered: false,
            use_rdf_type: false,
            use_native_types: false,
            rdf_direction: nil,
            produce_generalized_rdf: true,
            processing_mode: "json-ld-1.1",
            warn: :default

  def warn_default, do: Application.get_env(:json_ld, :warn, :log)

  @spec new :: t
  def new, do: %__MODULE__{}

  @spec new(convertible) :: t
  def new(%__MODULE__{} = options), do: options

  def new(options) do
    struct(__MODULE__, options)
    |> set_base(options[:base])
  end

  def extract(%__MODULE__{} = options), do: {options, []}

  def extract(options) when is_list(options) do
    processor_options = new(options)
    other_options = Keyword.drop(options, Map.keys(processor_options))
    {processor_options, other_options}
  end

  @spec set_base(t, IRI.coercible()) :: t
  def set_base(%__MODULE__{} = options, base) do
    %__MODULE__{options | base: base && base |> IRI.coerce_base() |> to_string()}
  end
end
