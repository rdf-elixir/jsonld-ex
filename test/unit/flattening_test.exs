defmodule JSON.LD.FlatteningTest do
  use ExUnit.Case, async: false

  alias RDF.NS.RDFS

  test "Flattened form of a JSON-LD document (EXAMPLE 60 and 61 of https://www.w3.org/TR/json-ld/#flattened-document-form)" do
    input = Jason.decode! """
      {
        "@context": {
          "name": "http://xmlns.com/foaf/0.1/name",
          "knows": "http://xmlns.com/foaf/0.1/knows"
        },
        "@id": "http://me.markus-lanthaler.com/",
        "name": "Markus Lanthaler",
        "knows": [
          {
            "@id": "http://manu.sporny.org/about#manu",
            "name": "Manu Sporny"
          },
          {
            "name": "Dave Longley"
          }
        ]
      }
      """
    assert JSON.LD.flatten(input, input) == Jason.decode! """
      {
        "@context": {
          "name": "http://xmlns.com/foaf/0.1/name",
          "knows": "http://xmlns.com/foaf/0.1/knows"
        },
        "@graph": [
          {
            "@id": "_:b0",
            "name": "Dave Longley"
          },
          {
            "@id": "http://manu.sporny.org/about#manu",
            "name": "Manu Sporny"
          },
          {
            "@id": "http://me.markus-lanthaler.com/",
            "name": "Markus Lanthaler",
            "knows": [
              { "@id": "http://manu.sporny.org/about#manu" },
              { "@id": "_:b0" }
            ]
          }
        ]
      }
      """
  end


  %{
    "single object" => %{
      input: %{"@id" => "http://example.com", "@type" => to_string(RDF.uri(RDFS.Resource))},
      output: [
        %{"@id" => "http://example.com", "@type" => [to_string(RDF.uri(RDFS.Resource))]}
      ]
    },
    "embedded object" => %{
      input: %{
        "@context" => %{
          "foaf" => "http://xmlns.com/foaf/0.1/"
        },
        "@id" => "http://greggkellogg.net/foaf",
        "@type" => ["foaf:PersonalProfileDocument"],
        "foaf:primaryTopic" => [%{
          "@id" => "http://greggkellogg.net/foaf#me",
          "@type" => ["foaf:Person"]
        }]
      },
      output: [
        %{
          "@id" => "http://greggkellogg.net/foaf",
          "@type" => ["http://xmlns.com/foaf/0.1/PersonalProfileDocument"],
          "http://xmlns.com/foaf/0.1/primaryTopic" => [%{"@id" => "http://greggkellogg.net/foaf#me"}]
        },
        %{
          "@id" => "http://greggkellogg.net/foaf#me",
          "@type" => ["http://xmlns.com/foaf/0.1/Person"]
        }
      ]
    },
    "embedded anon" => %{
      input: %{
        "@context" => %{
          "foaf" => "http://xmlns.com/foaf/0.1/"
        },
        "@id" => "http://greggkellogg.net/foaf",
        "@type" => "foaf:PersonalProfileDocument",
        "foaf:primaryTopic" => %{
          "@type" => "foaf:Person"
        }
      },
      output: [
        %{
          "@id" => "_:b0",
          "@type" => ["http://xmlns.com/foaf/0.1/Person"]
        },
        %{
          "@id" => "http://greggkellogg.net/foaf",
          "@type" => ["http://xmlns.com/foaf/0.1/PersonalProfileDocument"],
          "http://xmlns.com/foaf/0.1/primaryTopic" => [%{"@id" => "_:b0"}]
        }
      ]
    },
    "reverse properties" => %{
      input: Jason.decode!("""
        [
          {
            "@id": "http://example.com/people/markus",
            "@reverse": {
              "http://xmlns.com/foaf/0.1/knows": [
                {
                  "@id": "http://example.com/people/dave"
                },
                {
                  "@id": "http://example.com/people/gregg"
                }
              ]
            },
            "http://xmlns.com/foaf/0.1/name": [ { "@value": "Markus Lanthaler" } ]
          }
        ]
      """),
      output: Jason.decode!("""
        [
          {
            "@id": "http://example.com/people/dave",
            "http://xmlns.com/foaf/0.1/knows": [
              {
                "@id": "http://example.com/people/markus"
              }
            ]
          },
          {
            "@id": "http://example.com/people/gregg",
            "http://xmlns.com/foaf/0.1/knows": [
              {
                "@id": "http://example.com/people/markus"
              }
            ]
          },
          {
            "@id": "http://example.com/people/markus",
            "http://xmlns.com/foaf/0.1/name": [
              {
                "@value": "Markus Lanthaler"
              }
            ]
          }
        ]
      """)
    },
    "Simple named graph (Wikidata)" => %{
      input: Jason.decode!("""
      {
        "@context": {
          "rdf": "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
          "ex": "http://example.org/",
          "xsd": "http://www.w3.org/2001/XMLSchema#",
          "ex:locatedIn": {"@type": "@id"},
          "ex:hasPopulaton": {"@type": "xsd:integer"},
          "ex:hasReference": {"@type": "@id"}
        },
        "@graph": [
          {
            "@id": "http://example.org/ParisFact1",
            "@type": "rdf:Graph",
            "@graph": {
              "@id": "http://example.org/location/Paris#this",
              "ex:locatedIn": "http://example.org/location/France#this"
            },
            "ex:hasReference": ["http://www.britannica.com/", "http://www.wikipedia.org/", "http://www.brockhaus.de/"]
          },
          {
            "@id": "http://example.org/ParisFact2",
            "@type": "rdf:Graph",
            "@graph": {
              "@id": "http://example.org/location/Paris#this",
              "ex:hasPopulation": 7000000
            },
            "ex:hasReference": "http://www.wikipedia.org/"
          }
        ]
      }
      """),
      output: Jason.decode!("""
        [{
        "@id": "http://example.org/ParisFact1",
        "@type": ["http://www.w3.org/1999/02/22-rdf-syntax-ns#Graph"],
        "http://example.org/hasReference": [
          {"@id": "http://www.britannica.com/"},
          {"@id": "http://www.wikipedia.org/"},
          {"@id": "http://www.brockhaus.de/"}
        ],
        "@graph": [{
            "@id": "http://example.org/location/Paris#this",
            "http://example.org/locatedIn": [{"@id": "http://example.org/location/France#this"}]
          }]
        }, {
          "@id": "http://example.org/ParisFact2",
          "@type": ["http://www.w3.org/1999/02/22-rdf-syntax-ns#Graph"],
          "http://example.org/hasReference": [{"@id": "http://www.wikipedia.org/"}],
          "@graph": [{
            "@id": "http://example.org/location/Paris#this",
            "http://example.org/hasPopulation": [{"@value": 7000000}]
          }]
        }]
      """)
    },
    "Test Manifest (shortened)" => %{
      input: Jason.decode!("""
        {
          "@id": "",
          "http://example/sequence": {"@list": [
            {
              "@id": "#t0001",
              "http://example/name": "Keywords cannot be aliased to other keywords",
              "http://example/input": {"@id": "error-expand-0001-in.jsonld"}
            }
          ]}
        }
      """),
      output: Jason.decode!("""
        [{
          "@id": "",
          "http://example/sequence": [{"@list": [{"@id": "#t0001"}]}]
        }, {
          "@id": "#t0001",
          "http://example/input": [{"@id": "error-expand-0001-in.jsonld"}],
          "http://example/name": [{"@value": "Keywords cannot be aliased to other keywords"}]
        }]
      """),
      options: %{}
    },
    "@reverse bnode issue (0045)" => %{
      input: Jason.decode!("""
        {
          "@context": {
            "foo": "http://example.org/foo",
            "bar": { "@reverse": "http://example.org/bar", "@type": "@id" }
          },
          "foo": "Foo",
          "bar": [ "http://example.org/origin", "_:b0" ]
        }
      """),
      output: Jason.decode!("""
        [
          {
            "@id": "_:b0",
            "http://example.org/foo": [ { "@value": "Foo" } ]
          },
          {
            "@id": "_:b1",
            "http://example.org/bar": [ { "@id": "_:b0" } ]
          },
          {
            "@id": "http://example.org/origin",
            "http://example.org/bar": [ { "@id": "_:b0" } ]
          }
        ]
      """),
      options: %{}
    }
  }
  |> Enum.each(fn ({title, data}) ->
       @tag data: data
       test title, %{data: data} do
         assert JSON.LD.flatten(data.input) == data.output
       end
     end)

end
