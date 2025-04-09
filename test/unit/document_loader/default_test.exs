# credo:disable-for-this-file Credo.Check.Readability.LargeNumbers

defmodule JSON.LD.DocumentLoader.DefaultTest do
  use ExUnit.Case, async: false

  setup do
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

    {:ok, local: local}
  end

  test "loads remote context (with 200 response code)", %{local: local} do
    bypass = Bypass.open()

    Bypass.expect(bypass, fn conn ->
      assert "GET" == conn.method
      assert "/test-context" == conn.request_path

      context = %{
        "@context" => %{
          "homepage" => %{"@id" => "http://xmlns.com/foaf/0.1/homepage", "@type" => "@id"},
          "name" => "http://xmlns.com/foaf/0.1/name"
        }
      }

      conn
      |> Plug.Conn.put_resp_header("content-type", "application/json")
      |> Plug.Conn.resp(200, Jason.encode!(context))
    end)

    remote =
      Jason.decode!("""
        {
          "@context": "http://localhost:#{bypass.port}/test-context",
          "name": "Manu Sporny",
          "homepage": "http://manu.sporny.org/"
        }
      """)

    assert JSON.LD.expand(local) == JSON.LD.expand(remote)
  end

  test "loads remote context (with 302 response code)", %{local: local} do
    bypass1 = Bypass.open(port: 44887)
    bypass2 = Bypass.open(port: 44888)

    Bypass.expect(bypass1, fn conn ->
      assert "GET" == conn.method
      assert "/test1-context" == conn.request_path

      conn
      |> Plug.Conn.put_resp_header("Location", "http://localhost:#{bypass2.port}/test2-context")
      |> Plug.Conn.resp(302, "Found")
    end)

    Bypass.expect(bypass2, fn conn ->
      assert "GET" == conn.method
      assert "/test2-context" == conn.request_path

      context = %{
        "@context" => %{
          "homepage" => %{"@id" => "http://xmlns.com/foaf/0.1/homepage", "@type" => "@id"},
          "name" => "http://xmlns.com/foaf/0.1/name"
        }
      }

      conn
      |> Plug.Conn.put_resp_header("Content-Type", "application/json")
      |> Plug.Conn.resp(200, Jason.encode!(context))
    end)

    remote =
      Jason.decode!("""
        {
          "@context": "http://localhost:#{bypass1.port}/test1-context",
          "name": "Manu Sporny",
          "homepage": "http://manu.sporny.org/"
        }
      """)

    assert JSON.LD.expand(local) == JSON.LD.expand(remote)
  end

  test "loads remote context (with Link header, absolute URL)", %{local: local} do
    bypass1 = Bypass.open(port: 44887)
    bypass2 = Bypass.open(port: 44888)

    Bypass.expect(bypass1, fn conn ->
      assert "GET" == conn.method
      assert "/test1-context" == conn.request_path

      conn
      |> Plug.Conn.put_resp_header("Content-Type", "text/html")
      |> Plug.Conn.put_resp_header(
        "Link",
        "<http://localhost:#{bypass2.port}/test2-context>; rel=\"alternate\"; type=\"application/ld+json\""
      )
      |> Plug.Conn.resp(200, "<html>Not here!</html>")
    end)

    Bypass.expect(bypass2, fn conn ->
      assert "GET" == conn.method
      assert "/test2-context" == conn.request_path

      context = %{
        "@context" => %{
          "homepage" => %{"@id" => "http://xmlns.com/foaf/0.1/homepage", "@type" => "@id"},
          "name" => "http://xmlns.com/foaf/0.1/name"
        }
      }

      conn
      |> Plug.Conn.put_resp_header("Content-Type", "application/ld+json")
      |> Plug.Conn.resp(200, Jason.encode!(context))
    end)

    remote =
      Jason.decode!("""
        {
          "@context": "http://localhost:#{bypass1.port}/test1-context",
          "name": "Manu Sporny",
          "homepage": "http://manu.sporny.org/"
        }
      """)

    assert JSON.LD.expand(local) == JSON.LD.expand(remote)
  end

  test "loads remote context (with Link header, relative path)", %{local: local} do
    bypass = Bypass.open(port: 44887)

    Bypass.expect(bypass, fn conn ->
      case conn.request_path do
        "/test1-context" ->
          assert "GET" == conn.method

          conn
          |> Plug.Conn.put_resp_header("Content-Type", "text/html")
          |> Plug.Conn.put_resp_header(
            "Link",
            "</test2-context>; rel=\"alternate\"; type=\"application/ld+json\""
          )
          |> Plug.Conn.resp(200, "<html>Not here!</html>")

        "/test2-context" ->
          assert "GET" == conn.method

          context = %{
            "@context" => %{
              "homepage" => %{"@id" => "http://xmlns.com/foaf/0.1/homepage", "@type" => "@id"},
              "name" => "http://xmlns.com/foaf/0.1/name"
            }
          }

          conn
          |> Plug.Conn.put_resp_header("Content-Type", "application/json")
          |> Plug.Conn.resp(200, Jason.encode!(context))

        other ->
          raise "Unexpected request: #{inspect(other)}"
      end
    end)

    remote =
      Jason.decode!("""
        {
          "@context": "http://localhost:#{bypass.port}/test1-context",
          "name": "Manu Sporny",
          "homepage": "http://manu.sporny.org/"
        }
      """)

    assert JSON.LD.expand(local) == JSON.LD.expand(remote)
  end

  test "loads remote context (invalid Link headers)", %{local: local} do
    # Should ignore the invalid Link headers in all of these cases

    bypass1 = Bypass.open(port: 44887)
    bypass2 = Bypass.open(port: 44888)

    [
      "<http://localhost:#{bypass2.port}/test2-context>; rel=\"alternate\"; type=\"text/html\"",
      "<http://localhost:#{bypass2.port}/test2-context>; rel=\"unrecognized\"; type=\"application/ld+json\"",
      "MALFORMED"
    ]
    |> Enum.each(fn link_header_content ->
      Bypass.expect(bypass1, fn conn ->
        assert "GET" == conn.method
        assert "/test1-context" == conn.request_path

        context = %{
          "@context" => %{
            "homepage" => %{"@id" => "http://xmlns.com/foaf/0.1/homepage", "@type" => "@id"},
            "name" => "http://xmlns.com/foaf/0.1/name"
          }
        }

        conn
        |> Plug.Conn.put_resp_header("Content-Type", "application/json")
        |> Plug.Conn.put_resp_header("Link", link_header_content)
        |> Plug.Conn.resp(200, Jason.encode!(context))
      end)

      remote =
        Jason.decode!("""
          {
            "@context": "http://localhost:#{bypass1.port}/test1-context",
            "name": "Manu Sporny",
            "homepage": "http://manu.sporny.org/"
          }
        """)

      assert JSON.LD.expand(local) == JSON.LD.expand(remote)
    end)
  end

  test "loads remote context referring to other remote contexts", %{local: local} do
    bypass1 = Bypass.open(port: 44887)
    bypass2 = Bypass.open(port: 44888)

    Bypass.expect(bypass1, fn conn ->
      assert "GET" == conn.method
      assert "/test1-context" == conn.request_path

      context = %{"@context": "http://localhost:#{bypass2.port}/test2-context"}

      conn
      |> Plug.Conn.put_resp_header("Content-Type", "application/json")
      |> Plug.Conn.resp(200, Jason.encode!(context))
    end)

    Bypass.expect(bypass2, fn conn ->
      assert "GET" == conn.method
      assert "/test2-context" == conn.request_path

      context = %{
        "@context" => %{
          "homepage" => %{"@id" => "http://xmlns.com/foaf/0.1/homepage", "@type" => "@id"},
          "name" => "http://xmlns.com/foaf/0.1/name"
        }
      }

      conn
      |> Plug.Conn.put_resp_header("Content-Type", "application/json")
      |> Plug.Conn.resp(200, Jason.encode!(context))
    end)

    remote =
      Jason.decode!("""
        {
          "@context": "http://localhost:#{bypass1.port}/test1-context",
          "name": "Manu Sporny",
          "homepage": "http://manu.sporny.org/"
        }
      """)

    assert JSON.LD.expand(local) == JSON.LD.expand(remote)
  end

  test "handles context link header for application/json content type" do
    bypass = Bypass.open()

    reference_doc = %{
      "@context" => %{
        "homepage" => %{"@id" => "http://xmlns.com/foaf/0.1/homepage", "@type" => "@id"},
        "name" => "http://xmlns.com/foaf/0.1/name"
      },
      "name" => "Manu Sporny",
      "homepage" => "http://manu.sporny.org/"
    }

    Bypass.expect(bypass, fn conn ->
      cond do
        conn.request_path == "/test-document" ->
          document = %{
            "name" => "Manu Sporny",
            "homepage" => "http://manu.sporny.org/"
          }

          conn
          |> Plug.Conn.put_resp_header("Content-Type", "application/json")
          |> Plug.Conn.put_resp_header(
            "Link",
            "<http://localhost:#{bypass.port}/context-document>; rel=\"http://www.w3.org/ns/json-ld#context\""
          )
          |> Plug.Conn.resp(200, Jason.encode!(document))

        conn.request_path == "/context-document" ->
          context_doc = %{
            "@context" => %{
              "homepage" => %{"@id" => "http://xmlns.com/foaf/0.1/homepage", "@type" => "@id"},
              "name" => "http://xmlns.com/foaf/0.1/name"
            }
          }

          conn
          |> Plug.Conn.put_resp_header("Content-Type", "application/ld+json")
          |> Plug.Conn.resp(200, Jason.encode!(context_doc))

        true ->
          conn
          |> Plug.Conn.resp(404, "Not Found")
      end
    end)

    {:ok, remote_doc} =
      JSON.LD.DocumentLoader.Default.load("http://localhost:#{bypass.port}/test-document")

    assert remote_doc.context_url == "http://localhost:#{bypass.port}/context-document"

    expanded_reference = JSON.LD.expand(reference_doc)

    document_to_expand = %{
      "@context" => "http://localhost:#{bypass.port}/context-document",
      "name" => "Manu Sporny",
      "homepage" => "http://manu.sporny.org/"
    }

    expanded_test = JSON.LD.expand(document_to_expand)
    assert expanded_reference == expanded_test
  end

  test "rejects multiple context link headers" do
    bypass = Bypass.open()

    Bypass.expect(bypass, fn conn ->
      document = %{
        "name" => "Manu Sporny",
        "homepage" => "http://manu.sporny.org/"
      }

      conn
      |> Plug.Conn.put_resp_header("Content-Type", "application/json")
      |> Plug.Conn.put_resp_header(
        "Link",
        "<http://localhost:#{bypass.port}/context1>; rel=\"http://www.w3.org/ns/json-ld#context\", " <>
          "<http://localhost:#{bypass.port}/context2>; rel=\"http://www.w3.org/ns/json-ld#context\""
      )
      |> Plug.Conn.resp(200, Jason.encode!(document))
    end)

    assert {:error, %JSON.LD.Error{code: "multiple context link headers"}} =
             JSON.LD.DocumentLoader.Default.load("http://localhost:#{bypass.port}/test-context")
  end

  test "ignores context link header for application/ld+json content type", %{local: local} do
    bypass = Bypass.open()

    Bypass.expect(bypass, fn conn ->
      assert "GET" == conn.method
      assert "/test-context" == conn.request_path

      document = %{
        "@context" => %{
          "homepage" => %{"@id" => "http://xmlns.com/foaf/0.1/homepage", "@type" => "@id"},
          "name" => "http://xmlns.com/foaf/0.1/name"
        },
        "name" => "Manu Sporny",
        "homepage" => "http://manu.sporny.org/"
      }

      conn
      |> Plug.Conn.put_resp_header("Content-Type", "application/ld+json")
      |> Plug.Conn.put_resp_header(
        "Link",
        "<http://localhost:#{bypass.port}/different-context>; rel=\"http://www.w3.org/ns/json-ld#context\""
      )
      |> Plug.Conn.resp(200, Jason.encode!(document))
    end)

    remote =
      Jason.decode!("""
        {
          "@context": "http://localhost:#{bypass.port}/test-context",
          "name": "Manu Sporny",
          "homepage": "http://manu.sporny.org/"
        }
      """)

    assert JSON.LD.expand(local) == JSON.LD.expand(remote)
  end

  test "supports profile parameter in content type", %{local: _local} do
    bypass = Bypass.open()

    Bypass.expect(bypass, fn conn ->
      assert "GET" == conn.method
      assert "/test-context" == conn.request_path

      document = %{
        "@context" => %{
          "homepage" => %{"@id" => "http://xmlns.com/foaf/0.1/homepage", "@type" => "@id"},
          "name" => "http://xmlns.com/foaf/0.1/name"
        },
        "name" => "Manu Sporny",
        "homepage" => "http://manu.sporny.org/",
        "profileInfo" => "This document uses a profile"
      }

      conn
      |> Plug.Conn.put_resp_header(
        "Content-Type",
        "application/ld+json;profile=\"http://example.org/profile\""
      )
      |> Plug.Conn.resp(200, Jason.encode!(document))
    end)

    remote =
      Jason.decode!("""
        {
          "@context": "http://localhost:#{bypass.port}/test-context",
          "name": "Manu Sporny",
          "homepage": "http://manu.sporny.org/"
        }
      """)

    {:ok, remote_doc} =
      JSON.LD.DocumentLoader.Default.load("http://localhost:#{bypass.port}/test-context")

    assert remote_doc.profile == "http://example.org/profile"

    JSON.LD.expand(remote)
  end

  test "supports request profile parameter", %{local: _local} do
    bypass = Bypass.open()

    remote_document =
      %{
        "@context" => %{
          "homepage" => %{"@id" => "http://xmlns.com/foaf/0.1/homepage", "@type" => "@id"},
          "name" => "http://xmlns.com/foaf/0.1/name"
        },
        "name" => "Manu Sporny",
        "homepage" => "http://manu.sporny.org/"
      }

    Bypass.expect(bypass, fn conn ->
      assert "GET" == conn.method
      assert "/test-context" == conn.request_path

      accept_header =
        Enum.find_value(conn.req_headers, fn
          {"accept", value} -> value
          _ -> nil
        end)

      assert accept_header &&
               String.contains?(accept_header, "profile=\"http://example.org/requested-profile\"")

      conn
      |> Plug.Conn.put_resp_header("Content-Type", "application/ld+json")
      |> Plug.Conn.resp(200, Jason.encode!(remote_document))
    end)

    remote_doc_url = "http://localhost:#{bypass.port}/test-context"

    assert JSON.LD.DocumentLoader.Default.load(
             remote_doc_url,
             request_profile: "http://example.org/requested-profile"
           ) ==
             {:ok,
              %JSON.LD.DocumentLoader.RemoteDocument{
                profile: nil,
                document_url: remote_doc_url,
                document: remote_document,
                context_url: nil,
                content_type: "application/ld+json"
              }}
  end
end
