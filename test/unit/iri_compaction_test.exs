defmodule JSON.LD.IRICompactionTest do
  use ExUnit.Case, async: false

  import JSON.LD.Compaction, only: [compact_iri: 3, compact_iri: 4, compact_iri: 5]

  alias RDF.NS.{XSD}

  setup do
    context = JSON.LD.context(%{
      "@base"   => "http://base/",
      "xsd"     => "http://www.w3.org/2001/XMLSchema#",
      "ex"      => "http://example.org/",
      ""        => "http://empty/",  # TODO: "Invalid JSON-LD syntax; a term cannot be an empty string."
      "_"       => "http://underscore/",
      "rex"     => %{"@reverse" => "ex"},
      "lex"     => %{"@id" => "ex", "@language" => "en"},
      "tex"     => %{"@id" => "ex", "@type" => "xsd:string"},
      "exp"     => %{"@id" => "ex:pert"},
      "experts" => %{"@id" => "ex:perts"}
    })
    %{example_context: context, inverse_context: JSON.LD.Context.inverse(context)}
  end

  %{
    "nil"           => [nil, nil],
    "absolute IRI"  => ["http://example.com/", "http://example.com/"],
    "prefix:suffix" => ["ex:suffix",           "http://example.org/suffix"],
    "keyword"       => ["@type",               "@type"],
    "empty"         => [":suffix",             "http://empty/suffix"],
    "unmapped"      => ["foo",                 "foo"],
    "bnode"         => ["_:a",                 "_:a"],
    "relative"      => ["foo/bar",             "http://base/foo/bar"],
    "odd CURIE"     => ["exp:s",               "http://example.org/perts"]
  }
  |> Enum.each(fn {title, data} ->
       @tag data: data
       test title, %{data: [result, input], example_context: context,
                                            inverse_context: inverse_context} do
         assert compact_iri(input, context, inverse_context) == result
       end
     end)

  describe "with :vocab option" do
    %{
      "absolute IRI"  => ["http://example.com/", "http://example.com/"],
      "prefix:suffix" => ["ex:suffix",           "http://example.org/suffix"],
      "keyword"       => ["@type",               "@type"],
      "empty"         => [":suffix",             "http://empty/suffix"],
      "unmapped"      => ["foo",                 "foo"],
      "bnode"         => ["_:a",                 "_:a"],
      "relative"      => ["http://base/foo/bar", "http://base/foo/bar"],
      "odd CURIE"     => ["experts",             "http://example.org/perts"]
    }
    |> Enum.each(fn {title, data} ->
         @tag data: data
         test title, %{data: [result, input], example_context: context,
                                              inverse_context: inverse_context} do
           assert compact_iri(input, context, inverse_context, nil, true) == result
         end
       end)
  end

  describe "with @vocab" do
    setup %{example_context: context} do
      context = %JSON.LD.Context{context | vocab: "http://example.org/"}
      %{example_context: context, inverse_context: JSON.LD.Context.inverse(context)}
    end

    %{
      "absolute IRI"  => ["http://example.com/", "http://example.com/"],
      "prefix:suffix" => ["suffix",              "http://example.org/suffix"],
      "keyword"       => ["@type",               "@type"],
      "empty"         => [":suffix",             "http://empty/suffix"],
      "unmapped"      => ["foo",                 "foo"],
      "bnode"         => ["_:a",                 "_:a"],
      "relative"      => ["http://base/foo/bar", "http://base/foo/bar"],
      "odd CURIE"     => ["experts",             "http://example.org/perts"]
    }
    |> Enum.each(fn {title, data} ->
         @tag data: data
         test title, %{data: [result, input], example_context: context,
                                              inverse_context: inverse_context} do
           assert compact_iri(input, context, inverse_context, nil, true) == result
         end
       end)

# TODO: we don't support 'position: :predicate'"
#    test "does not use @vocab if it would collide with a term" do
#      subject.set_mapping("name", "http://xmlns.com/foaf/0.1/name")
#      subject.set_mapping("ex", nil)
#      expect(subject.compact_iri("http://example.org/name", position: :predicate)).
#        to produce("lex:name", logger)
#    end
  end

  describe "with value" do
    setup do
      context = JSON.LD.context(%{
        "xsd" => XSD.__base_iri__,
        "plain" => "http://example.com/plain",
        "lang" => %{"@id" => "http://example.com/lang", "@language" => "en"},
        "bool" => %{"@id" => "http://example.com/bool", "@type" => "xsd:boolean"},
        "integer" => %{"@id" => "http://example.com/integer", "@type" => "xsd:integer"},
        "double" => %{"@id" => "http://example.com/double", "@type" => "xsd:double"},
        "date" => %{"@id" => "http://example.com/date", "@type" => "xsd:date"},
        "id" => %{"@id" => "http://example.com/id", "@type" => "@id"},
        "listplain" => %{"@id" => "http://example.com/plain", "@container" => "@list"},
        "listlang" => %{"@id" => "http://example.com/lang", "@language" => "en", "@container" => "@list"},
        "listbool" => %{"@id" => "http://example.com/bool", "@type" => "xsd:boolean", "@container" => "@list"},
        "listinteger" => %{"@id" => "http://example.com/integer", "@type" => "xsd:integer", "@container" => "@list"},
        "listdouble" => %{"@id" => "http://example.com/double", "@type" => "xsd:double", "@container" => "@list"},
        "listdate" => %{"@id" => "http://example.com/date", "@type" => "xsd:date", "@container" => "@list"},
        "listid" => %{"@id" => "http://example.com/id", "@type" => "@id", "@container" => "@list"},
        "setplain" => %{"@id" => "http://example.com/plain", "@container" => "@set"},
        "setlang" => %{"@id" => "http://example.com/lang", "@language" => "en", "@container" => "@set"},
        "setbool" => %{"@id" => "http://example.com/bool", "@type" => "xsd:boolean", "@container" => "@set"},
        "setinteger" => %{"@id" => "http://example.com/integer", "@type" => "xsd:integer", "@container" => "@set"},
        "setdouble" => %{"@id" => "http://example.com/double", "@type" => "xsd:double", "@container" => "@set"},
        "setdate" => %{"@id" => "http://example.com/date", "@type" => "xsd:date", "@container" => "@set"},
        "setid" => %{"@id" => "http://example.com/id", "@type" => "@id", "@container" => "@set"},
        "langmap" => %{"@id" => "http://example.com/langmap", "@container" => "@language"},
      })
      %{example_context: context, inverse_context: JSON.LD.Context.inverse(context)}
    end

    %{
      "langmap" => %{"@value" => "en", "@language" => "en"},
      #"plain" => %{"@value" => "foo"},
      "setplain" => %{"@value" => "foo", "@language" => "pl"}
    }
    |> Enum.each(fn {prop, value} ->
         @tag data: {prop, value}
         test "uses #{prop} for #{inspect value}",
              %{data: {prop, value}, example_context: context,
                                     inverse_context: inverse_context} do
           assert compact_iri("http://example.com/#{String.replace(prop, "set", "")}",
                    context, inverse_context, value, true) == prop
         end
       end)

      %{
        "listplain"   => [
          [%{"@value" => "foo"}],
          [%{"@value" => "foo"}, %{"@value" => "bar"}, %{"@value" => "baz"}],
          [%{"@value" => "foo"}, %{"@value" => "bar"}, %{"@value" => 1}],
          [%{"@value" => "foo"}, %{"@value" => "bar"}, %{"@value" => 1.1}],
          [%{"@value" => "foo"}, %{"@value" => "bar"}, %{"@value" => true}],
          [%{"@value" => "de", "@language" => "de"}, %{"@value" => "jp", "@language" => "jp"}],
          [%{"@value" => true}],
          [%{"@value" => false}],
          [%{"@value" => 1}], [%{"@value" => 1.1}],
        ],
        "listlang" => [[%{"@value" => "en", "@language" => "en"}]],
        "listbool" => [[%{"@value" => "true", "@type" => to_string(XSD.boolean)}]],
        "listinteger" => [[%{"@value" => "1", "@type" => to_string(XSD.integer)}]],
        "listdouble" => [[%{"@value" => "1", "@type" => to_string(XSD.double)}]],
        "listdate" => [[%{"@value" => "2012-04-17", "@type" => to_string(XSD.date)}]],
      }
    |> Enum.each(fn {prop, values} ->
         Enum.each values, fn value ->
           @tag data: {prop, value}
           test "for @list uses #{prop} for #{inspect  %{"@list" => value}}",
                %{data: {prop, value}, example_context: context,
                                       inverse_context: inverse_context} do
             assert compact_iri("http://example.com/#{String.replace(prop, "list", "")}",
                      context, inverse_context, %{"@list" => value}, true) == prop
           end
         end
       end)
  end

#  describe "with :simple_compact_iris" do
#    before(:each) { subject.instance_variable_get(:@options)[:simple_compact_iris] = true}
#
#    %{
#      "nil" => [nil, nil],
#      "absolute IRI"  => ["http://example.com/", "http://example.com/"],
#      "prefix:suffix" => ["ex:suffix",           "http://example.org/suffix"],
#      "keyword"       => ["@type",               "@type"],
#      "empty"         => [":suffix",             "http://empty/suffix"],
#      "unmapped"      => ["foo",                 "foo"],
#      "bnode"         => ["_:a",                 RDF::Node("a")],
#      "relative"      => ["foo/bar",             "http://base/foo/bar"],
#      "odd CURIE"     => ["ex:perts",            "http://example.org/perts"]
#    }.each do |title, (result, input)|
#      test title do
#        expect(subject.compact_iri(input)).to produce(result, logger)
#      end
#    end
#
#    describe "and @vocab" do
#      before(:each) { subject.vocab = "http://example.org/"}
#
#      %{
#        "absolute IRI"  => ["http://example.com/", "http://example.com/"],
#        "prefix:suffix" => ["suffix",              "http://example.org/suffix"],
#        "keyword"       => ["@type",               "@type"],
#        "empty"         => [":suffix",             "http://empty/suffix"],
#        "unmapped"      => ["foo",                 "foo"],
#        "bnode"         => ["_:a",                 RDF::Node("a")],
#        "relative"      => ["http://base/foo/bar", "http://base/foo/bar"],
#        "odd CURIE"     => ["experts",             "http://example.org/perts"]
#      }.each do |title, (result, input)|
#        test title do
#          expect(subject.compact_iri(input, vocab: true)).to produce(result, logger)
#        end
#      end
#    end
#  end

  describe "compact-0018" do
    setup do
      context = JSON.LD.context(Jason.decode! """
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
      %{example_context: context, inverse_context: JSON.LD.Context.inverse(context)}
    end


    %{
      "term" => [
        '{ "@value": "v0.1", "@language": "de" }',
        '{ "@value": "v0.2", "@language": "en" }',
        '{ "@value": "v0.3"}',
        '{ "@value": 4}',
        '{ "@value": true}',
        '{ "@value": false}'
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
      """,
    }
    |> Enum.each(fn {term, values} ->
         values = if is_binary(values),
          do: [values],
          else: values
         Enum.each(values, fn value ->
          value = Jason.decode!(value)
           @tag data: {term, value}
           test "uses #{term} for #{inspect value, limit: 3}",
                %{data: {term, value}, example_context: context,
                                       inverse_context: inverse_context} do
             assert compact_iri("http://example.com/term", context, inverse_context,
                value, true) == term
           end
         end)
       end)
  end

  describe "compact-0020" do
    setup do
      context = JSON.LD.context(%{
        "ex" => "http://example.org/ns#",
        "ex:property" => %{"@container" => "@list"}
      })
      %{example_context: context, inverse_context: JSON.LD.Context.inverse(context)}
    end

    @tag skip: "TODO: we don't support 'position: :subject'"
    test "Compact @id that is a property IRI when @container is @list", %{
            example_context: context, inverse_context: inverse_context} do
      assert compact_iri("http://example.org/ns#property", context, inverse_context) == "ex:property"
#      expect(ctx.compact_iri("http://example.org/ns#property", position: :subject)).
#        to produce("ex:property", logger)
    end
  end

  describe "compact-0041" do
    setup do
      context = JSON.LD.context(%{
        "name" => %{"@id" => "http://example.com/property", "@container" => "@list"}
      })
      %{example_context: context, inverse_context: JSON.LD.Context.inverse(context)}
    end

    test "Does not use @list with @index", %{
            example_context: context, inverse_context: inverse_context} do
      assert compact_iri("http://example.com/property", context, inverse_context,
              %{
                "@list" => ["one item"],
                "@index" => "an annotation"
              }) == "http://example.com/property"
    end
  end

end
