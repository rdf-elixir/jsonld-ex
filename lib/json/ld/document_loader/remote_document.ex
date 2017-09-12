defmodule JSON.LD.DocumentLoader.RemoteDocument do
  @type t :: %JSON.LD.DocumentLoader.RemoteDocument{context_url: String.t,
    document_url: String.t,
    document: any}

  defstruct context_url: nil,
    document_url: nil,
    document: nil
end
