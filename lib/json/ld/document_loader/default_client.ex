defmodule JSON.LD.DocumentLoader.DefaultClient do
  @default_max_redirects 5

  @moduledoc """
  Default Tesla HTTP client.

  This module provides a minimal HTTP client implementation.

  ## Configuration

  The maximum number of redirects to follow can be configured in your config:

      config :json_ld, :max_redirects, 10

  If not configured, it defaults to #{@default_max_redirects}.
  """

  use Tesla, docs: false

  @doc """
  Returns the configured maximum number of redirects to follow.
  """
  def default_max_redirects do
    Application.get_env(:json_ld, :max_redirects, @default_max_redirects)
  end

  @doc """
  Creates a Tesla client with the given headers and redirect handling.
  """
  def client(headers, _url, _options) do
    [
      {Tesla.Middleware.Headers, headers},
      {Tesla.Middleware.FollowRedirects, max_redirects: default_max_redirects()}
    ]
    |> Tesla.client()
  end
end
