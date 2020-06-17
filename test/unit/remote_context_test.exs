defmodule JSON.LD.RemoteContextTest do
  use ExUnit.Case, async: false

  alias JSON.LD.{DocumentLoader, LoadingRemoteContextFailedError, Options}

  setup_all do
    local =
      Jason.decode! """
        {
          "@context": {
            "name": "http://xmlns.com/foaf/0.1/name",
            "homepage": {
              "@id": "http://xmlns.com/foaf/0.1/homepage",
              "@type": "@id"
            }
          },
          "name": "Manu Sporny",
          "homepage": "http://manu.sporny.org/"
        }
      """

    remote =
      Jason.decode! """
        {
          "@context": "http://example.com/test-context",
          "name": "Manu Sporny",
          "homepage": "http://manu.sporny.org/"
        }
      """

    [local: local, remote: remote]
  end

  describe "result is the same for identical local and remote contexts" do
    test "expanded form of a JSON-LD document", %{local: local, remote: remote} do
      assert JSON.LD.expand(local) ==
               JSON.LD.expand(remote, %Options{document_loader: DocumentLoader.Test})
    end

    test "flattened form of a JSON-LD document", %{local: local, remote: remote} do
      assert JSON.LD.flatten(local, nil) ==
               JSON.LD.flatten(remote, nil, %Options{document_loader: DocumentLoader.Test})
    end
  end

  test "failed loading of remote context" do
    remote =
      Jason.decode! """
        {
          "@context": "http://fake.com/fake-context",
          "name": "Manu Sporny",
          "homepage": "http://manu.sporny.org/"
        }
      """

    assert_raise LoadingRemoteContextFailedError, fn ->
      JSON.LD.flatten(remote, nil, %Options{document_loader: DocumentLoader.Test})
    end
  end
end
