defmodule JSON.LD.FlatteningTest do
  use JSON.LD.Case, async: false

  doctest JSON.LD.Flattening

  alias RDF.NS.RDFS

  test "Flattened form of a JSON-LD document (EXAMPLE 60 and 61 of https://www.w3.org/TR/json-ld/#flattened-document-form)" do
    input =
      Jason.decode!("""
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
      """)

    assert JSON.LD.flatten(input, input) ==
             Jason.decode!("""
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
             """)
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
        "foaf:primaryTopic" => [
          %{
            "@id" => "http://greggkellogg.net/foaf#me",
            "@type" => ["foaf:Person"]
          }
        ]
      },
      output: [
        %{
          "@id" => "http://greggkellogg.net/foaf",
          "@type" => ["http://xmlns.com/foaf/0.1/PersonalProfileDocument"],
          "http://xmlns.com/foaf/0.1/primaryTopic" => [
            %{"@id" => "http://greggkellogg.net/foaf#me"}
          ]
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
      input:
        Jason.decode!("""
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
      output:
        Jason.decode!("""
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
      input:
        Jason.decode!("""
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
      output:
        Jason.decode!("""
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
      input:
        Jason.decode!("""
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
      output:
        Jason.decode!("""
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
      input:
        Jason.decode!("""
          {
            "@context": {
              "foo": "http://example.org/foo",
              "bar": { "@reverse": "http://example.org/bar", "@type": "@id" }
            },
            "foo": "Foo",
            "bar": [ "http://example.org/origin", "_:b0" ]
          }
        """),
      output:
        Jason.decode!("""
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
    },
    "@list with embedded object" => %{
      input:
        Jason.decode!("""
          [{
            "http://example.com/foo": [{
              "@list": [{
                "@id": "http://example.com/baz",
                "http://example.com/bar": "buz"}
              ]}
            ]}
          ]
        """),
      output:
        Jason.decode!("""
          [
            {
              "@id": "_:b0",
              "http://example.com/foo": [{
                "@list": [
                  {
                    "@id": "http://example.com/baz"
                  }
                ]
              }]
            },
            {
              "@id": "http://example.com/baz",
              "http://example.com/bar": [{"@value": "buz"}]
            }
          ]
        """)
    },
    "coerced @list containing an deep list" => %{
      input:
        Jason.decode!("""
          [{
            "http://example.com/foo": [{"@list": [{"@list": [{"@list": [{"@value": "baz"}]}]}]}]
          }]
        """),
      output:
        Jason.decode!("""
          [{
            "@id": "_:b0",
            "http://example.com/foo": [{"@list": [{"@list": [{"@list": [{"@value": "baz"}]}]}]}]
          }]
        """)
    },
    "@list containing empty @list" => %{
      input:
        Jason.decode!("""
          {
            "http://example.com/foo": {"@list": [{"@list": []}]}
          }
        """),
      output:
        Jason.decode!("""
          [{
            "@id": "_:b0",
            "http://example.com/foo": [{"@list": [{"@list": []}]}]
          }]
        """)
    },
    "coerced @list containing mixed list values" => %{
      input:
        Jason.decode!("""
          {
            "@context": {"foo": {"@id": "http://example.com/foo", "@container": "@list"}},
            "foo": [
              [{"@id": "http://example/a", "@type": "http://example/Bar"}],
              {"@id": "http://example/b", "@type": "http://example/Baz"}]
          }
        """),
      output:
        Jason.decode!("""
          [{
            "@id": "_:b0",
            "http://example.com/foo": [{"@list": [
              {"@list": [{"@id": "http://example/a"}]},
              {"@id": "http://example/b"}
            ]}]
          },
          {
            "@id": "http://example/a",
            "@type": [
              "http://example/Bar"
            ]
          },
          {
            "@id": "http://example/b",
            "@type": [
              "http://example/Baz"
            ]
          }]
        """)
    },
    "Basic Included array" => %{
      input:
        Jason.decode!("""
          {
            "@context": {
              "@version": 1.1,
              "@vocab": "http://example.org/"
            },
            "prop": "value",
            "@included": [{
              "prop": "value2"
            }]
          }
        """),
      output:
        Jason.decode!("""
          [{
            "@id": "_:b0",
            "http://example.org/prop": [{"@value": "value"}]
          }, {
            "@id": "_:b1",
            "http://example.org/prop": [{"@value": "value2"}]
          }]
        """)
    },
    "Basic Included object" => %{
      input:
        Jason.decode!("""
          {
            "@context": {
              "@version": 1.1,
              "@vocab": "http://example.org/"
            },
            "prop": "value",
            "@included": {
              "prop": "value2"
            }
          }
        """),
      output:
        Jason.decode!("""
          [{
            "@id": "_:b0",
            "http://example.org/prop": [{"@value": "value"}]
          }, {
            "@id": "_:b1",
            "http://example.org/prop": [{"@value": "value2"}]
          }]
        """)
    },
    "Multiple properties mapping to @included are folded together" => %{
      input:
        Jason.decode!("""
          {
            "@context": {
              "@version": 1.1,
              "@vocab": "http://example.org/",
              "included1": "@included",
              "included2": "@included"
            },
            "included1": {"prop": "value1"},
            "included2": {"prop": "value2"}
          }
        """),
      output:
        Jason.decode!("""
          [{
            "@id": "_:b1",
            "http://example.org/prop": [{"@value": "value2"}]
          }, {
            "@id": "_:b2",
            "http://example.org/prop": [{"@value": "value1"}]
          }]
        """)
    },
    "Included containing @included" => %{
      input:
        Jason.decode!("""
          {
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
          }
        """),
      output:
        Jason.decode!("""
          [{
            "@id": "_:b0",
            "http://example.org/prop": [{"@value": "value"}]
          }, {
            "@id": "_:b1",
            "http://example.org/prop": [{"@value": "value2"}]
          }, {
            "@id": "_:b2",
            "http://example.org/prop": [{"@value": "value3"}]
          }]
        """)
    },
    "Property value with @included" => %{
      input:
        Jason.decode!("""
          {
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
          }
        """),
      output:
        Jason.decode!("""
          [{
            "@id": "_:b0",
            "http://example.org/prop": [
              {"@id": "_:b1"}
            ]
          }, {
            "@id": "_:b1",
            "@type": ["http://example.org/Foo"]
          }, {
            "@id": "_:b2",
            "@type": ["http://example.org/Bar"]
          }]
        """)
    }
  }
  |> Enum.each(fn {title, data} ->
    @tag data: data
    test title, %{data: data} do
      assert JSON.LD.flatten(data.input) == data.output
    end
  end)

  test "json.api example" do
    input =
      Jason.decode!("""
        {
          "@context": {
            "@version": 1.1,
            "@vocab": "http://example.org/vocab#",
            "@base": "http://example.org/base/",
            "id": "@id",
            "type": "@type",
            "data": "@nest",
            "attributes": "@nest",
            "links": "@nest",
            "relationships": "@nest",
            "included": "@included",
            "self": {"@type": "@id"},
            "related": {"@type": "@id"},
            "comments": {
              "@context": {
                "data": null
              }
            }
          },
          "data": [{
            "type": "articles",
            "id": "1",
            "attributes": {
              "title": "JSON:API paints my bikeshed!"
            },
            "links": {
              "self": "http://example.com/articles/1"
            },
            "relationships": {
              "author": {
                "links": {
                  "self": "http://example.com/articles/1/relationships/author",
                  "related": "http://example.com/articles/1/author"
                },
                "data": { "type": "people", "id": "9" }
              },
              "comments": {
                "links": {
                  "self": "http://example.com/articles/1/relationships/comments",
                  "related": "http://example.com/articles/1/comments"
                },
                "data": [
                  { "type": "comments", "id": "5" },
                  { "type": "comments", "id": "12" }
                ]
              }
            }
          }],
          "included": [{
            "type": "people",
            "id": "9",
            "attributes": {
              "first-name": "Dan",
              "last-name": "Gebhardt",
              "twitter": "dgeb"
            },
            "links": {
              "self": "http://example.com/people/9"
            }
          }, {
            "type": "comments",
            "id": "5",
            "attributes": {
              "body": "First!"
            },
            "relationships": {
              "author": {
                "data": { "type": "people", "id": "2" }
              }
            },
            "links": {
              "self": "http://example.com/comments/5"
            }
          }, {
            "type": "comments",
            "id": "12",
            "attributes": {
              "body": "I like XML better"
            },
            "relationships": {
              "author": {
                "data": { "type": "people", "id": "9" }
              }
            },
            "links": {
              "self": "http://example.com/comments/12"
            }
          }]
        }
      """)

    output =
      Jason.decode!("""
        [{
          "@id": "_:b0",
          "http://example.org/vocab#self": [{"@id": "http://example.com/articles/1/relationships/comments"}
          ],
          "http://example.org/vocab#related": [{"@id": "http://example.com/articles/1/comments"}]
        }, {
          "@id": "http://example.org/base/1",
          "@type": ["http://example.org/vocab#articles"],
          "http://example.org/vocab#title": [{"@value": "JSON:API paints my bikeshed!"}],
          "http://example.org/vocab#self": [{"@id": "http://example.com/articles/1"}],
          "http://example.org/vocab#author": [{"@id": "http://example.org/base/9"}],
          "http://example.org/vocab#comments": [{"@id": "_:b0"}]
        }, {
          "@id": "http://example.org/base/12",
          "@type": ["http://example.org/vocab#comments"],
          "http://example.org/vocab#body": [{"@value": "I like XML better"}],
          "http://example.org/vocab#author": [{"@id": "http://example.org/base/9"}],
          "http://example.org/vocab#self": [{"@id": "http://example.com/comments/12"}]
        }, {
          "@id": "http://example.org/base/2",
          "@type": ["http://example.org/vocab#people"]
        }, {
          "@id": "http://example.org/base/5",
          "@type": ["http://example.org/vocab#comments"],
          "http://example.org/vocab#body": [{"@value": "First!"}
          ],
          "http://example.org/vocab#author": [{"@id": "http://example.org/base/2"}],
          "http://example.org/vocab#self": [{"@id": "http://example.com/comments/5"}]
        }, {
          "@id": "http://example.org/base/9",
          "@type": ["http://example.org/vocab#people"],
          "http://example.org/vocab#first-name": [{"@value": "Dan"}],
          "http://example.org/vocab#last-name": [{"@value": "Gebhardt"}],
          "http://example.org/vocab#twitter": [{"@value": "dgeb"}],
          "http://example.org/vocab#self": [
            {"@id": "http://example.com/people/9"},
            {"@id": "http://example.com/articles/1/relationships/author"}
          ],
          "http://example.org/vocab#related": [{"@id": "http://example.com/articles/1/author"}]
        }]
      """)

    assert JSON.LD.flatten(input) == output
  end

  describe "remote document handling" do
    setup do
      bypass = Bypass.open()
      {:ok, bypass: bypass}
    end

    test "flattens a document from a URL", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert "GET" == conn.method
        assert "/document.jsonld" == conn.request_path

        json_content =
          Jason.encode!(%{
            "@context" => %{
              "name" => "http://xmlns.com/foaf/0.1/name",
              "knows" => "http://xmlns.com/foaf/0.1/knows"
            },
            "@id" => "http://me.example.com/",
            "name" => "Alice",
            "knows" => [
              %{
                "@id" => "http://bob.example.com/",
                "name" => "Bob"
              },
              %{
                "name" => "Charlie"
              }
            ]
          })

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, json_content)
      end)

      url = "http://localhost:#{bypass.port}/document.jsonld"

      assert JSON.LD.flatten(url) == [
               %{
                 "@id" => "_:b0",
                 "http://xmlns.com/foaf/0.1/name" => [%{"@value" => "Charlie"}]
               },
               %{
                 "@id" => "http://bob.example.com/",
                 "http://xmlns.com/foaf/0.1/name" => [%{"@value" => "Bob"}]
               },
               %{
                 "@id" => "http://me.example.com/",
                 "http://xmlns.com/foaf/0.1/name" => [%{"@value" => "Alice"}],
                 "http://xmlns.com/foaf/0.1/knows" => [
                   %{"@id" => "http://bob.example.com/"},
                   %{"@id" => "_:b0"}
                 ]
               }
             ]
    end

    test "flattens a document from a URL with context compaction", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert "GET" == conn.method
        assert "/document.jsonld" == conn.request_path

        json_content =
          Jason.encode!(%{
            "@context" => %{
              "name" => "http://xmlns.com/foaf/0.1/name",
              "knows" => "http://xmlns.com/foaf/0.1/knows"
            },
            "@id" => "http://me.example.com/",
            "name" => "Alice",
            "knows" => [
              %{
                "@id" => "http://bob.example.com/",
                "name" => "Bob"
              }
            ]
          })

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, json_content)
      end)

      url = "http://localhost:#{bypass.port}/document.jsonld"

      context = %{
        "@context" => %{
          "foaf" => "http://xmlns.com/foaf/0.1/",
          "name" => "foaf:name",
          "knows" => "foaf:knows"
        }
      }

      assert JSON.LD.flatten(url, context) == %{
               "@context" => %{
                 "foaf" => "http://xmlns.com/foaf/0.1/",
                 "name" => "foaf:name",
                 "knows" => "foaf:knows"
               },
               "@graph" => [
                 %{
                   "@id" => "http://bob.example.com/",
                   "name" => "Bob"
                 },
                 %{
                   "@id" => "http://me.example.com/",
                   "name" => "Alice",
                   "knows" => %{"@id" => "http://bob.example.com/"}
                 }
               ]
             }
    end

    test "flattens a document with relative IRIs", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert "GET" == conn.method
        assert "/document.jsonld" == conn.request_path

        json_content =
          Jason.encode!(%{
            "@context" => %{
              "name" => "http://xmlns.com/foaf/0.1/name",
              "knows" => "http://xmlns.com/foaf/0.1/knows"
            },
            # Änderung hier: expliziter relativer Pfad statt leerer String
            "@id" => "document.jsonld",
            "name" => "Alice",
            "knows" => [%{"@id" => "bob", "name" => "Bob"}]
          })

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, json_content)
      end)

      url = "http://localhost:#{bypass.port}/document.jsonld"

      context = %{
        "@context" => %{
          "foaf" => "http://xmlns.com/foaf/0.1/",
          "name" => "foaf:name",
          "knows" => "foaf:knows"
        }
      }

      assert JSON.LD.flatten(url, context, compact_to_relative: false) == %{
               "@context" => %{
                 "foaf" => "http://xmlns.com/foaf/0.1/",
                 "name" => "foaf:name",
                 "knows" => "foaf:knows"
               },
               "@graph" => [
                 %{
                   "@id" => "http://localhost:#{bypass.port}/bob",
                   "name" => "Bob"
                 },
                 %{
                   "@id" => "http://localhost:#{bypass.port}/document.jsonld",
                   "name" => "Alice",
                   "knows" => %{"@id" => "http://localhost:#{bypass.port}/bob"}
                 }
               ]
             }

      assert JSON.LD.flatten(url, context) == %{
               "@context" => %{
                 "foaf" => "http://xmlns.com/foaf/0.1/",
                 "name" => "foaf:name",
                 "knows" => "foaf:knows"
               },
               "@graph" => [
                 %{
                   "@id" => "bob",
                   "name" => "Bob"
                 },
                 %{
                   "@id" => "document.jsonld",
                   "name" => "Alice",
                   "knows" => %{"@id" => "bob"}
                 }
               ]
             }
    end

    test "handles failed remote document loading", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        Plug.Conn.resp(conn, 404, "Not Found")
      end)

      url = "http://localhost:#{bypass.port}/document.jsonld"

      assert_raise JSON.LD.LoadingDocumentFailedError,
                   "HTTP request failed with status 404",
                   fn -> JSON.LD.flatten(url) end
    end
  end
end
