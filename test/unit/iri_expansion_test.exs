defmodule JSON.LD.IRIExpansionTest do
  use ExUnit.Case, async: false

  import JSON.LD.IRIExpansion

  setup do
    context =
      JSON.LD.context(%{
        "@base" => "http://base/",
        "@vocab" => "http://vocab/",
        "ex" => "http://example.org/",
        "" => "http://empty/",
        "_" => "http://underscore/"
      })

    %{example_context: context}
  end

  test "bnode", %{example_context: context} do
    assert expand_iri("_:a", context) == "_:a"
  end

  describe "relative IRI with no options" do
    # TODO: Test this with RDF.URIs and RDF.BlankNodes
    #    %{
    #      "absolute IRI" =>  ["http://example.org/", ~I<http://example.org/>],
    #      "term" =>          ["ex",                  ~I<ex>],
    #      "prefix:suffix" => ["ex:suffix",           ~I<http://example.org/suffix>],
    #      "keyword" =>       ["@type",               "@type"],
    #      "empty" =>         [":suffix",             ~I<http://empty/suffix>],
    #      "unmapped" =>      ["foo",                 ~I<foo>],
    #      "empty term" =>    ["",                    ~I<>],
    #      "another abs IRI"=>["ex://foo",            ~I<ex://foo>],
    #      "absolute IRI looking like a curie" =>
    #                         ["foo:bar",             ~I<foo:bar>],
    #      "bnode" =>         ["_:t0",                RDF.bnode("t0")],
    #      "_" =>             ["_",                   ~I<_>],
    #    }
    %{
      "absolute IRI" => ["http://example.org/", "http://example.org/"],
      "term" => ["ex", "ex"],
      "prefix:suffix" => ["ex:suffix", "http://example.org/suffix"],
      "keyword" => ["@type", "@type"],
      "empty" => [":suffix", "http://empty/suffix"],
      "unmapped" => ["foo", "foo"],
      "empty term" => ["", ""],
      "another abs IRI" => ["ex://foo", "ex://foo"],
      "absolute IRI looking like a curie" => ["foo:bar", "foo:bar"],
      "bnode" => ["_:t0", "_:t0"],
      "_" => ["_", "_"]
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: [input, result], example_context: context} do
        assert expand_iri(input, context) == result
      end
    end)
  end

  describe "relative IRI with base IRI" do
    # TODO: Test this with RDF.URIs and RDF.BlankNodes
    #    %{
    #      "absolute IRI" =>  ["http://example.org/", ~I<http://example.org/>],
    #      "term" =>          ["ex",                  ~I<http://base/ex>],
    #      "prefix:suffix" => ["ex:suffix",           ~I<http://example.org/suffix>],
    #      "keyword" =>       ["@type",               "@type"],
    #      "empty" =>         [":suffix",             ~I<http://empty/suffix>],
    #      "unmapped" =>      ["foo",                 ~I<http://base/foo>],
    #      "empty term" =>    ["",                    ~I<http://base/>],
    #      "another abs IRI"=>["ex://foo",            ~I<ex://foo>],
    #      "absolute IRI looking like a curie" =>
    #                         ["foo:bar",             ~I<foo:bar>],
    #      "bnode" =>         ["_:t0",                RDF.bnode("t0")],
    #      "_" =>             ["_",                   ~I<http://base/_>],
    #    }
    %{
      "absolute IRI" => ["http://example.org/", "http://example.org/"],
      "term" => ["ex", "http://base/ex"],
      "prefix:suffix" => ["ex:suffix", "http://example.org/suffix"],
      "keyword" => ["@type", "@type"],
      "empty" => [":suffix", "http://empty/suffix"],
      "unmapped" => ["foo", "http://base/foo"],
      "empty term" => ["", "http://base/"],
      "another abs IRI" => ["ex://foo", "ex://foo"],
      "absolute IRI looking like a curie" => ["foo:bar", "foo:bar"],
      "bnode" => ["_:t0", "_:t0"],
      "_" => ["_", "http://base/_"]
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: [input, result], example_context: context} do
        assert expand_iri(input, context, true) == result
      end
    end)
  end

  describe "relative IRI @vocab" do
    # TODO: Test this with RDF.URIs and RDF.BlankNodes
    #    %{
    #      "absolute IRI" =>  ["http://example.org/", ~I<http://example.org/>],
    #      "term" =>          ["ex",                  ~I<http://example.org/>],
    #      "prefix:suffix" => ["ex:suffix",           ~I<http://example.org/suffix>],
    #      "keyword" =>       ["@type",               "@type"],
    #      "empty" =>         [":suffix",             ~I<http://empty/suffix>],
    #      "unmapped" =>      ["foo",                 ~I<http://vocab/foo>],
    #      "empty term" =>    ["",                    ~I<http://empty/>],
    #      "another abs IRI"=>["ex://foo",            ~I<ex://foo>],
    #      "absolute IRI looking like a curie" =>
    #                         ["foo:bar",             ~I<foo:bar>],
    #      "bnode" =>         ["_:t0",                RDF.bode("t0")],
    #      "_" =>             ["_",                   ~I<http://underscore/>],
    #    }
    %{
      "absolute IRI" => ["http://example.org/", "http://example.org/"],
      "term" => ["ex", "http://example.org/"],
      "prefix:suffix" => ["ex:suffix", "http://example.org/suffix"],
      "keyword" => ["@type", "@type"],
      "empty" => [":suffix", "http://empty/suffix"],
      "unmapped" => ["foo", "http://vocab/foo"],
      "empty term" => ["", "http://empty/"],
      "another abs IRI" => ["ex://foo", "ex://foo"],
      "absolute IRI looking like a curie" => ["foo:bar", "foo:bar"],
      "bnode" => ["_:t0", "_:t0"],
      "_" => ["_", "http://underscore/"]
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: [input, result], example_context: context} do
        assert expand_iri(input, context, false, true) == result
      end
    end)
  end
end
