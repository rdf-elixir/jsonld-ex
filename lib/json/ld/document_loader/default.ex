defmodule JSON.LD.DocumentLoader.Default do
  @moduledoc """
  Default implementation of the `JSON.LD.DocumentLoader` behaviour according to
  the JSON-LD 1.1 specification for Remote Document and Context Retrieval.

  See: https://www.w3.org/TR/json-ld11-api/#remote-document-and-context-retrieval
  """

  @behaviour JSON.LD.DocumentLoader

  alias JSON.LD.DocumentLoader.RemoteDocument
  alias JSON.LD.{Options, LoadingDocumentFailedError, MultipleContextLinkHeadersError}
  alias RDF.IRI

  @spec load(String.t(), Options.convertible()) :: {:ok, RemoteDocument.t()} | {:error, any}
  def load(url, options \\ []) do
    retrieve_document(url, Options.new(options))
  end

  defp retrieve_document(url, options, visited_urls \\ []) do
    if url in visited_urls do
      {:error,
       %LoadingDocumentFailedError{
         message: "Circular reference detected in document loading"
       }}
    else
      with {:ok, response} <- http_get(url, options) do
        # 3)
        document_url = response.request.url || url
        content_type = get_content_type(response.headers)
        profile = get_profile_from_content_type(response.headers)

        cond do
          # The HTTP Link Header is ignored for documents served as application/ld+json ...
          content_type == "application/ld+json" ->
            with {:ok, document} <- parse_json(response.body) do
              {:ok,
               %RemoteDocument{
                 document: document,
                 document_url: document_url,
                 content_type: content_type,
                 context_url: nil,
                 profile: profile
               }}
            end

          # 5)
          content_type &&
              (String.starts_with?(content_type, "application/json") ||
                 String.contains?(content_type, "+json")) ->
            with {:ok, document} <- parse_json(response.body) do
              case find_context_links(response.headers) do
                {:ok, nil} ->
                  {:ok,
                   %RemoteDocument{
                     document: document,
                     document_url: document_url,
                     content_type: content_type,
                     context_url: nil,
                     profile: profile
                   }}

                {:ok, context_url} ->
                  {:ok,
                   %RemoteDocument{
                     document: document,
                     document_url: document_url,
                     content_type: content_type,
                     context_url: document_url |> IRI.merge(context_url) |> to_string(),
                     profile: profile
                   }}

                {:error, _} = error ->
                  error
              end
            end

          # 4)
          true ->
            if alternate_url = find_alternate_link(response.headers) do
              document_url
              |> IRI.merge(alternate_url)
              |> retrieve_document(options, [url | visited_urls])
            else
              # 6)
              {:error,
               %LoadingDocumentFailedError{
                 message:
                   "Retrieved resource's Content-Type is not JSON-compatible: #{content_type}"
               }}
            end
        end
      end
    end
  end

  # 2)
  defp http_get(url, options) do
    headers = build_headers(options.request_profile)
    HTTPoison.get(url, headers, follow_redirect: true)
  rescue
    e -> {:error, %LoadingDocumentFailedError{message: "HTTP request failed: #{inspect(e)}"}}
  end

  defp build_headers(request_profile) do
    [
      accept:
        if request_profile do
          "application/ld+json;profile=\"#{request_profile |> List.wrap() |> Enum.join(" ")}\", application/json"
        else
          "application/ld+json, application/json"
        end
    ]
  end

  defp get_content_type(headers) do
    case Enum.find(headers, fn {name, _} -> String.downcase(name) == "content-type" end) do
      {_, content_type} ->
        [base_type | _] = String.split(content_type, ";", parts: 2)
        String.trim(base_type)

      _ ->
        nil
    end
  end

  defp get_profile_from_content_type(headers) do
    case Enum.find(headers, fn {name, _} -> String.downcase(name) == "content-type" end) do
      {_, content_type} ->
        case Regex.run(~r/profile="?([^;"]+)"?/, content_type) do
          [_, profile] -> profile
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp find_context_links(headers) do
    headers
    |> Enum.filter(fn {name, value} ->
      String.downcase(name) == "link" &&
        String.contains?(String.downcase(value), "http://www.w3.org/ns/json-ld#context")
    end)
    |> Enum.flat_map(fn {_, value} ->
      value
      |> parse_link_headers()
      |> Enum.filter(fn {_, props} ->
        props["rel"] == "http://www.w3.org/ns/json-ld#context"
      end)
    end)
    |> case do
      [] ->
        {:ok, nil}

      [{url, _}] ->
        {:ok, url}

      _ ->
        {:error,
         %MultipleContextLinkHeadersError{
           message:
             "Multiple HTTP Link Headers using http://www.w3.org/ns/json-ld#context relation found"
         }}
    end
  end

  defp find_alternate_link(headers) do
    headers
    |> Stream.filter(fn {name, _} -> String.downcase(name) == "link" end)
    |> Stream.flat_map(fn {_, value} ->
      value
      |> parse_link_headers()
      |> Stream.filter(fn {_, props} ->
        props["rel"] == "alternate" && props["type"] == "application/ld+json"
      end)
    end)
    |> Enum.find(fn {url, _} -> url end)
    |> case do
      nil -> nil
      {url, _} -> url
    end
  end

  defp parse_link_headers(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&parse_link/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_link(link_str) do
    with [url_part | param_parts] <- String.split(link_str, ";"),
         [_, url] <- Regex.run(~r/\A\s*<([^>]+)>\s*\Z/, url_part) do
      props =
        param_parts
        |> Enum.map(&String.trim/1)
        |> Enum.map(fn param ->
          case Regex.run(~r/\A([^=]+)=(?:"([^"]+)"|([^"]\S*))\Z/, param) do
            [_, key, value] -> {String.downcase(key), value}
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Map.new()

      {url, props}
    else
      _ -> nil
    end
  end

  defp parse_json(document) do
    case Jason.decode(document) do
      {:ok, _} = ok ->
        ok

      {:error, %Jason.DecodeError{} = error} ->
        {:error,
         %LoadingDocumentFailedError{
           message: "JSON parsing failed: #{Exception.message(error)}"
         }}
    end
  end
end
