defmodule JSON.LD.DocumentLoader.RemoteDocument do
  @moduledoc """
  A struct for remote documents.

  See: https://www.w3.org/TR/json-ld11-api/#remotedocument
  """
  @type t :: %__MODULE__{
          context_url: String.t() | nil,
          document_url: String.t(),
          document: any,
          content_type: String.t(),
          profile: String.t() | nil
        }
  defstruct [:context_url, :document_url, :document, :content_type, :profile]
end
