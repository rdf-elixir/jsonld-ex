defmodule JSON.LD.DocumentLoader.RemoteDocument do
  @moduledoc """
  Implementation of the JSON-LD 1.1 Remote Document and Context Retrieval specification.

  This module provides both:

  1. A struct representing remote documents as specified in https://www.w3.org/TR/json-ld11-api/#remotedocument
  2. The core implementation of remote document loading according to
     <https://www.w3.org/TR/json-ld11-api/#remote-document-and-context-retrieval>

  Custom `JSON.LD.DocumentLoader` implementations can reuse this by calling `load/3` or
  implementing their own loading logic.

  ## Custom HTTP clients

  The default Tesla-based HTTP client is `JSON.LD.DocumentLoader.DefaultClient`.

  If you need a custom HTTP client with custom middleware, you can create your own module
  that implements a `client/3` function:

      defmodule MyCustomClient do
        use Tesla

        def client(headers, url, options) do
          [
            {Tesla.Middleware.Headers, headers},
            # your custom middleware
          ]
          |> Tesla.client()
        end
      end

  and configure it as:

      config :json_ld, :http_client, MyCustomClient

  """

  defstruct [:context_url, :document_url, :document, :content_type, :profile]

  @type t :: %__MODULE__{
          context_url: String.t() | nil,
          document_url: String.t(),
          document: any,
          content_type: String.t(),
          profile: String.t() | nil
        }

  alias JSON.LD.{Options, LoadingDocumentFailedError, MultipleContextLinkHeadersError}
  alias JSON.LD.DocumentLoader.DefaultClient
  alias RDF.IRI

  def default_http_client do
    Application.get_env(:json_ld, :http_client, DefaultClient)
  end

  @doc """
  Loads a remote document from the given URL.

  According to <https://www.w3.org/TR/json-ld11-api/#remote-document-and-context-retrieval>
  """
  @spec load(String.t(), Options.convertible(), module) :: {:ok, t()} | {:error, any}
  def load(url, options \\ [], http_client \\ default_http_client()) do
    do_load(url, http_client, Options.new(options))
  end

  defp do_load(url, http_client, options, visited_urls \\ []) do
    if url in visited_urls do
      {:error,
       %LoadingDocumentFailedError{
         message: "Circular reference detected in document loading"
       }}
    else
      case http_get(http_client, url, options) do
        {:ok, %Tesla.Env{status: status} = response} when status in 200..299 ->
          # 3)
          document_url = response.url
          content_type = get_content_type(response.headers)
          profile = get_profile_from_content_type(response.headers)

          cond do
            # The HTTP Link Header is ignored for documents served as application/ld+json ...
            content_type == "application/ld+json" ->
              with {:ok, document} <- parse_json(response.body) do
                {:ok,
                 %__MODULE__{
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
                     %__MODULE__{
                       document: document,
                       document_url: document_url,
                       content_type: content_type,
                       context_url: nil,
                       profile: profile
                     }}

                  {:ok, context_url} ->
                    {:ok,
                     %__MODULE__{
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
                |> to_string()
                |> do_load(http_client, options, [url | visited_urls])
              else
                # 6)
                {:error,
                 %LoadingDocumentFailedError{
                   message:
                     "Retrieved resource's Content-Type is not JSON-compatible: #{content_type}"
                 }}
              end
          end

        {:ok, %{status: status}} ->
          {:error,
           %LoadingDocumentFailedError{message: "HTTP request failed with status #{status}"}}

        {:error, _} = error ->
          error
      end
    end
  end

  def load!(url, options \\ [], http_client \\ default_http_client()) do
    case load(url, options, http_client) do
      {:ok, remote_document} -> remote_document
      {:error, error} -> raise error
    end
  end

  # 2)
  def http_get(http_client, url, options) do
    options.request_profile
    |> build_headers()
    |> http_client.client(url, options)
    |> Tesla.get(url)
  rescue
    e -> {:error, %LoadingDocumentFailedError{message: "HTTP request failed: #{inspect(e)}"}}
  end

  defp build_headers(request_profile) do
    [
      {"accept",
       if request_profile do
         "application/ld+json;profile=\"#{request_profile |> List.wrap() |> Enum.join(" ")}\", application/json"
       else
         "application/ld+json, application/json"
       end}
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
