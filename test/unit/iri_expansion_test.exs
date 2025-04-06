defmodule JSON.LD.IRIExpansionTest do
  use JSON.LD.Case, async: false

  doctest JSON.LD.IRIExpansion

  import JSON.LD.IRIExpansion

  setup do
    context =
      JSON.LD.context(%{
        "@base" => "http://base/base",
        "@vocab" => "http://vocab/",
        "ex" => "http://example.org/",
        "_" => "http://underscore/"
      })

    %{example_context: context}
  end

  test "bnode", %{example_context: context} do
    assert expand_iri("_:a", context) == "_:a"
  end

  describe "keywords" do
    test "expands id to @id", %{example_context: context} do
      context_with_id_alias =
        JSON.LD.Context.update(
          %{context | term_defs: context.term_defs},
          %{"id" => "@id"}
        )

      assert expand_iri("id", context_with_id_alias, JSON.LD.Options.new(), false, true) == "@id"
    end

    test "expands type to @type", %{example_context: context} do
      context_with_type_alias =
        JSON.LD.Context.update(
          %{context | term_defs: context.term_defs},
          %{"type" => "@type"}
        )

      assert expand_iri("type", context_with_type_alias, JSON.LD.Options.new(), false, true) ==
               "@type"
    end
  end

  describe "relative IRI with no options" do
    %{
      "absolute IRI" => ["http://example.org/", "http://example.org/"],
      "term" => ["ex", "ex"],
      "prefix:suffix" => ["ex:suffix", "http://example.org/suffix"],
      "#frag" => ["#frag", "#frag"],
      "#frag:2" => ["#frag:2", "#frag:2"],
      "keyword" => ["@type", "@type"],
      "unmapped" => ["foo", "foo"],
      "relative" => ["foo/bar", "foo/bar"],
      "dotseg" => ["../foo/bar", "../foo/bar"],
      "empty term" => ["", ""],
      "another abs IRI" => ["ex://foo", "ex://foo"],
      "absolute IRI looking like a Compact IRI" => ["foo:bar", "foo:bar"],
      "bnode" => ["_:t0", "_:t0"],
      "_" => ["_", "_"],
      "@" => ["@", "@"]
    }
    |> Enum.each(fn {title, [input, result]} ->
      @tag data: [input, result]
      test title, %{data: [input, result], example_context: context} do
        assert expand_iri(input, context) == result
      end
    end)
  end

  describe "relative IRI with base IRI" do
    %{
      "absolute IRI" => ["http://example.org/", "http://example.org/"],
      "term" => ["ex", "http://base/ex"],
      "prefix:suffix" => ["ex:suffix", "http://example.org/suffix"],
      "#frag" => ["#frag", "http://base/base#frag"],
      "#frag:2" => ["#frag:2", "http://base/base#frag:2"],
      "keyword" => ["@type", "@type"],
      "unmapped" => ["foo", "http://base/foo"],
      "relative" => ["foo/bar", "http://base/foo/bar"],
      "dotseg" => ["../foo/bar", "http://base/foo/bar"],
      "empty term" => ["", "http://base/base"],
      "another abs IRI" => ["ex://foo", "ex://foo"],
      "absolute IRI looking like a compact IRI" => ["foo:bar", "foo:bar"],
      "bnode" => ["_:t0", "_:t0"],
      "_" => ["_", "http://base/_"],
      "@" => ["@", "http://base/@"]
    }
    |> Enum.each(fn {title, [input, result]} ->
      @tag data: [input, result]
      test title, %{data: [input, result], example_context: context} do
        assert expand_iri(input, context, JSON.LD.Options.new(), true) == result
      end
    end)
  end

  describe "relative IRI @vocab" do
    %{
      "absolute IRI" => ["http://example.org/", "http://example.org/"],
      "term" => ["ex", "http://example.org/"],
      "prefix:suffix" => ["ex:suffix", "http://example.org/suffix"],
      "#frag" => ["#frag", "http://vocab/#frag"],
      "#frag:2" => ["#frag:2", "http://vocab/#frag:2"],
      "keyword" => ["@type", "@type"],
      "unmapped" => ["foo", "http://vocab/foo"],
      "relative" => ["foo/bar", "http://vocab/foo/bar"],
      "dotseg" => ["../foo/bar", "http://vocab/../foo/bar"],
      "another abs IRI" => ["ex://foo", "ex://foo"],
      "absolute IRI looking like a compact IRI" => ["foo:bar", "foo:bar"],
      "bnode" => ["_:t0", "_:t0"],
      "_" => ["_", "http://underscore/"],
      "@" => ["@", "http://vocab/@"]
    }
    |> Enum.each(fn {title, [input, result]} ->
      @tag data: [input, result]
      test title, %{data: [input, result], example_context: context} do
        assert expand_iri(input, context, JSON.LD.Options.new(), false, true) == result
      end
    end)
  end

  describe "@vocab set to ''" do
    setup do
      context =
        JSON.LD.context(%{
          "@base" => "http://base/base",
          "@vocab" => "",
          "ex" => "http://example.org/",
          "_" => "http://underscore/"
        })

      %{example_context: context}
    end

    %{
      "absolute IRI" => ["http://example.org/", "http://example.org/"],
      "term" => ["ex", "http://example.org/"],
      "prefix:suffix" => ["ex:suffix", "http://example.org/suffix"],
      "#frag" => ["#frag", "http://base/base#frag"],
      "#frag:2" => ["#frag:2", "http://base/base#frag:2"],
      "keyword" => ["@type", "@type"],
      "unmapped" => ["foo", "http://base/basefoo"],
      "relative" => ["foo/bar", "http://base/basefoo/bar"],
      "dotseg" => ["../foo/bar", "http://base/base../foo/bar"],
      "another abs IRI" => ["ex://foo", "ex://foo"],
      "absolute IRI looking like a compact IRI" => ["foo:bar", "foo:bar"],
      "bnode" => ["_:t0", "_:t0"],
      "_" => ["_", "http://underscore/"]
    }
    |> Enum.each(fn {title, [input, result]} ->
      @tag data: [input, result]
      test title, %{data: [input, result], example_context: context} do
        assert expand_iri(input, context, JSON.LD.Options.new(), false, true) == result
      end
    end)
  end

  test "expand-0110" do
    ctx =
      JSON.LD.context(%{
        "@base" => "http://example.com/some/deep/directory/and/file/",
        "@vocab" => "/relative"
      })

    assert expand_iri("#fragment-works", ctx, JSON.LD.Options.new(), false, true) ==
             "http://example.com/relative#fragment-works"
  end
end
