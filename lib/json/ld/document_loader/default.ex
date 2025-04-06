defmodule JSON.LD.DocumentLoader.Default do
  @moduledoc """
  Default implementation of the `JSON.LD.DocumentLoader` behaviour.

  This module provides the standard document loader that follows the JSON-LD 1.1
  specification for Remote Document and Context Retrieval. It delegates the actual
  loading logic to `JSON.LD.DocumentLoader.RemoteDocument`.

  See: https://www.w3.org/TR/json-ld11-api/#remote-document-and-context-retrieval
  """

  @behaviour JSON.LD.DocumentLoader

  alias JSON.LD.DocumentLoader.RemoteDocument
  alias JSON.LD.Options

  @spec load(String.t(), Options.convertible()) :: {:ok, RemoteDocument.t()} | {:error, any}
  def load(url, options \\ []) do
    RemoteDocument.load(url, options)
  end
end
