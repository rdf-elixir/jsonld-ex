defmodule JSON.LD.Context.TermDefinition do
  @type t :: %__MODULE__{
          iri_mapping: String.t() | nil,
          reverse_property: boolean,
          type_mapping: boolean,
          language_mapping: boolean,
          container_mapping: nil
        }

  defstruct iri_mapping: nil,
            reverse_property: false,
            type_mapping: false,
            language_mapping: false,
            container_mapping: nil
end
