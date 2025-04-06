defmodule JSON.LD.IRICompactionTest do
  use JSON.LD.Case, async: false

  import JSON.LD.Compaction, only: [compact_iri: 3, compact_iri: 5]

  setup do
    context =
      context_with_inverse(%{
        "@base" => "http://base/",
        "xsd" => "http://www.w3.org/2001/XMLSchema#",
        "ex" => "http://example.org/",
        "rex" => %{"@reverse" => "ex"},
        "lex" => %{"@id" => "ex", "@language" => "en"},
        "tex" => %{"@id" => "ex", "@type" => "xsd:string"},
        "exp" => %{"@id" => "ex:pert"},
        "experts" => %{"@id" => "ex:perts"}
      })
      |> JSON.LD.Context.set_inverse()

    %{example_context: context, options: JSON.LD.Options.new([])}
  end

  describe "with vocab: false" do
    %{
      "nil" => [nil, nil],
      "absolute IRI" => ["http://example.com/", "http://example.com/"],
      "prefix:suffix" => ["ex:suffix", "http://example.org/suffix"],
      "unmapped" => ["foo", "foo"],
      "bnode" => ["_:a", "_:a"],
      "relative" => ["foo/bar", "http://base/foo/bar"]
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: [result, input], example_context: context, options: options} do
        assert compact_iri(input, context, options, nil, false) == result
      end
    end)
  end

  describe "with vocab: true" do
    %{
      "absolute IRI" => ["http://example.com/", "http://example.com/"],
      "prefix:suffix" => ["ex:suffix", "http://example.org/suffix"],
      "keyword" => ["@type", "@type"],
      "unmapped" => ["foo", "foo"],
      "bnode" => ["_:a", "_:a"],
      "relative" => ["http://base/foo/bar", "http://base/foo/bar"],
      "odd CURIE" => ["experts", "http://example.org/perts"]
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: [result, input], example_context: context, options: options} do
        assert compact_iri(input, context, options, nil, true) == result
      end
    end)
  end

  describe "with @vocab" do
    setup %{example_context: ld_context} = context do
      ld_context =
        %JSON.LD.Context{ld_context | vocab: "http://example.org/"}
        |> JSON.LD.Context.set_inverse()

      %{context | example_context: ld_context}
    end

    %{
      "absolute IRI" => ["http://example.com/", "http://example.com/"],
      "prefix:suffix" => ["suffix", "http://example.org/suffix"],
      "keyword" => ["@type", "@type"],
      "unmapped" => ["foo", "foo"],
      "bnode" => ["_:a", "_:a"],
      "relative" => ["http://base/foo/bar", "http://base/foo/bar"],
      "odd CURIE" => ["experts", "http://example.org/perts"]
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{
        data: [result, input],
        example_context: context,
        options: options
      } do
        assert compact_iri(input, context, options, nil, true) == result
      end
    end)
  end

  describe "with value" do
    setup do
      context =
        context_with_inverse(%{
          "xsd" => XSD.__base_iri__(),
          "plain" => "http://example.com/plain",
          "lang" => %{"@id" => "http://example.com/lang", "@language" => "en"},
          "dir" => %{"@id" => "http://example.com/dir", "@direction" => "ltr"},
          "langdir" => %{
            "@id" => "http://example.com/langdir",
            "@language" => "en",
            "@direction" => "ltr"
          },
          "bool" => %{"@id" => "http://example.com/bool", "@type" => "xsd:boolean"},
          "integer" => %{"@id" => "http://example.com/integer", "@type" => "xsd:integer"},
          "double" => %{"@id" => "http://example.com/double", "@type" => "xsd:double"},
          "date" => %{"@id" => "http://example.com/date", "@type" => "xsd:date"},
          "id" => %{"@id" => "http://example.com/id", "@type" => "@id"},
          "graph" => %{"@id" => "http://example.com/graph", "@container" => "@graph"},
          "json" => %{"@id" => "http://example.com/json", "@type" => "@json"},

          # Liste der Ruby-Stil Terminologien exakt wie im Original
          "list_plain" => %{"@id" => "http://example.com/plain", "@container" => "@list"},
          "list_lang" => %{
            "@id" => "http://example.com/lang",
            "@language" => "en",
            "@container" => "@list"
          },
          "list_bool" => %{
            "@id" => "http://example.com/bool",
            "@type" => "xsd:boolean",
            "@container" => "@list"
          },
          "list_integer" => %{
            "@id" => "http://example.com/integer",
            "@type" => "xsd:integer",
            "@container" => "@list"
          },
          "list_double" => %{
            "@id" => "http://example.com/double",
            "@type" => "xsd:double",
            "@container" => "@list"
          },
          "list_date" => %{
            "@id" => "http://example.com/date",
            "@type" => "xsd:date",
            "@container" => "@list"
          },
          "list_id" => %{
            "@id" => "http://example.com/id",
            "@type" => "@id",
            "@container" => "@list"
          },
          "list_graph" => %{
            "@id" => "http://example.com/graph",
            "@type" => "@id",
            "@container" => "@list"
          },
          "set_plain" => %{"@id" => "http://example.com/plain", "@container" => "@set"},
          "set_lang" => %{
            "@id" => "http://example.com/lang",
            "@language" => "en",
            "@container" => "@set"
          },
          "set_bool" => %{
            "@id" => "http://example.com/bool",
            "@type" => "xsd:boolean",
            "@container" => "@set"
          },
          "set_integer" => %{
            "@id" => "http://example.com/integer",
            "@type" => "xsd:integer",
            "@container" => "@set"
          },
          "set_double" => %{
            "@id" => "http://example.com/double",
            "@type" => "xsd:double",
            "@container" => "@set"
          },
          "set_date" => %{
            "@id" => "http://example.com/date",
            "@type" => "xsd:date",
            "@container" => "@set"
          },
          "set_id" => %{
            "@id" => "http://example.com/id",
            "@type" => "@id",
            "@container" => "@set"
          },
          "set_graph" => %{
            "@id" => "http://example.com/graph",
            "@container" => ["@graph", "@set"]
          },
          "map_lang" => %{"@id" => "http://example.com/lang", "@container" => "@language"},
          "set_map_lang" => %{
            "@id" => "http://example.com/lang",
            "@container" => ["@language", "@set"]
          }
        })

      %{example_context: context, options: JSON.LD.Options.new([])}
    end

    # Prefered sets and maps over non sets or maps
    %{
      "set_plain" => %{"@value" => "foo"},
      "map_lang" => %{"@value" => "en", "@language" => "en"},
      "set_bool" => %{"@value" => "true", "@type" => "http://www.w3.org/2001/XMLSchema#boolean"},
      "set_integer" => %{"@value" => "1", "@type" => "http://www.w3.org/2001/XMLSchema#integer"},
      "set_id" => %{"@id" => "http://example.org/id"},
      "graph" => %{"@graph" => [%{"@id" => "http://example.org/id"}]},
      "json" => %{"@value" => %{"some" => "json"}, "@type" => "@json"},
      "dir" => %{"@value" => "dir", "@direction" => "ltr"},
      "langdir" => %{"@value" => "lang dir", "@language" => "en", "@direction" => "ltr"}
    }
    |> Enum.each(fn {prop, value} ->
      @tag data: {prop, value}
      test "uses #{prop} for #{inspect(value)}",
           %{data: {prop, value}, example_context: context, options: options} do
        assert compact_iri(
                 "http://example.com/#{String.replace(prop, ~r/^\w+_/, "")}",
                 context,
                 options,
                 value,
                 true
               ) == prop
      end
    end)

    # @language and @type with @list
    %{
      "list_plain" => [
        [%{"@value" => "foo"}],
        [%{"@value" => "foo"}, %{"@value" => "bar"}, %{"@value" => "baz"}],
        [%{"@value" => "foo"}, %{"@value" => "bar"}, %{"@value" => 1}],
        [%{"@value" => "foo"}, %{"@value" => "bar"}, %{"@value" => 1.1}],
        [%{"@value" => "foo"}, %{"@value" => "bar"}, %{"@value" => true}],
        [%{"@value" => "de", "@language" => "de"}, %{"@value" => "jp", "@language" => "jp"}],
        [%{"@value" => true}],
        [%{"@value" => false}],
        [%{"@value" => 1}],
        [%{"@value" => 1.1}]
      ],
      "list_lang" => [[%{"@value" => "en", "@language" => "en"}]],
      "list_bool" => [[%{"@value" => "true", "@type" => to_string(XSD.boolean())}]],
      "list_integer" => [[%{"@value" => "1", "@type" => to_string(XSD.integer())}]],
      "list_double" => [[%{"@value" => "1", "@type" => to_string(XSD.double())}]],
      "list_date" => [[%{"@value" => "2012-04-17", "@type" => to_string(XSD.date())}]]
    }
    |> Enum.each(fn {prop, values} ->
      Enum.each(values, fn value ->
        @tag data: {prop, value}
        test "for @list uses #{prop} for #{inspect(%{"@list" => value})}",
             %{data: {prop, value}, example_context: context, options: options} do
          assert compact_iri(
                   "http://example.com/#{String.replace(prop, ~r/^list_/, "")}",
                   context,
                   options,
                   %{"@list" => value},
                   true
                 ) == prop
        end
      end)
    end)
  end

  describe "compact-0018" do
    setup do
      context =
        context_with_inverse(
          Jason.decode!("""
          {
            "id1": "http://example.com/id1",
            "type1": "http://example.com/t1",
            "type2": "http://example.com/t2",
            "@language": "de",
            "term": {
              "@id": "http://example.com/term"
            },
            "term1": {
              "@id": "http://example.com/term",
              "@container": "@list"
            },
            "term2": {
              "@id": "http://example.com/term",
              "@container": "@list",
              "@language": "en"
            },
            "term3": {
              "@id": "http://example.com/term",
              "@container": "@list",
              "@language": null
            },
            "term4": {
              "@id": "http://example.com/term",
              "@container": "@list",
              "@type": "type1"
            },
            "term5": {
              "@id": "http://example.com/term",
              "@container": "@list",
              "@type": "type2"
            }
          }
          """)
        )

      %{example_context: context, options: JSON.LD.Options.new([])}
    end

    %{
      "term" => [
        ~s'{ "@value": "v0.1", "@language": "de" }',
        ~s'{ "@value": "v0.2", "@language": "en" }',
        ~s'{ "@value": "v0.3"}',
        ~s'{ "@value": 4}',
        ~s'{ "@value": true}',
        ~s'{ "@value": false}'
      ],
      "term1" => """
      {
        "@list": [
          { "@value": "v1.1", "@language": "de" },
          { "@value": "v1.2", "@language": "en" },
          { "@value": "v1.3"},
          { "@value": 14},
          { "@value": true},
          { "@value": false}
        ]
      }
      """,
      "term2" => """
      {
        "@list": [
          { "@value": "v2.1", "@language": "en" },
          { "@value": "v2.2", "@language": "en" },
          { "@value": "v2.3", "@language": "en" },
          { "@value": "v2.4", "@language": "en" },
          { "@value": "v2.5", "@language": "en" },
          { "@value": "v2.6", "@language": "en" }
        ]
      }
      """,
      "term3" => """
      {
        "@list": [
          { "@value": "v3.1"},
          { "@value": "v3.2"},
          { "@value": "v3.3"},
          { "@value": "v3.4"},
          { "@value": "v3.5"},
          { "@value": "v3.6"}
        ]
      }
      """,
      "term4" => """
      {
        "@list": [
          { "@value": "v4.1", "@type": "http://example.com/t1" },
          { "@value": "v4.2", "@type": "http://example.com/t1" },
          { "@value": "v4.3", "@type": "http://example.com/t1" },
          { "@value": "v4.4", "@type": "http://example.com/t1" },
          { "@value": "v4.5", "@type": "http://example.com/t1" },
          { "@value": "v4.6", "@type": "http://example.com/t1" }
        ]
      }
      """,
      "term5" => """
      {
        "@list": [
          { "@value": "v5.1", "@type": "http://example.com/t2" },
          { "@value": "v5.2", "@type": "http://example.com/t2" },
          { "@value": "v5.3", "@type": "http://example.com/t2" },
          { "@value": "v5.4", "@type": "http://example.com/t2" },
          { "@value": "v5.5", "@type": "http://example.com/t2" },
          { "@value": "v5.6", "@type": "http://example.com/t2" }
        ]
      }
      """
    }
    |> Enum.each(fn {term, values} ->
      values =
        if is_binary(values),
          do: [values],
          else: values

      Enum.each(values, fn value ->
        value = Jason.decode!(value)
        @tag data: {term, value}
        test "uses #{term} for #{inspect(value, limit: 3)}",
             %{data: {term, value}, example_context: context, options: options} do
          assert compact_iri("http://example.com/term", context, options, value, true) ==
                   term
        end
      end)
    end)
  end

  describe "compact-0020" do
    setup do
      context =
        context_with_inverse(%{
          "ex" => "http://example.org/ns#",
          "ex:property" => %{"@container" => "@list"}
        })

      %{example_context: context, options: JSON.LD.Options.new([])}
    end

    test "Compact @id that is a property IRI when @container is @list", %{
      example_context: context,
      options: options
    } do
      assert compact_iri("http://example.org/ns#property", context, options) ==
               "ex:property"
    end
  end
end
