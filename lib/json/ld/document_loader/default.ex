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
    with {:ok, response} <-
           HTTPoison.get(url, [accept: "application/ld+json"], follow_redirect: true) do
      case url_from_link_header(response) do
        nil ->
          {:ok, response}

        url ->
          http_get(url)
      end
    end
  rescue
    e -> {:error, "HTTPoison failed: #{inspect(e)}"}
  end

  @spec url_from_link_header(HTTPoison.Response.t()) :: String.t() | nil
  defp url_from_link_header(response) do
    response.headers
    |> Enum.find(fn {name, _} -> name == "Link" end)
    |> case do
      nil ->
        nil

      {"Link", content} ->
        with {url, props} <- parse_link_header(content) do
          if match?(%{"rel" => "alternate", "type" => "application/ld+json"}, props) do
            if String.starts_with?(url, "http") do
              url
            else
              # Relative path
              response.request.url
              |> URI.parse()
              |> Map.put(:path, url)
              |> URI.to_string()
            end
          end
        end
    end
  end

  @spec parse_link_header(String.t()) :: {String.t(), map()} | nil
  defp parse_link_header(content) do
    [first | prop_strings] = String.split(content, ~r/\s*;\s*/)

    with [_, url] <- Regex.run(~r/\A<([^>]+)>\Z/, first) do
      props =
        Map.new(prop_strings, fn prop_string ->
          [_, key, value] = Regex.run(~r/\A([^=]+)=\"([^\"]+)\"\Z/, prop_string)

          {key, value}
        end)

      {url, props}
    end
  end
end
