defmodule JSON.LD.DocumentLoader.RemoteDocument do
  @moduledoc """
  A struct for remote documents.
  """

  @type t :: %__MODULE__{
          context_url: String.t(),
          document_url: String.t(),
          document: any
        }

  defstruct [:context_url, :document_url, :document]
end
