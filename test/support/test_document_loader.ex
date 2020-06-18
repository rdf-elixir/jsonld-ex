defmodule JSON.LD.DocumentLoader.Test do
  @behaviour JSON.LD.DocumentLoader

  alias JSON.LD.DocumentLoader.RemoteDocument

  def load(url, _options) do
    with {:ok, data} <- load_context(url) do
      {:ok, %RemoteDocument{document: data, document_url: url}}
    end
  end

  defp load_context("http://example.com/test-context") do
    {:ok,
     %{
       "@context" => %{
         "homepage" => %{"@id" => "http://xmlns.com/foaf/0.1/homepage", "@type" => "@id"},
         "name" => "http://xmlns.com/foaf/0.1/name"
       }
     }}
  end

  defp load_context(_), do: {:error, :invalid_url}
end
