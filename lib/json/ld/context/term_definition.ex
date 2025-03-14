defmodule JSON.LD.Context.TermDefinition do
  @moduledoc """
  Struct for the term definitions in a `JSON.LD.Context`.
  """

  @type t :: %__MODULE__{
          iri_mapping: String.t(),
          prefix_flag: boolean,
          protected: boolean,
          reverse_property: boolean,
          base_url: nil | String.t(),
          context: nil | JSON.LD.Context.t(),
          container_mapping: nil | [String.t()],
          index_mapping: nil | String.t(),
          language_mapping: false | nil | String.t(),
          direction_mapping: false | nil | :ltr | :rtl,
          nest_value: nil | String.t(),
          type_mapping: false | nil | String.t()
        }

  defstruct iri_mapping: nil,
            prefix_flag: false,
            protected: false,
            reverse_property: false,
            context: nil,
            base_url: nil,
            container_mapping: nil,
            index_mapping: nil,
            language_mapping: false,
            direction_mapping: false,
            nest_value: nil,
            type_mapping: false

  def language(%__MODULE__{language_mapping: false}, context), do: context.default_language
  def language(%__MODULE__{language_mapping: language_mapping}, _), do: language_mapping
  def language(_, context), do: context.default_language

  def direction(%{direction_mapping: false}, context), do: context.base_direction
  def direction(%{direction_mapping: direction_mapping}, _), do: direction_mapping
  def direction(_, context), do: context.base_direction
end
