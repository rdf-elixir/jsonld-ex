defmodule JSON.LD.DecoderTest do
  use JSON.LD.Case, async: false

  doctest JSON.LD.Decoder

  test "an empty JSON document is deserialized to an empty graph" do
    assert JSON.LD.Decoder.decode!("{}") == Dataset.new()
  end

  describe "unnamed nodes" do
    %{
      "no @id" => {
        ~s({
          "http://example.com/foo": "bar"
        }),
        {RDF.bnode("b0"), ~I<http://example.com/foo>, RDF.literal("bar")}
      },
      "@id with _:a" => {
        ~s({
          "@id": "_:a",
          "http://example.com/foo": "bar"
        }),
        {RDF.bnode("b0"), ~I<http://example.com/foo>, RDF.literal("bar")}
      },
      "@id with _:a and reference" => {
        ~s({
          "@id": "_:a",
          "http://example.com/foo": {"@id": "_:a"}
        }),
        {RDF.bnode("b0"), ~I<http://example.com/foo>, RDF.bnode("b0")}
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: {input, output}} do
        assert JSON.LD.Decoder.decode!(input) == RDF.Dataset.new(output)
      end
    end)
  end

  describe "nodes with @id" do
    %{
      "with IRI" => {
        ~s({
          "@id": "http://example.com/a",
          "http://example.com/foo": "bar"
        }),
        {~I<http://example.com/a>, ~I<http://example.com/foo>, RDF.literal("bar")}
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: {input, output}} do
        assert JSON.LD.Decoder.decode!(input) == RDF.Dataset.new(output)
      end
    end)

    %{
      "base" => {
        ~s({
          "@id": "",
          "@type": "#{RDF.uri(RDFS.Resource)}"
        }),
        {~I<http://example.org/>, NS.RDF.type(), RDF.uri(RDFS.Resource)}
      },
      "relative" => {
        ~s({
          "@id": "a/b",
          "@type": "#{RDF.uri(RDFS.Resource)}"
        }),
        {~I<http://example.org/a/b>, NS.RDF.type(), RDF.uri(RDFS.Resource)}
      },
      "hash" => {
        ~s({
          "@id": "#a",
          "@type": "#{RDF.uri(RDFS.Resource)}"
        }),
        {~I<http://example.org/#a>, NS.RDF.type(), RDF.uri(RDFS.Resource)}
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test "when relative IRIs #{title}", %{data: {input, output}} do
        assert JSON.LD.Decoder.decode!(input, base: "http://example.org/") ==
                 RDF.Dataset.new(output)
      end
    end)
  end

  describe "typed nodes" do
    %{
      "one type" => {
        ~s({
          "@type": "http://example.com/foo"
        }),
        {RDF.bnode("b0"), NS.RDF.type(), ~I<http://example.com/foo>}
      },
      "two types" => {
        ~s({
          "@type": ["http://example.com/foo", "http://example.com/baz"]
        }),
        [
          {RDF.bnode("b0"), NS.RDF.type(), ~I<http://example.com/foo>},
          {RDF.bnode("b0"), NS.RDF.type(), ~I<http://example.com/baz>}
        ]
      },
      "blank node type" => {
        ~s({
          "@type": "_:foo"
        }),
        {RDF.bnode("b1"), NS.RDF.type(), RDF.bnode("b0")}
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: {input, output}} do
        assert JSON.LD.Decoder.decode!(input) == RDF.Dataset.new(output)
      end
    end)
  end

  describe "key/value" do
    %{
      "string" => {
        ~s({
          "http://example.com/foo": "bar"
        }),
        {RDF.bnode("b0"), ~I<http://example.com/foo>, RDF.literal("bar")}
      },
      "strings" => {
        ~s({
          "http://example.com/foo": ["bar", "baz"]
        }),
        [
          {RDF.bnode("b0"), ~I<http://example.com/foo>, RDF.literal("bar")},
          {RDF.bnode("b0"), ~I<http://example.com/foo>, RDF.literal("baz")}
        ]
      },
      "IRI" => {
        ~s({
          "http://example.com/foo": {"@id": "http://example.com/bar"}
        }),
        {RDF.bnode("b0"), ~I<http://example.com/foo>, ~I<http://example.com/bar>}
      },
      "IRIs" => {
        ~s({
          "http://example.com/foo": [{"@id": "http://example.com/bar"}, {"@id": "http://example.com/baz"}]
        }),
        [
          {RDF.bnode("b0"), ~I<http://example.com/foo>, ~I<http://example.com/bar>},
          {RDF.bnode("b0"), ~I<http://example.com/foo>, ~I<http://example.com/baz>}
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: {input, output}} do
        assert JSON.LD.Decoder.decode!(input) == RDF.Dataset.new(output)
      end
    end)
  end

  describe "@json literale" do
    %{
      "boolean true" => {
        ~s({
          "@context": {
            "@version": 1.1,
            "e": {"@id": "http://example.org/vocab#bool", "@type": "@json"}
          },
          "e": true
        }),
        {RDF.bnode("b0"), ~I<http://example.org/vocab#bool>,
         RDF.literal("true", datatype: NS.RDF.JSON)}
      },
      "boolean false" => {
        ~s({
          "@context": {
            "@version": 1.1,
            "e": {"@id": "http://example.org/vocab#bool", "@type": "@json"}
          },
          "e": false
        }),
        {RDF.bnode("b0"), ~I<http://example.org/vocab#bool>,
         RDF.literal("false", datatype: NS.RDF.JSON)}
      },
      "double" => {
        ~s({
          "@context": {
            "@version": 1.1,
            "e": {"@id": "http://example.org/vocab#double", "@type": "@json"}
          },
          "e": 1.23
        }),
        {RDF.bnode("b0"), ~I<http://example.org/vocab#double>,
         RDF.literal("1.23", datatype: NS.RDF.JSON)}
      },
      "integer" => {
        ~s({
          "@context": {
            "@version": 1.1,
            "e": {"@id": "http://example.org/vocab#integer", "@type": "@json"}
          },
          "e": 123
        }),
        {RDF.bnode("b0"), ~I<http://example.org/vocab#integer>,
         RDF.literal("123", datatype: NS.RDF.JSON)}
      },
      "string" => {
        ~s({
          "@context": {
            "@version": 1.1,
            "e": {"@id": "http://example.org/vocab#string", "@type": "@json"}
          },
          "e": "string"
        }),
        {RDF.bnode("b0"), ~I<http://example.org/vocab#string>,
         RDF.literal("\"string\"", datatype: NS.RDF.JSON)}
      },
      "null" => {
        ~s({
          "@context": {
            "@version": 1.1,
            "e": {"@id": "http://example.org/vocab#null", "@type": "@json"}
          },
          "e": null
        }),
        {RDF.bnode("b0"), ~I<http://example.org/vocab#null>,
         RDF.literal("null", datatype: NS.RDF.JSON)}
      },
      "object" => {
        ~s({
          "@context": {
            "@version": 1.1,
            "e": {"@id": "http://example.org/vocab#object", "@type": "@json"}
          },
          "e": {"foo": "bar"}
        }),
        {RDF.bnode("b0"), ~I<http://example.org/vocab#object>,
         RDF.literal("{\"foo\":\"bar\"}", datatype: NS.RDF.JSON)}
      },
      "array" => {
        ~s({
          "@context": {
            "@version": 1.1,
            "e": {"@id": "http://example.org/vocab#array", "@type": "@json"}
          },
          "e": [{"foo": "bar"}]
        }),
        {RDF.bnode("b0"), ~I<http://example.org/vocab#array>,
         RDF.literal("[{\"foo\":\"bar\"}]", datatype: NS.RDF.JSON)}
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: {input, output}} do
        assert JSON.LD.Decoder.decode!(input) == RDF.Dataset.new(output)
      end
    end)
  end

  describe "@direction - i18n-datatype" do
    %{
      "no language rtl" => {
        ~s({"http://example.org/label": {"@value": "no language", "@direction": "rtl"}}),
        {RDF.bnode("b0"), ~I<http://example.org/label>,
         RDF.literal("no language", datatype: "https://www.w3.org/ns/i18n#_rtl")}
      },
      "en-US rtl" => {
        ~s({"http://example.org/label": {"@value": "en-US", "@language": "en-US", "@direction": "rtl"}}),
        {RDF.bnode("b0"), ~I<http://example.org/label>,
         RDF.literal("en-US", datatype: "https://www.w3.org/ns/i18n#en-us_rtl")}
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: {input, output}} do
        assert JSON.LD.Decoder.decode!(input, rdf_direction: "i18n-datatype") ==
                 RDF.Dataset.new(output)
      end
    end)
  end

  describe "@direction - compound-literal" do
    %{
      "no language rtl" => {
        ~s({"http://example.org/label": {"@value": "no language", "@direction": "rtl"}}),
        [
          {RDF.bnode("b0"), ~I<http://example.org/label>, RDF.bnode("b1")},
          {RDF.bnode("b1"), NS.RDF.value(), RDF.literal("no language")},
          {RDF.bnode("b1"), RDF.iri(RDF.__base_iri__() <> "direction"), RDF.literal("rtl")}
        ]
      },
      "en-US rtl" => {
        ~s({"http://example.org/label": {"@value": "en-US", "@language": "en-US", "@direction": "rtl"}}),
        [
          {RDF.bnode("b0"), ~I<http://example.org/label>, RDF.bnode("b1")},
          {RDF.bnode("b1"), NS.RDF.value(), RDF.literal("en-US")},
          {RDF.bnode("b1"), RDF.iri(RDF.__base_iri__() <> "language"), RDF.literal("en-us")},
          {RDF.bnode("b1"), RDF.iri(RDF.__base_iri__() <> "direction"), RDF.literal("rtl")}
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: {input, output}} do
        assert_rdf_isomorphic(
          JSON.LD.Decoder.decode!(input, rdf_direction: "compound-literal"),
          RDF.Dataset.new(output)
        )
      end
    end)
  end

  describe "literals" do
    %{
      "plain literal" => {
        ~s({"@id": "http://greggkellogg.net/foaf#me", "http://xmlns.com/foaf/0.1/name": "Gregg Kellogg"}),
        {~I<http://greggkellogg.net/foaf#me>, ~I<http://xmlns.com/foaf/0.1/name>,
         RDF.literal("Gregg Kellogg")}
      },
      "explicit plain literal" => {
        ~s({"http://xmlns.com/foaf/0.1/name": {"@value": "Gregg Kellogg"}}),
        {RDF.bnode("b0"), ~I<http://xmlns.com/foaf/0.1/name>, RDF.literal("Gregg Kellogg")}
      },
      "language tagged literal" => {
        ~s({"http://www.w3.org/2000/01/rdf-schema#label": {"@value": "A plain literal with a lang tag.", "@language": "en-us"}}),
        {RDF.bnode("b0"), RDFS.label(),
         RDF.literal("A plain literal with a lang tag.", language: "en-us")}
      },
      "I18N literal with language" => {
        ~s([{
          "@id": "http://greggkellogg.net/foaf#me",
          "http://xmlns.com/foaf/0.1/knows": {"@id": "http://www.ivan-herman.net/foaf#me"}
        },{
          "@id": "http://www.ivan-herman.net/foaf#me",
          "http://xmlns.com/foaf/0.1/name": {"@value": "Herman Iván", "@language": "hu"}
        }]),
        [
          {~I<http://greggkellogg.net/foaf#me>, ~I<http://xmlns.com/foaf/0.1/knows>,
           ~I<http://www.ivan-herman.net/foaf#me>},
          {~I<http://www.ivan-herman.net/foaf#me>, ~I<http://xmlns.com/foaf/0.1/name>,
           RDF.literal("Herman Iv\u00E1n", language: "hu")}
        ]
      },
      "explicit datatyped literal" => {
        ~s({
          "@id":  "http://greggkellogg.net/foaf#me",
          "http://purl.org/dc/terms/created":  {"@value": "1957-02-27", "@type": "http://www.w3.org/2001/XMLSchema#date"}
        }),
        {~I<http://greggkellogg.net/foaf#me>, ~I<http://purl.org/dc/terms/created>,
         RDF.literal("1957-02-27", datatype: XSD.date())}
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: {input, output}} do
        assert JSON.LD.Decoder.decode!(input) == RDF.Dataset.new(output)
      end
    end)
  end

  describe "prefixes" do
    %{
      "empty suffix" => {
        ~s({"@context": {"prefix": "http://example.com/default#"}, "prefix:": "bar"}),
        {RDF.bnode("b0"), ~I<http://example.com/default#>, RDF.literal("bar")}
      },
      "prefix:suffix" => {
        ~s({"@context": {"prefix": "http://example.com/default#"}, "prefix:foo": "bar"}),
        {RDF.bnode("b0"), ~I<http://example.com/default#foo>, RDF.literal("bar")}
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: {input, output}} do
        assert JSON.LD.Decoder.decode!(input) == RDF.Dataset.new(output)
      end
    end)
  end

  describe "overriding keywords" do
    %{
      "'url' for @id, 'a' for @type" => {
        ~s({
          "@context": {"url": "@id", "a": "@type", "name": "http://schema.org/name"},
          "url": "http://example.com/about#gregg",
          "a": "http://schema.org/Person",
          "name": "Gregg Kellogg"
        }),
        [
          {~I<http://example.com/about#gregg>, NS.RDF.type(), ~I<http://schema.org/Person>},
          {~I<http://example.com/about#gregg>, ~I<http://schema.org/name>,
           RDF.literal("Gregg Kellogg")}
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: {input, output}} do
        assert JSON.LD.Decoder.decode!(input) == RDF.Dataset.new(output)
      end
    end)
  end

  describe "chaining" do
    %{
      "explicit subject" => {
        ~s({
          "@context": {"foaf": "http://xmlns.com/foaf/0.1/"},
          "@id": "http://greggkellogg.net/foaf#me",
          "foaf:knows": {
            "@id": "http://www.ivan-herman.net/foaf#me",
            "foaf:name": "Ivan Herman"
          }
        }),
        [
          {~I<http://greggkellogg.net/foaf#me>, ~I<http://xmlns.com/foaf/0.1/knows>,
           ~I<http://www.ivan-herman.net/foaf#me>},
          {~I<http://www.ivan-herman.net/foaf#me>, ~I<http://xmlns.com/foaf/0.1/name>,
           RDF.literal("Ivan Herman")}
        ]
      },
      "implicit subject" => {
        ~s({
          "@context": {"foaf": "http://xmlns.com/foaf/0.1/"},
          "@id": "http://greggkellogg.net/foaf#me",
          "foaf:knows": {
            "foaf:name": "Manu Sporny"
          }
        }),
        [
          {~I<http://greggkellogg.net/foaf#me>, ~I<http://xmlns.com/foaf/0.1/knows>,
           RDF.bnode("b0")},
          {RDF.bnode("b0"), ~I<http://xmlns.com/foaf/0.1/name>, RDF.literal("Manu Sporny")}
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: {input, output}} do
        assert JSON.LD.Decoder.decode!(input) == RDF.Dataset.new(output)
      end
    end)
  end

  describe "multiple values" do
    %{
      "literals" => {
        ~s({
          "@context": {"foaf": "http://xmlns.com/foaf/0.1/"},
          "@id": "http://greggkellogg.net/foaf#me",
          "foaf:knows": ["Manu Sporny", "Ivan Herman"]
        }),
        [
          {~I<http://greggkellogg.net/foaf#me>, ~I<http://xmlns.com/foaf/0.1/knows>,
           RDF.literal("Manu Sporny")},
          {~I<http://greggkellogg.net/foaf#me>, ~I<http://xmlns.com/foaf/0.1/knows>,
           RDF.literal("Ivan Herman")}
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: {input, output}} do
        assert JSON.LD.Decoder.decode!(input) == RDF.Dataset.new(output)
      end
    end)
  end

  describe "lists" do
    %{
      "Empty" => {
        ~s({
          "@context": {"foaf": "http://xmlns.com/foaf/0.1/"},
          "@id": "http://greggkellogg.net/foaf#me",
          "foaf:knows": {"@list": []}
        }),
        {~I<http://greggkellogg.net/foaf#me>, ~I<http://xmlns.com/foaf/0.1/knows>, NS.RDF.nil()}
      },
      "single value" => {
        ~s({
         "@context": {"foaf": "http://xmlns.com/foaf/0.1/"},
         "@id": "http://greggkellogg.net/foaf#me",
         "foaf:knows": {"@list": ["Manu Sporny"]}
       }),
        [
          {~I<http://greggkellogg.net/foaf#me>, ~I<http://xmlns.com/foaf/0.1/knows>,
           RDF.bnode("b0")},
          {RDF.bnode("b0"), NS.RDF.first(), RDF.literal("Manu Sporny")},
          {RDF.bnode("b0"), NS.RDF.rest(), NS.RDF.nil()}
        ]
      },
      "single value (with coercion)" => {
        ~s({
         "@context": {
           "foaf": "http://xmlns.com/foaf/0.1/",
           "foaf:knows": { "@container": "@list"}
         },
         "@id": "http://greggkellogg.net/foaf#me",
         "foaf:knows": ["Manu Sporny"]
       }),
        [
          {~I<http://greggkellogg.net/foaf#me>, ~I<http://xmlns.com/foaf/0.1/knows>,
           RDF.bnode("b0")},
          {RDF.bnode("b0"), NS.RDF.first(), RDF.literal("Manu Sporny")},
          {RDF.bnode("b0"), NS.RDF.rest(), NS.RDF.nil()}
        ]
      },
      "multiple values" => {
        ~s({
         "@context": {"foaf": "http://xmlns.com/foaf/0.1/"},
         "@id": "http://greggkellogg.net/foaf#me",
         "foaf:knows": {"@list": ["Manu Sporny", "Dave Longley"]}
       }),
        [
          {~I<http://greggkellogg.net/foaf#me>, ~I<http://xmlns.com/foaf/0.1/knows>,
           RDF.bnode("b0")},
          {RDF.bnode("b0"), NS.RDF.first(), RDF.literal("Manu Sporny")},
          {RDF.bnode("b0"), NS.RDF.rest(), RDF.bnode("b1")},
          {RDF.bnode("b1"), NS.RDF.first(), RDF.literal("Dave Longley")},
          {RDF.bnode("b1"), NS.RDF.rest(), NS.RDF.nil()}
        ]
      },
      "@list containing @list" => {
        ~s({
          "@id": "http://example/A",
          "http://example.com/foo": {"@list": [{"@list": ["baz"]}]}
        }),
        [
          {~I<http://example/A>, ~I<http://example.com/foo>, RDF.bnode("b0")},
          {RDF.bnode("b0"), NS.RDF.first(), RDF.bnode("b1")},
          {RDF.bnode("b0"), NS.RDF.rest(), NS.RDF.nil()},
          {RDF.bnode("b1"), NS.RDF.first(), RDF.literal("baz")},
          {RDF.bnode("b1"), NS.RDF.rest(), NS.RDF.nil()}
        ]
      },
      "@list containing empty @list" => {
        ~s({
          "@id": "http://example/A",
          "http://example.com/foo": {"@list": [{"@list": []}]}
        }),
        [
          {~I<http://example/A>, ~I<http://example.com/foo>, RDF.bnode("b0")},
          {RDF.bnode("b0"), NS.RDF.first(), NS.RDF.nil()},
          {RDF.bnode("b0"), NS.RDF.rest(), NS.RDF.nil()}
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: {input, output}} do
        assert_rdf_isomorphic(
          JSON.LD.Decoder.decode!(input),
          RDF.Dataset.new(output)
        )
      end
    end)
  end

  describe "context" do
    %{
      "@id coersion" => {
        ~s({
          "@context": {
            "knows": {"@id": "http://xmlns.com/foaf/0.1/knows", "@type": "@id"}
          },
          "@id":  "http://greggkellogg.net/foaf#me",
          "knows":  "http://www.ivan-herman.net/foaf#me"
        }),
        {~I<http://greggkellogg.net/foaf#me>, ~I<http://xmlns.com/foaf/0.1/knows>,
         ~I<http://www.ivan-herman.net/foaf#me>}
      },
      "datatype coersion" => {
        ~s({
          "@context": {
            "dcterms":  "http://purl.org/dc/terms/",
            "xsd":      "http://www.w3.org/2001/XMLSchema#",
            "created":  {"@id": "http://purl.org/dc/terms/created", "@type": "xsd:date"}
          },
          "@id":  "http://greggkellogg.net/foaf#me",
          "created":  "1957-02-27"
        }),
        {~I<http://greggkellogg.net/foaf#me>, ~I<http://purl.org/dc/terms/created>,
         RDF.literal("1957-02-27", datatype: XSD.date())}
      },
      "sub-objects with context" => {
        ~s({
          "@context": {"foo": "http://example.com/foo"},
          "foo":  {
            "@context": {"foo": "http://example.org/foo"},
            "foo": "bar"
          }
        }),
        [
          {RDF.bnode("b0"), ~I<http://example.com/foo>, RDF.bnode("b1")},
          {RDF.bnode("b1"), ~I<http://example.org/foo>, RDF.literal("bar")}
        ]
      },
      "contexts with a list processed in order" => {
        ~s({
          "@context": [
            {"foo": "http://example.com/foo"},
            {"foo": "http://example.org/foo"}
          ],
          "foo":  "bar"
        }),
        {RDF.bnode("b0"), ~I<http://example.org/foo>, RDF.literal("bar")}
      },
      "term definition resolves term as IRI" => {
        ~s({
          "@context": [
            {"foo": "http://example.com/foo"},
            {"bar": "foo"}
          ],
          "bar":  "bar"
        }),
        {RDF.bnode("b0"), ~I<http://example.com/foo>, RDF.literal("bar")}
      },
      "term definition resolves prefix as IRI" => {
        ~s({
          "@context": [
            {"foo": "http://example.com/foo#"},
            {"bar": "foo:bar"}
          ],
          "bar":  "bar"
        }),
        {RDF.bnode("b0"), ~I<http://example.com/foo#bar>, RDF.literal("bar")}
      },
      "@language" => {
        ~s({
          "@context": {
            "foo": "http://example.com/foo#",
            "@language": "en"
          },
          "foo:bar":  "baz"
        }),
        {RDF.bnode("b0"), ~I<http://example.com/foo#bar>, RDF.literal("baz", language: "en")}
      },
      "@language with override" => {
        ~s({
          "@context": {
            "foo": "http://example.com/foo#",
            "@language": "en"
          },
          "foo:bar":  {"@value": "baz", "@language": "fr"}
        }),
        {RDF.bnode("b0"), ~I<http://example.com/foo#bar>, RDF.literal("baz", language: "fr")}
      },
      "@language with plain" => {
        ~s({
          "@context": {
            "foo": "http://example.com/foo#",
            "@language": "en"
          },
          "foo:bar":  {"@value": "baz"}
        }),
        {RDF.bnode("b0"), ~I<http://example.com/foo#bar>, RDF.literal("baz")}
      },
      "@propagate: true (default)" => {
        ~s({
          "@context": {
            "@version": 1.1,
            "ex": "http://example.org/",
            "term1": "ex:term1",
            "term2": {"@id": "ex:term2", "@type": "@id"}
          },
          "term1": "value1",
          "ex:prop": {
            "term2": "http://example.org/value2"
          }
        }),
        [
          {RDF.bnode("b0"), ~I<http://example.org/term1>, RDF.literal("value1")},
          {RDF.bnode("b0"), ~I<http://example.org/prop>, RDF.bnode("b1")},
          {RDF.bnode("b1"), ~I<http://example.org/term2>, ~I<http://example.org/value2>}
        ]
      },
      "@propagate: false" => {
        ~s({
          "@context": {
            "@version": 1.1,
            "ex": "http://example.org/",
            "term1": "ex:term1",
            "term2": {"@id": "ex:term2", "@type": "@id"}
          },
          "term1": "value1",
          "ex:prop": {
            "@context": {"@propagate": false},
            "term2": "http://example.org/value2"
          }
        }),
        [
          {RDF.bnode("b0"), ~I<http://example.org/term1>, RDF.literal("value1")},
          {RDF.bnode("b0"), ~I<http://example.org/prop>, RDF.bnode("b1")},
          {RDF.bnode("b1"), ~I<http://example.org/term2>, RDF.iri("http://example.org/value2")}
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: {input, output}} do
        assert JSON.LD.Decoder.decode!(input) == RDF.Dataset.new(output)
      end
    end)

    %{
      "dt with term" => {
        ~s({
          "@context": [
            {"date": "http://www.w3.org/2001/XMLSchema#date", "term": "http://example.org/foo#"},
            {"foo": {"@id": "term", "@type": "date"}}
          ],
          "foo": "bar"
        }),
        {RDF.bnode("b0"), ~I<http://example.org/foo#>, RDF.literal("bar", datatype: XSD.date())}
      },
      "@id with term" => {
        ~s({
          "@context": [
            {"foo": {"@id": "http://example.org/foo#bar", "@type": "@id"}}
          ],
          "foo": "http://example.org/foo#bar"
        }),
        {RDF.bnode("b0"), ~I<http://example.org/foo#bar>, ~I<http://example.org/foo#bar>}
      },
      "coercion without term definition" => {
        ~s({
          "@context": [
            {
              "xsd": "http://www.w3.org/2001/XMLSchema#",
              "dc": "http://purl.org/dc/terms/"
            },
            {
              "dc:date": {"@type": "xsd:date"}
            }
          ],
          "dc:date": "2011-11-23"
        }),
        {RDF.bnode("b0"), ~I<http://purl.org/dc/terms/date>,
         RDF.literal("2011-11-23", datatype: XSD.date())}
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test "term def with @id + @type coercion: #{title}", %{data: {input, output}} do
        assert JSON.LD.Decoder.decode!(input) == RDF.Dataset.new(output)
      end
    end)

    %{
      "dt with term" => {
        ~s({
          "@context": [
            {"date": "http://www.w3.org/2001/XMLSchema#date", "term": "http://example.org/foo#"},
            {"foo": {"@id": "term", "@type": "date", "@container": "@list"}}
          ],
          "foo": ["bar"]
        }),
        [
          {RDF.bnode("b0"), ~I<http://example.org/foo#>, RDF.bnode("b1")},
          {RDF.bnode("b1"), NS.RDF.first(), RDF.literal("bar", datatype: XSD.date())},
          {RDF.bnode("b1"), NS.RDF.rest(), NS.RDF.nil()}
        ]
      },
      "@id with term" => {
        ~s({
          "@context": [
            {"foo": {"@id": "http://example.org/foo#bar", "@type": "@id", "@container": "@list"}}
          ],
          "foo": ["http://example.org/foo#bar"]
        }),
        [
          {RDF.bnode("b0"), ~I<http://example.org/foo#bar>, RDF.bnode("b1")},
          {RDF.bnode("b1"), NS.RDF.first(), ~I<http://example.org/foo#bar>},
          {RDF.bnode("b1"), NS.RDF.rest(), NS.RDF.nil()}
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test "term def with @id + @type + @container list: #{title}", %{data: {input, output}} do
        assert JSON.LD.Decoder.decode!(input) == RDF.Dataset.new(output)
      end
    end)
  end

  describe "blank node predicates" do
    setup do
      {:ok, input: ~s({"@id": "http://example/subj", "_:foo": "bar"})}
    end

    @tag skip: "TODO: missing generalized RDF support"
    test "outputs statements with blank node predicates if :produceGeneralizedRdf is true",
         %{input: input} do
      dataset = JSON.LD.Decoder.decode!(input, produce_generalized_rdf: true)
      assert RDF.Dataset.statement_count(dataset) == 1
    end

    test "rejects statements with blank node predicates if :produceGeneralizedRdf is false",
         %{input: input} do
      dataset = JSON.LD.Decoder.decode!(input, produce_generalized_rdf: false)
      assert RDF.Dataset.statement_count(dataset) == 0
    end
  end

  describe "@included" do
    %{
      "Basic Included array" => {
        ~s({
          "@context": {
            "@version": 1.1,
            "@vocab": "http://example.org/"
          },
          "prop": "value",
          "@included": [{
            "prop": "value2"
          }]
        }),
        [
          {RDF.bnode("b0"), ~I<http://example.org/prop>, RDF.literal("value")},
          {RDF.bnode("b1"), ~I<http://example.org/prop>, RDF.literal("value2")}
        ]
      },
      "Basic Included object" => {
        ~s({
          "@context": {
            "@version": 1.1,
            "@vocab": "http://example.org/"
          },
          "prop": "value",
          "@included": {
            "prop": "value2"
          }
        }),
        [
          {RDF.bnode("b0"), ~I<http://example.org/prop>, RDF.literal("value")},
          {RDF.bnode("b1"), ~I<http://example.org/prop>, RDF.literal("value2")}
        ]
      },
      "Multiple properties mapping to @included are folded together" => {
        ~s({
          "@context": {
            "@version": 1.1,
            "@vocab": "http://example.org/",
            "included1": "@included",
            "included2": "@included"
          },
          "included1": {"prop": "value1"},
          "included2": {"prop": "value2"}
        }),
        [
          {RDF.bnode("b0"), ~I<http://example.org/prop>, RDF.literal("value1")},
          {RDF.bnode("b1"), ~I<http://example.org/prop>, RDF.literal("value2")}
        ]
      },
      "Included containing @included" => {
        ~s({
          "@context": {
            "@version": 1.1,
            "@vocab": "http://example.org/"
          },
          "prop": "value",
          "@included": {
            "prop": "value2",
            "@included": {
              "prop": "value3"
            }
          }
        }),
        [
          {RDF.bnode("b0"), ~I<http://example.org/prop>, RDF.literal("value")},
          {RDF.bnode("b1"), ~I<http://example.org/prop>, RDF.literal("value2")},
          {RDF.bnode("b2"), ~I<http://example.org/prop>, RDF.literal("value3")}
        ]
      },
      "Property value with @included" => {
        ~s({
          "@context": {
            "@version": 1.1,
            "@vocab": "http://example.org/"
          },
          "prop": {
            "@type": "Foo",
            "@included": {
              "@type": "Bar"
            }
          }
        }),
        [
          {RDF.bnode("b0"), ~I<http://example.org/prop>, RDF.bnode("b1")},
          {RDF.bnode("b1"), NS.RDF.type(), ~I<http://example.org/Foo>},
          {RDF.bnode("b2"), NS.RDF.type(), ~I<http://example.org/Bar>}
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: {input, output}} do
        assert_rdf_isomorphic(
          JSON.LD.Decoder.decode!(input),
          RDF.Dataset.new(output)
        )
      end
    end)
  end

  describe "to_rdf/2 with remote documents" do
    setup do
      bypass = Bypass.open()
      {:ok, bypass: bypass}
    end

    test "loads and processes a remote JSON-LD document", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert "GET" == conn.method
        assert "/test-doc" == conn.request_path

        document = %{
          "@context" => %{
            "@vocab" => "http://schema.org/",
            "name" => "name",
            "homepage" => %{"@id" => "url", "@type" => "@id"}
          },
          "@type" => "Person",
          "name" => "Jane Doe",
          "homepage" => "http://example.org/jane"
        }

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/ld+json")
        |> Plug.Conn.resp(200, Jason.encode!(document))
      end)

      expected_dataset =
        RDF.Dataset.new([
          {RDF.bnode("b0"), NS.RDF.type(), ~I<http://schema.org/Person>},
          {RDF.bnode("b0"), ~I<http://schema.org/name>, RDF.literal("Jane Doe")},
          {RDF.bnode("b0"), ~I<http://schema.org/url>, ~I<http://example.org/jane>}
        ])

      assert JSON.LD.to_rdf("http://localhost:#{bypass.port}/test-doc") ==
               expected_dataset
    end

    test "loads remote document with external context", %{bypass: bypass} do
      Bypass.expect(bypass, fn
        %{request_path: "/context"} = conn ->
          context = %{
            "@context" => %{
              "@vocab" => "http://schema.org/",
              "name" => "name",
              "homepage" => %{"@id" => "url", "@type" => "@id"}
            }
          }

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/ld+json")
          |> Plug.Conn.resp(200, Jason.encode!(context))

        %{request_path: "/test-doc"} = conn ->
          document = %{
            "@context" => "context",
            "@type" => "Person",
            "name" => "Alice Smith",
            "homepage" => "http://example.org/alice"
          }

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/ld+json")
          |> Plug.Conn.resp(200, Jason.encode!(document))
      end)

      expected_dataset =
        RDF.Dataset.new([
          {RDF.bnode("b0"), NS.RDF.type(), ~I<http://schema.org/Person>},
          {RDF.bnode("b0"), ~I<http://schema.org/name>, RDF.literal("Alice Smith")},
          {RDF.bnode("b0"), ~I<http://schema.org/url>, ~I<http://example.org/alice>}
        ])

      assert JSON.LD.to_rdf("http://localhost:#{bypass.port}/test-doc") ==
               expected_dataset
    end

    test "fails when remote document cannot be loaded", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.resp(conn, 404, "Not Found")
      end)

      assert_raise_json_ld_error "loading document failed",
                                 "HTTP request failed with status 404",
                                 fn ->
                                   JSON.LD.to_rdf("http://localhost:#{bypass.port}/not-found")
                                 end
    end

    test "fails when remote document is not valid JSON-LD", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/ld+json")
        |> Plug.Conn.resp(200, "invalid json")
      end)

      assert_raise_json_ld_error "loading document failed", fn ->
        JSON.LD.to_rdf("http://localhost:#{bypass.port}/invalid")
      end
    end
  end

  describe "advanced features" do
    %{
      "number syntax (decimal)" => {
        ~s({"@context": { "measure": "http://example/measure#"}, "measure:cups": 5.3}),
        {RDF.bnode("b0"), ~I<http://example/measure#cups>,
         RDF.literal("5.3E0", datatype: XSD.double())}
      },
      "number syntax (double)" => {
        ~s({"@context": { "measure": "http://example/measure#"}, "measure:cups": 5.3e0}),
        {RDF.bnode("b0"), ~I<http://example/measure#cups>,
         RDF.literal("5.3E0", datatype: XSD.double())}
      },
      "number syntax (integer)" => {
        ~s({"@context": { "chem": "http://example/chem#"}, "chem:protons": 12}),
        {RDF.bnode("b0"), ~I<http://example/chem#protons>,
         RDF.literal("12", datatype: XSD.integer())}
      },
      "boolean syntax" => {
        ~s({"@context": { "sensor": "http://example/sensor#"}, "sensor:active": true}),
        {RDF.bnode("b0"), ~I<http://example/sensor#active>,
         RDF.literal("true", datatype: XSD.boolean())}
      },
      "Array top element" => {
        ~s([
         {"@id":   "http://example.com/#me", "@type": "http://xmlns.com/foaf/0.1/Person"},
         {"@id":   "http://example.com/#you", "@type": "http://xmlns.com/foaf/0.1/Person"}
       ]),
        [
          {~I<http://example.com/#me>, NS.RDF.type(), ~I<http://xmlns.com/foaf/0.1/Person>},
          {~I<http://example.com/#you>, NS.RDF.type(), ~I<http://xmlns.com/foaf/0.1/Person>}
        ]
      },
      "@graph with array of objects value" => {
        ~s({
         "@context": {"foaf": "http://xmlns.com/foaf/0.1/"},
         "@graph": [
           {"@id":   "http://example.com/#me", "@type": "foaf:Person"},
           {"@id":   "http://example.com/#you", "@type": "foaf:Person"}
         ]
       }),
        [
          {~I<http://example.com/#me>, NS.RDF.type(), ~I<http://xmlns.com/foaf/0.1/Person>},
          {~I<http://example.com/#you>, NS.RDF.type(), ~I<http://xmlns.com/foaf/0.1/Person>}
        ]
      },
      "XMLLiteral" => {
        ~s({
         "http://rdfs.org/sioc/ns#content": {
           "@value": "foo",
           "@type": "http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral"
         }
       }),
        {RDF.bnode("b0"), ~I<http://rdfs.org/sioc/ns#content>,
         RDF.literal("foo", datatype: "http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral")}
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: {input, output}} do
        assert JSON.LD.Decoder.decode!(input) == RDF.Dataset.new(output)
      end
    end)
  end
end
