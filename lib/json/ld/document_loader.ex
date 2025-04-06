defmodule JSON.LD.DocumentLoader do
  @moduledoc """
  Behaviour for document loaders used to retrieve remote documents and contexts.

  as specified at <https://www.w3.org/TR/json-ld-api/#idl-def-LoadDocumentCallback>
  """

  alias JSON.LD.DocumentLoader.{Default, RemoteDocument}
  alias JSON.LD.Options

  @callback load(String.t(), Options.t()) :: {:ok, RemoteDocument.t()} | {:error, any}

  def load(url, %Options{document_loader: nil} = options), do: Default.load(url, options)
  def load(url, %Options{document_loader: loader} = options), do: loader.load(url, options)
end
