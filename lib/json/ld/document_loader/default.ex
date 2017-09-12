defmodule JSON.LD.DocumentLoader.Default do
  @behaviour JSON.LD.DocumentLoader

  alias JSON.LD.DocumentLoader.RemoteDocument

  def load(url, _options) do
    with {:ok, res} <- HTTPoison.get(url, [accept: "application/ld+json"],
                                     [follow_redirect: true]),
         {:ok, data} <- Poison.decode(res.body)
    do
      result = %RemoteDocument{
        document: data,
        document_url: res.request_url,
      }
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
