defmodule JSON.LD.DocumentLoader.Default do
  @behaviour JSON.LD.DocumentLoader

  alias JSON.LD.DocumentLoader.RemoteDocument

  def load(url, _options) do
    with {:ok, res} <- HTTPoison.get(url, [accept: "application/ld+json"], follow_redirect: true),
         {:ok, data} <- Jason.decode(res.body) do
      {:ok, %RemoteDocument{document: data, document_url: res.request_url}}
    end
  end
end
