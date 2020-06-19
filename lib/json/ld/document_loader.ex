defmodule JSON.LD.DocumentLoader do
  @moduledoc """
  Loader used to retrieve remote documents and contexts.

  as specified at <https://www.w3.org/TR/json-ld-api/#idl-def-LoadDocumentCallback>
  """

  alias JSON.LD.DocumentLoader.RemoteDocument
  alias JSON.LD.Options

  @callback load(String.t(), Options.t()) :: {:ok, RemoteDocument.t()} | {:error, any}
end
