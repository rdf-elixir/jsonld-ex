defmodule JSON.LD.Options do
  @moduledoc """
  Options accepted by the JSON-LD processing algorithms.

  as specified at <https://www.w3.org/TR/json-ld-api/#the-jsonldoptions-type>
  """

  alias RDF.IRI

  @type t :: %__MODULE__{
          base: String.t() | nil,
          compact_arrays: boolean,
          document_loader: nil,
          expand_context: map | nil,
          produce_generalized_rdf: boolean,
          use_rdf_type: boolean,
          use_native_types: boolean,
          processing_mode: String.t()
        }

  @type convertible :: t | keyword | Enum.t()

  defstruct base: nil,
            compact_arrays: true,
            document_loader: nil,
            expand_context: nil,
            produce_generalized_rdf: false,
            use_rdf_type: false,
            use_native_types: false,
            processing_mode: "json-ld-1.0"

  @spec new :: t
  def new, do: %__MODULE__{}

  @spec new(convertible) :: t
  def new(%__MODULE__{} = options), do: options

  def new(options) do
    struct(__MODULE__, options)
    |> set_base(options[:base])
  end

  @spec set_base(t, IRI.coercible()) :: t
  def set_base(%__MODULE__{} = options, base) do
    %__MODULE__{options | base: base && base |> IRI.coerce_base() |> to_string()}
  end
end
