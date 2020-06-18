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

      Plug.Conn.resp(conn, 200, Jason.encode!(context))
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

      Plug.Conn.resp(conn, 200, Jason.encode!(context))
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

  test "loads remote context referring to other remote contexts", %{local: local} do
    bypass1 = Bypass.open(port: 44887)
    bypass2 = Bypass.open(port: 44888)

    Bypass.expect(bypass1, fn conn ->
      assert "GET" == conn.method
      assert "/test1-context" == conn.request_path

      context = %{"@context": "http://localhost:#{bypass2.port}/test2-context"}

      Plug.Conn.resp(conn, 200, Jason.encode!(context))
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

      Plug.Conn.resp(conn, 200, Jason.encode!(context))
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
end
