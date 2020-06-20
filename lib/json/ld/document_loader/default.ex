defmodule JSON.LD.DocumentLoader.Default do
  @behaviour JSON.LD.DocumentLoader

  alias HTTPoison.{AsyncResponse, Response}

  alias JSON.LD.DocumentLoader.RemoteDocument
  alias JSON.LD.Options

  @spec load(String.t(), Options.t()) :: {:ok, RemoteDocument.t()} | {:error, any}
  def load(url, _options) do
    with {:ok, res} <- http_get(url),
         {:ok, data} <- Jason.decode(res.body) do
      {:ok, %RemoteDocument{document: data, document_url: res.request_url}}
    end
  end

  @spec http_get(String.t()) :: {:ok, Response.t() | AsyncResponse.t()} | {:error, any}
  defp http_get(url) do
    HTTPoison.get(url, [accept: "application/ld+json"], follow_redirect: true)
  rescue
    e -> {:error, "HTTPoison failed: #{inspect(e)}"}
  end
end
