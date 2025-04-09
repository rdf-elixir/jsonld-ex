defmodule JSON.LD.RemoteContextTest do
  use JSON.LD.Case, async: false

  alias JSON.LD.{DocumentLoader, Options}

  setup_all do
    local =
      Jason.decode!("""
        {
          "@context": {
            "name": "http://xmlns.com/foaf/0.1/name",
            "homepage": {"@id": "http://xmlns.com/foaf/0.1/homepage", "@type": "@id"}
          },
          "name": "Manu Sporny",
          "homepage": "http://manu.sporny.org/"
        }
      """)

    remote =
      Jason.decode!("""
        {
          "@context": "http://example.com/test-context",
          "name": "Manu Sporny",
          "homepage": "http://manu.sporny.org/"
        }
      """)

    {:ok, local: local, remote: remote}
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
      Jason.decode!("""
        {
          "@context": "http://fake.com/fake-context",
          "name": "Manu Sporny",
          "homepage": "http://manu.sporny.org/"
        }
      """)

    assert_raise_json_ld_error "loading remote context failed", fn ->
      JSON.LD.flatten(remote, nil, %Options{document_loader: DocumentLoader.Test})
    end
  end

  describe "@import functionality" do
    setup do
      bypass = Bypass.open()
      {:ok, bypass: bypass}
    end

    test "loads a remote context via @import", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert "GET" == conn.method
        assert "/context" == conn.request_path

        json_content =
          Jason.encode!(%{
            "@context": %{
              imported: "http://example.org/imported"
            }
          })

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, json_content)
      end)

      context =
        JSON.LD.context(%{
          "@version": 1.1,
          "@import": "http://localhost:#{bypass.port}/context"
        })

      assert context.term_defs["imported"]
      assert context.term_defs["imported"].iri_mapping == "http://example.org/imported"
    end

    test "merges @import with local context", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert "GET" == conn.method
        assert "/context" == conn.request_path

        json_content =
          Jason.encode!(%{
            "@context": %{
              imported: "http://example.org/imported",
              common: "http://example.org/common-imported"
            }
          })

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, json_content)
      end)

      context =
        JSON.LD.context(%{
          "@version": 1.1,
          "@import": "http://localhost:#{bypass.port}/context",
          local: "http://example.org/local",
          common: "http://example.org/common-local"
        })

      assert context.term_defs["imported"].iri_mapping == "http://example.org/imported"
      assert context.term_defs["local"].iri_mapping == "http://example.org/local"
      # Later contexts override earlier ones
      assert context.term_defs["common"].iri_mapping == "http://example.org/common-local"
    end

    test "rejects non-string @import value" do
      assert_raise_json_ld_error "invalid @import value", fn ->
        JSON.LD.context(%{
          "@version": 1.1,
          "@import": true
        })
      end
    end

    test "loads @import within a nested context", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert "GET" == conn.method
        assert "/context" == conn.request_path

        json_content =
          Jason.encode!(%{
            "@context": %{
              imported: "http://example.org/imported"
            }
          })

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, json_content)
      end)

      input = %{
        "@context" => %{
          "@version" => 1.1,
          "term" => %{
            "@id" => "http://example.org/term",
            "@context" => %{
              "@import" => "http://localhost:#{bypass.port}/context"
            }
          }
        },
        "term" => %{
          "imported" => "value"
        }
      }

      expanded = JSON.LD.expand(input)

      assert expanded == [
               %{
                 "http://example.org/term" => [
                   %{"http://example.org/imported" => [%{"@value" => "value"}]}
                 ]
               }
             ]
    end

    test "handles @import in an array context", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert "GET" == conn.method
        assert "/context" == conn.request_path

        json_content =
          Jason.encode!(%{
            "@context": %{
              imported: "http://example.org/imported"
            }
          })

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, json_content)
      end)

      context =
        JSON.LD.context([
          %{
            "@version": 1.1,
            "@import": "http://localhost:#{bypass.port}/context"
          },
          %{
            "local" => "http://example.org/local"
          }
        ])

      assert context.term_defs["imported"].iri_mapping == "http://example.org/imported"
      assert context.term_defs["local"].iri_mapping == "http://example.org/local"
    end
  end
end
