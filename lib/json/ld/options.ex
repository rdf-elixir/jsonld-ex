defmodule JSON.LD.Options do
  @moduledoc """
  Options accepted by the JSON-LD processing algorithms.

  as specified at <https://www.w3.org/TR/json-ld-api/#the-jsonldoptions-type>
  """

  defstruct base: nil,
            compact_arrays: true,
            document_loader: nil,
            expand_context: nil,
            produce_generalized_rdf: false,
            processing_mode: "json-ld-1.0"

  def new(), do: %JSON.LD.Options{}
  def new(%JSON.LD.Options{} = options), do: options
  def new(options), do: struct(JSON.LD.Options, options)

end
