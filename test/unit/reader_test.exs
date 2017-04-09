defmodule JSON.LD.ReaderTest do
  use ExUnit.Case, async: false

  doctest JSON.LD.Reader

  alias RDF.{Dataset, Graph}
  alias RDF.NS
  alias RDF.NS.{XSD, RDFS}


  defmodule TestNS do
    use RDF.Vocabulary.Namespace
    defvocab EX, base_uri: "http://example.org/#", terms: [], strict: false
    defvocab S,  base_uri: "http://schema.org/", terms: [], strict: false
  end

  alias TestNS.{EX, S}


  test "an empty JSON document is deserialized to an empty graph" do
    assert JSON.LD.Reader.read!("{}") == Dataset.new(Graph.new)
  end

  describe "unnamed nodes" do
    %{
      "no @id" => {
        ~s({
          "http://example.com/foo": "bar"
        }),
        {RDF.bnode("b0"), RDF.uri("http://example.com/foo"), RDF.literal("bar")}
      },
      "@id with _:a" => {
        ~s({
          "@id": "_:a",
          "http://example.com/foo": "bar"
        }),
        {RDF.bnode("b0"), RDF.uri("http://example.com/foo"), RDF.literal("bar")}
      },
      "@id with _:a and reference" => {
        ~s({
          "@id": "_:a",
          "http://example.com/foo": {"@id": "_:a"}
        }),
        {RDF.bnode("b0"), RDF.uri("http://example.com/foo"), RDF.bnode("b0")}
      },
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: {input, output}} do
           assert JSON.LD.Reader.read_string!(input) == RDF.Dataset.new(output)
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
        {RDF.uri("http://example.com/a"), RDF.uri("http://example.com/foo"), RDF.literal("bar")}
      },
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: {input, output}} do
           assert JSON.LD.Reader.read_string!(input) == RDF.Dataset.new(output)
         end
       end)

    %{
      "base" => {
        ~s({
          "@id": "",
          "@type": "#{RDF.uri(RDFS.Resource)}"
        }),
        {RDF.uri("http://example.org/"), NS.RDF.type, RDF.uri(RDFS.Resource)}
      },
       "relative" => {
        ~s({
          "@id": "a/b",
          "@type": "#{RDF.uri(RDFS.Resource)}"
        }),
        {RDF.uri("http://example.org/a/b"), NS.RDF.type, RDF.uri(RDFS.Resource)}
      },
      "hash" => {
        ~s({
          "@id": "#a",
          "@type": "#{RDF.uri(RDFS.Resource)}"
        }),
        {RDF.uri("http://example.org/#a"), NS.RDF.type, RDF.uri(RDFS.Resource)}
      },
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test "when relative IRIs #{title}", %{data: {input, output}} do
           assert JSON.LD.Reader.read_string!(input, base: "http://example.org/") == 
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
        {RDF.bnode("b0"), NS.RDF.type, RDF.uri("http://example.com/foo")}
      },
      "two types" => {
        ~s({
          "@type": ["http://example.com/foo", "http://example.com/baz"]
        }),
        [
          {RDF.bnode("b0"), NS.RDF.type, RDF.uri("http://example.com/foo")},
          {RDF.bnode("b0"), NS.RDF.type, RDF.uri("http://example.com/baz")},
        ]
      },
      "blank node type" => {
        ~s({
          "@type": "_:foo"
        }),
        {RDF.bnode("b1"), NS.RDF.type, RDF.bnode("b0")}
      }
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: {input, output}} do
           assert JSON.LD.Reader.read_string!(input) == RDF.Dataset.new(output)
         end
       end)
  end

  describe "key/value" do
    %{
      "string" => {
        ~s({
          "http://example.com/foo": "bar"
        }),
        {RDF.bnode("b0"), RDF.uri("http://example.com/foo"), RDF.literal("bar")}
      },
      "strings" => {
        ~s({
          "http://example.com/foo": ["bar", "baz"]
        }),
        [
          {RDF.bnode("b0"), RDF.uri("http://example.com/foo"), RDF.literal("bar")},
          {RDF.bnode("b0"), RDF.uri("http://example.com/foo"), RDF.literal("baz")},
        ]
      },
      "IRI" => {
        ~s({
          "http://example.com/foo": {"@id": "http://example.com/bar"}
        }),
        {RDF.bnode("b0"), RDF.uri("http://example.com/foo"), RDF.uri("http://example.com/bar")}
      },
      "IRIs" => {
        ~s({
          "http://example.com/foo": [{"@id": "http://example.com/bar"}, {"@id": "http://example.com/baz"}]
        }),
        [
          {RDF.bnode("b0"), RDF.uri("http://example.com/foo"), RDF.uri("http://example.com/bar")},
          {RDF.bnode("b0"), RDF.uri("http://example.com/foo"), RDF.uri("http://example.com/baz")},
        ]
      },
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: {input, output}} do
           assert JSON.LD.Reader.read_string!(input) == RDF.Dataset.new(output)
         end
       end)
  end

  describe "literals" do
    %{
      "plain literal" =>
      {
        ~s({"@id": "http://greggkellogg.net/foaf#me", "http://xmlns.com/foaf/0.1/name": "Gregg Kellogg"}),
        {RDF.uri("http://greggkellogg.net/foaf#me"), RDF.uri("http://xmlns.com/foaf/0.1/name"), RDF.literal("Gregg Kellogg")},
      },
      "explicit plain literal" =>
      {
        ~s({"http://xmlns.com/foaf/0.1/name": {"@value": "Gregg Kellogg"}}),
        {RDF.bnode("b0"), RDF.uri("http://xmlns.com/foaf/0.1/name"), RDF.literal("Gregg Kellogg")}
      },
      "language tagged literal" =>
      {
        ~s({"http://www.w3.org/2000/01/rdf-schema#label": {"@value": "A plain literal with a lang tag.", "@language": "en-us"}}),
        {RDF.bnode("b0"), RDFS.label, RDF.literal("A plain literal with a lang tag.", language: "en-us")}
      },
      "I18N literal with language" =>
      {
        ~s([{
          "@id": "http://greggkellogg.net/foaf#me",
          "http://xmlns.com/foaf/0.1/knows": {"@id": "http://www.ivan-herman.net/foaf#me"}
        },{
          "@id": "http://www.ivan-herman.net/foaf#me",
          "http://xmlns.com/foaf/0.1/name": {"@value": "Herman Iván", "@language": "hu"}
        }]),
        [
           {RDF.uri("http://greggkellogg.net/foaf#me"), RDF.uri("http://xmlns.com/foaf/0.1/knows"), RDF.uri("http://www.ivan-herman.net/foaf#me")},
           {RDF.uri("http://www.ivan-herman.net/foaf#me"), RDF.uri("http://xmlns.com/foaf/0.1/name"), RDF.literal("Herman Iv\u00E1n", language: "hu")},
        ]
      },
      "explicit datatyped literal" =>
      {
        ~s({
          "@id":  "http://greggkellogg.net/foaf#me",
          "http://purl.org/dc/terms/created":  {"@value": "1957-02-27", "@type": "http://www.w3.org/2001/XMLSchema#date"}
        }),
        {RDF.uri("http://greggkellogg.net/foaf#me"), RDF.uri("http://purl.org/dc/terms/created"), RDF.literal("1957-02-27", datatype: XSD.date)},
      },
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: {input, output}} do
           assert JSON.LD.Reader.read_string!(input) == RDF.Dataset.new(output)
         end
       end)
  end

  describe "prefixes" do
    %{
       "empty prefix" => {
         ~s({"@context": {"": "http://example.com/default#"}, ":foo": "bar"}),
         {RDF.bnode("b0"), RDF.uri("http://example.com/default#foo"), RDF.literal("bar")}
       },
       # TODO:
       "empty suffix" => {
         ~s({"@context": {"prefix": "http://example.com/default#"}, "prefix:": "bar"}),
         {RDF.bnode("b0"), RDF.uri("http://example.com/default#"), RDF.literal("bar")}
       },
       "prefix:suffix" => {
         ~s({"@context": {"prefix": "http://example.com/default#"}, "prefix:foo": "bar"}),
         {RDF.bnode("b0"), RDF.uri("http://example.com/default#foo"), RDF.literal("bar")}
       }
    }
    |> Enum.each(fn ({title, data}) ->
         if title == "empty suffix", do: @tag :skip
         @tag data: data
         test title, %{data: {input, output}} do
            assert JSON.LD.Reader.read_string!(input) == RDF.Dataset.new(output)
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
           {RDF.uri("http://example.com/about#gregg"), NS.RDF.type, RDF.uri("http://schema.org/Person")},
           {RDF.uri("http://example.com/about#gregg"), RDF.uri("http://schema.org/name"), RDF.literal("Gregg Kellogg")},
        ]
      },
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: {input, output}} do
           assert JSON.LD.Reader.read_string!(input) == RDF.Dataset.new(output)
         end
       end)
  end

  describe "chaining" do
    %{
      "explicit subject" =>
      {
        ~s({
          "@context": {"foaf": "http://xmlns.com/foaf/0.1/"},
          "@id": "http://greggkellogg.net/foaf#me",
          "foaf:knows": {
            "@id": "http://www.ivan-herman.net/foaf#me",
            "foaf:name": "Ivan Herman"
          }
        }),
        [
           {RDF.uri("http://greggkellogg.net/foaf#me"), RDF.uri("http://xmlns.com/foaf/0.1/knows"), RDF.uri("http://www.ivan-herman.net/foaf#me")},
           {RDF.uri("http://www.ivan-herman.net/foaf#me"), RDF.uri("http://xmlns.com/foaf/0.1/name"), RDF.literal("Ivan Herman")},
        ]
      },
      "implicit subject" =>
      {
        ~s({
          "@context": {"foaf": "http://xmlns.com/foaf/0.1/"},
          "@id": "http://greggkellogg.net/foaf#me",
          "foaf:knows": {
            "foaf:name": "Manu Sporny"
          }
        }),
        [
           {RDF.uri("http://greggkellogg.net/foaf#me"), RDF.uri("http://xmlns.com/foaf/0.1/knows"), RDF.bnode("b0")},
           {RDF.bnode("b0"), RDF.uri("http://xmlns.com/foaf/0.1/name"), RDF.literal("Manu Sporny")},
        ]
      },
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: {input, output}} do
           assert JSON.LD.Reader.read_string!(input) == RDF.Dataset.new(output)
         end
       end)
  end

  describe "multiple values" do
    %{
      "literals" =>
      {
        ~s({
          "@context": {"foaf": "http://xmlns.com/foaf/0.1/"},
          "@id": "http://greggkellogg.net/foaf#me",
          "foaf:knows": ["Manu Sporny", "Ivan Herman"]
        }),
        [
           {RDF.uri("http://greggkellogg.net/foaf#me"), RDF.uri("http://xmlns.com/foaf/0.1/knows"), RDF.literal("Manu Sporny")},
           {RDF.uri("http://greggkellogg.net/foaf#me"), RDF.uri("http://xmlns.com/foaf/0.1/knows"), RDF.literal("Ivan Herman")},
        ]
      },
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: {input, output}} do
           assert JSON.LD.Reader.read_string!(input) == RDF.Dataset.new(output)
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
        {RDF.uri("http://greggkellogg.net/foaf#me"), RDF.uri("http://xmlns.com/foaf/0.1/knows"), NS.RDF.nil}
      },
     "single value" => {
       ~s({
         "@context": {"foaf": "http://xmlns.com/foaf/0.1/"},
         "@id": "http://greggkellogg.net/foaf#me",
         "foaf:knows": {"@list": ["Manu Sporny"]}
       }),
       [
          {RDF.uri("http://greggkellogg.net/foaf#me"), RDF.uri("http://xmlns.com/foaf/0.1/knows"), RDF.bnode("b0")},
          {RDF.bnode("b0"), NS.RDF.first, RDF.literal("Manu Sporny")},
          {RDF.bnode("b0"), NS.RDF.rest, NS.RDF.nil},
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
          {RDF.uri("http://greggkellogg.net/foaf#me"), RDF.uri("http://xmlns.com/foaf/0.1/knows"), RDF.bnode("b0")},
          {RDF.bnode("b0"), NS.RDF.first, RDF.literal("Manu Sporny")},
          {RDF.bnode("b0"), NS.RDF.rest, NS.RDF.nil},
       ]
     },
     "multiple values" => {
       ~s({
         "@context": {"foaf": "http://xmlns.com/foaf/0.1/"},
         "@id": "http://greggkellogg.net/foaf#me",
         "foaf:knows": {"@list": ["Manu Sporny", "Dave Longley"]}
       }),
       [
          {RDF.uri("http://greggkellogg.net/foaf#me"), RDF.uri("http://xmlns.com/foaf/0.1/knows"), RDF.bnode("b1")},
          {RDF.bnode("b1"), NS.RDF.first, RDF.literal("Manu Sporny")},
          {RDF.bnode("b1"), NS.RDF.rest, RDF.bnode("b0")},
          {RDF.bnode("b0"), NS.RDF.first, RDF.literal("Dave Longley")},
          {RDF.bnode("b0"), NS.RDF.rest, NS.RDF.nil},
       ]
     },
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: {input, output}} do
           assert JSON.LD.Reader.read_string!(input) == RDF.Dataset.new(output)
         end
       end)
  end

  describe "context" do
    %{
      "@id coersion" =>
      {
        ~s({
          "@context": {
            "knows": {"@id": "http://xmlns.com/foaf/0.1/knows", "@type": "@id"}
          },
          "@id":  "http://greggkellogg.net/foaf#me",
          "knows":  "http://www.ivan-herman.net/foaf#me"
        }),
        {RDF.uri("http://greggkellogg.net/foaf#me"), RDF.uri("http://xmlns.com/foaf/0.1/knows"), RDF.uri("http://www.ivan-herman.net/foaf#me")},
      },
      "datatype coersion" =>
      {
        ~s({
          "@context": {
            "dcterms":  "http://purl.org/dc/terms/",
            "xsd":      "http://www.w3.org/2001/XMLSchema#",
            "created":  {"@id": "http://purl.org/dc/terms/created", "@type": "xsd:date"}
          },
          "@id":  "http://greggkellogg.net/foaf#me",
          "created":  "1957-02-27"
        }),
        {RDF.uri("http://greggkellogg.net/foaf#me"), RDF.uri("http://purl.org/dc/terms/created"), RDF.literal("1957-02-27", datatype: XSD.date)},
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
          {RDF.bnode("b0"), RDF.uri("http://example.com/foo"), RDF.bnode("b1")},
          {RDF.bnode("b1"), RDF.uri("http://example.org/foo"), RDF.literal("bar")},
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
        {RDF.bnode("b0"), RDF.uri("http://example.org/foo"), RDF.literal("bar")},
      },
      "term definition resolves term as IRI" => {
        ~s({
          "@context": [
            {"foo": "http://example.com/foo"},
            {"bar": "foo"}
          ],
          "bar":  "bar"
        }),
        {RDF.bnode("b0"), RDF.uri("http://example.com/foo"), RDF.literal("bar")},
      },
      "term definition resolves prefix as IRI" => {
        ~s({
          "@context": [
            {"foo": "http://example.com/foo#"},
            {"bar": "foo:bar"}
          ],
          "bar":  "bar"
        }),
        {RDF.bnode("b0"), RDF.uri("http://example.com/foo#bar"), RDF.literal("bar")},
      },
      "@language" => {
        ~s({
          "@context": {
            "foo": "http://example.com/foo#",
            "@language": "en"
          },
          "foo:bar":  "baz"
        }),
        {RDF.bnode("b0"), RDF.uri("http://example.com/foo#bar"), RDF.literal("baz", language: "en")},
      },
      "@language with override" => {
        ~s({
          "@context": {
            "foo": "http://example.com/foo#",
            "@language": "en"
          },
          "foo:bar":  {"@value": "baz", "@language": "fr"}
        }),
        {RDF.bnode("b0"), RDF.uri("http://example.com/foo#bar"), RDF.literal("baz", language: "fr")},
      },
      "@language with plain" => {
        ~s({
          "@context": {
            "foo": "http://example.com/foo#",
            "@language": "en"
          },
          "foo:bar":  {"@value": "baz"}
        }),
        {RDF.bnode("b0"), RDF.uri("http://example.com/foo#bar"), RDF.literal("baz")},
      },
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: {input, output}} do
           assert JSON.LD.Reader.read_string!(input) == RDF.Dataset.new(output)
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
        {RDF.bnode("b0"), RDF.uri("http://example.org/foo#"), RDF.literal("bar", datatype: XSD.date)},
      },
      "@id with term" => {
        ~s({
          "@context": [
            {"foo": {"@id": "http://example.org/foo#bar", "@type": "@id"}}
          ],
          "foo": "http://example.org/foo#bar"
        }),
        {RDF.bnode("b0"), RDF.uri("http://example.org/foo#bar"), RDF.uri("http://example.org/foo#bar")},
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
        {RDF.bnode("b0"), RDF.uri("http://purl.org/dc/terms/date"), RDF.literal("2011-11-23", datatype: XSD.date)},
      },
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test "term def with @id + @type coercion: #{title}", %{data: {input, output}} do
           assert JSON.LD.Reader.read_string!(input) == RDF.Dataset.new(output)
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
          {RDF.bnode("b0"), RDF.uri("http://example.org/foo#"), RDF.bnode("b1")},
          {RDF.bnode("b1"), NS.RDF.first, RDF.literal("bar", datatype: XSD.date)},
          {RDF.bnode("b1"), NS.RDF.rest, NS.RDF.nil},
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
          {RDF.bnode("b0"), RDF.uri("http://example.org/foo#bar"), RDF.bnode("b1")},
          {RDF.bnode("b1"), NS.RDF.first, RDF.uri("http://example.org/foo#bar")},
          {RDF.bnode("b1"), NS.RDF.rest, NS.RDF.nil},
        ]
      },
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test "term def with @id + @type + @container list: #{title}", %{data: {input, output}} do
           assert JSON.LD.Reader.read_string!(input) == RDF.Dataset.new(output)
         end
       end)
  end

  describe "blank node predicates" do
    setup do
      {:ok, input: ~s({"@id": "http://example/subj", "_:foo": "bar"})}
    end

    test "outputs statements with blank node predicates if :produceGeneralizedRdf is true",
      %{input: input} do
       dataset = JSON.LD.Reader.read_string!(input, produce_generalized_rdf: true)
       assert RDF.Dataset.statement_count(dataset) == 1
    end

    test "rejects statements with blank node predicates if :produceGeneralizedRdf is false",
      %{input: input} do
       dataset = JSON.LD.Reader.read_string!(input, produce_generalized_rdf: false)
       assert RDF.Dataset.statement_count(dataset) == 0
    end
  end

  describe "advanced features" do
    %{
      # TODO:
      "number syntax (decimal)" =>
      {
        ~s({"@context": { "measure": "http://example/measure#"}, "measure:cups": 5.3}),
        {RDF.bnode("b0"), RDF.uri("http://example/measure#cups"), RDF.literal("5.3E0", datatype: XSD.double)}
      },
      # TODO:
      "number syntax (double)" =>
      {
        ~s({"@context": { "measure": "http://example/measure#"}, "measure:cups": 5.3e0}),
        {RDF.bnode("b0"), RDF.uri("http://example/measure#cups"), RDF.literal("5.3E0", datatype: XSD.double)}
      },
     "number syntax (integer)" =>
     {
       ~s({"@context": { "chem": "http://example/chem#"}, "chem:protons": 12}),
       {RDF.bnode("b0"), RDF.uri("http://example/chem#protons"), RDF.literal("12", datatype: XSD.integer)}
     },
     "boolan syntax" =>
     {
       ~s({"@context": { "sensor": "http://example/sensor#"}, "sensor:active": true}),
       {RDF.bnode("b0"), RDF.uri("http://example/sensor#active"), RDF.literal("true", datatype: XSD.boolean)}
     },
     "Array top element" =>
     {
       ~s([
         {"@id":   "http://example.com/#me", "@type": "http://xmlns.com/foaf/0.1/Person"},
         {"@id":   "http://example.com/#you", "@type": "http://xmlns.com/foaf/0.1/Person"}
       ]),
       [
         {RDF.uri("http://example.com/#me"), NS.RDF.type, RDF.uri("http://xmlns.com/foaf/0.1/Person")},
         {RDF.uri("http://example.com/#you"), NS.RDF.type, RDF.uri("http://xmlns.com/foaf/0.1/Person")}
       ]
     },
     "@graph with array of objects value" =>
     {
       ~s({
         "@context": {"foaf": "http://xmlns.com/foaf/0.1/"},
         "@graph": [
           {"@id":   "http://example.com/#me", "@type": "foaf:Person"},
           {"@id":   "http://example.com/#you", "@type": "foaf:Person"}
         ]
       }),
       [
         {RDF.uri("http://example.com/#me"), NS.RDF.type, RDF.uri("http://xmlns.com/foaf/0.1/Person")},
         {RDF.uri("http://example.com/#you"), NS.RDF.type, RDF.uri("http://xmlns.com/foaf/0.1/Person")}
       ]
     },
     "XMLLiteral" =>
     {
       ~s({
         "http://rdfs.org/sioc/ns#content": {
           "@value": "foo",
           "@type": "http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral"
         }
       }),
       {RDF.bnode("b0"), RDF.uri("http://rdfs.org/sioc/ns#content"), RDF.literal("foo", datatype: "http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral")}
     }
    }
    |> Enum.each(fn ({title, data}) ->
         if title in ["number syntax (decimal)", "number syntax (double)"] do
           @tag skip: "support float literals with exponential notation"
         end
         @tag data: data
         test title, %{data: {input, output}} do
           assert JSON.LD.Reader.read_string!(input) == RDF.Dataset.new(output)
         end
       end)
  end

end
