defmodule JSON.LD.DocumentLoader.Default do
  @moduledoc """
  Default implementation of the `JSON.LD.DocumentLoader` behaviour.
  """

  @behaviour JSON.LD.DocumentLoader

  alias JSON.LD.DocumentLoader.RemoteDocument
  alias JSON.LD.Options

  @spec load(String.t(), Options.t()) :: {:ok, RemoteDocument.t()} | {:error, any}
  def load(url, _options) do
    with {:ok, res} <- http_get(url),
         {:ok, data} <- Jason.decode(res.body) do
      {:ok, %RemoteDocument{document: data, document_url: res.request_url}}
    end
  end

  @spec http_get(String.t()) ::
          {:ok, HTTPoison.Response.t() | HTTPoison.AsyncResponse.t()} | {:error, any}
  defp http_get(url) do
    HTTPoison.get(url, [accept: "application/ld+json"], follow_redirect: true)
  rescue
    e -> {:error, "HTTPoison failed: #{inspect(e)}"}
  end
end
