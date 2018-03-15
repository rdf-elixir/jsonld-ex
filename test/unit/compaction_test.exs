defmodule JSON.LD.CompactionTest do
  use ExUnit.Case, async: false

  alias RDF.NS.{RDFS, XSD}

  test "Flattened form of a JSON-LD document (EXAMPLES 57-59 of https://www.w3.org/TR/json-ld/#compacted-document-form)" do
    input = Jason.decode! """
      [
        {
          "http://xmlns.com/foaf/0.1/name": [ "Manu Sporny" ],
          "http://xmlns.com/foaf/0.1/homepage": [
            {
             "@id": "http://manu.sporny.org/"
            }
          ]
        }
      ]
      """
    context = Jason.decode! """
      {
        "@context": {
          "name": "http://xmlns.com/foaf/0.1/name",
          "homepage": {
            "@id": "http://xmlns.com/foaf/0.1/homepage",
            "@type": "@id"
          }
        }
      }
      """
    assert JSON.LD.compact(input, context) == Jason.decode! """
      {
        "@context": {
          "name": "http://xmlns.com/foaf/0.1/name",
          "homepage": {
            "@id": "http://xmlns.com/foaf/0.1/homepage",
            "@type": "@id"
          }
        },
        "name": "Manu Sporny",
        "homepage": "http://manu.sporny.org/"
      }
      """
  end


  %{
    "prefix" => %{
      input: %{
        "@id" => "http://example.com/a",
        "http://example.com/b" => %{"@id" => "http://example.com/c"}
      },
      context: %{"ex" => "http://example.com/"},
      output: %{
        "@context" => %{"ex" => "http://example.com/"},
        "@id" => "ex:a",
        "ex:b" => %{"@id" => "ex:c"}
      }
    },
    "term" => %{
      input: %{
        "@id" => "http://example.com/a",
        "http://example.com/b" => %{"@id" => "http://example.com/c"}
      },
      context: %{"b" => "http://example.com/b"},
      output: %{
        "@context" => %{"b" => "http://example.com/b"},
        "@id" => "http://example.com/a",
        "b" => %{"@id" => "http://example.com/c"}
      }
    },
    "integer value" => %{
      input: %{
        "@id" => "http://example.com/a",
        "http://example.com/b" => %{"@value" => 1}
      },
      context: %{"b" => "http://example.com/b"},
      output: %{
        "@context" => %{"b" => "http://example.com/b"},
        "@id" => "http://example.com/a",
        "b" => 1
      }
    },
    "boolean value" => %{
      input: %{
        "@id" => "http://example.com/a",
        "http://example.com/b" => %{"@value" => true}
      },
      context: %{"b" => "http://example.com/b"},
      output: %{
        "@context" => %{"b" => "http://example.com/b"},
        "@id" => "http://example.com/a",
        "b" => true
      }
    },
    "@id" => %{
      input: %{"@id" => "http://example.org/test#example"},
      context: %{},
      output: %{}
    },
    "@id coercion" => %{
      input: %{
        "@id" => "http://example.com/a",
        "http://example.com/b" => %{"@id" => "http://example.com/c"}
      },
      context: %{"b" => %{"@id" => "http://example.com/b", "@type" => "@id"}},
      output: %{
        "@context" => %{"b" => %{"@id" => "http://example.com/b", "@type" => "@id"}},
        "@id" => "http://example.com/a",
        "b" => "http://example.com/c"
      }
    },
    "xsd:date coercion" => %{
      input: %{
        "http://example.com/b" => %{"@value" => "2012-01-04", "@type" => to_string(XSD.date)}
      },
      context: %{
        "xsd" => XSD.__base_iri__,
        "b" => %{"@id" => "http://example.com/b", "@type" => "xsd:date"}
      },
      output: %{
        "@context" => %{
          "xsd" => XSD.__base_iri__,
          "b" => %{"@id" => "http://example.com/b", "@type" => "xsd:date"}
        },
        "b" => "2012-01-04"
      }
    },
    "@list coercion" => %{
      input: %{
        "http://example.com/b" => %{"@list" => ["c", "d"]}
      },
      context: %{"b" => %{"@id" => "http://example.com/b", "@container" => "@list"}},
      output: %{
        "@context" => %{"b" => %{"@id" => "http://example.com/b", "@container" => "@list"}},
        "b" => ["c", "d"]
      }
    },
    "@list coercion (integer)" => %{
      input: %{
        "http://example.com/term" => [
          %{"@list" => [1]},
        ]
      },
      context: %{
        "term4" => %{"@id" => "http://example.com/term", "@container" => "@list"},
        "@language" => "de"
      },
      output: %{
        "@context" => %{
          "term4" => %{"@id" => "http://example.com/term", "@container" => "@list"},
          "@language" => "de"
        },
        "term4" => [1],
      }
    },
    "@set coercion" => %{
      input: %{
        "http://example.com/b" => %{"@set" => ["c"]}
      },
      context: %{"b" => %{"@id" => "http://example.com/b", "@container" => "@set"}},
      output: %{
        "@context" => %{"b" => %{"@id" => "http://example.com/b", "@container" => "@set"}},
        "b" => ["c"]
      }
    },
    "empty @set coercion" => %{
      input: %{
        "http://example.com/b" => []
      },
      context: %{"b" => %{"@id" => "http://example.com/b", "@container" => "@set"}},
      output: %{
        "@context" => %{"b" => %{"@id" => "http://example.com/b", "@container" => "@set"}},
        "b" => []
      }
    },
    "@type with string @id" => %{
      input: %{
        "@id" => "http://example.com/",
        "@type" => (RDFS.Resource |> RDF.uri |> to_string)
      },
      context: %{},
      output: %{
        "@id" => "http://example.com/",
        "@type" => (RDFS.Resource |> RDF.uri |> to_string)
      },
    },
    "@type with array @id" => %{
      input: %{
        "@id" => "http://example.com/",
        "@type" => (RDFS.Resource |> RDF.uri |> to_string)
      },
      context: %{},
      output: %{
        "@id" => "http://example.com/",
        "@type" => (RDFS.Resource |> RDF.uri |> to_string)
      },
    },
    "default language" => %{
      input: %{
        "http://example.com/term" => [
          "v5",
          %{"@value" => "plain literal"}
        ]
      },
      context: %{
        "term5" => %{"@id" => "http://example.com/term", "@language" => nil},
        "@language" => "de"
      },
      output: %{
        "@context" => %{
          "term5" => %{"@id" => "http://example.com/term", "@language" => nil},
          "@language" => "de"
        },
        "term5" => [ "v5", "plain literal" ]
      }
    },
  }
  |> Enum.each(fn ({title, data}) ->
       @tag data: data
       test title, %{data: data} do
         assert JSON.LD.compact(data.input, data.context) == data.output
       end
     end)

  describe "keyword aliasing" do
    %{
      "@id" => %{
        input: %{
          "@id" => "",
          "@type" => (RDFS.Resource |> RDF.uri |> to_string)
        },
        context: %{"id" => "@id"},
        output: %{
          "@context" => %{"id" => "@id"},
          "id" => "",
          "@type" => (RDFS.Resource |> RDF.uri |> to_string)
        }
      },
      "@type" => %{
        input: %{
          "@type" => (RDFS.Resource |> RDF.uri |> to_string),
          "http://example.org/foo" => %{"@value" => "bar", "@type" => "http://example.com/type"}
        },
        context: %{"type" => "@type"},
        output: %{
          "@context" => %{"type" => "@type"},
          "type" => (RDFS.Resource |> RDF.uri |> to_string),
          "http://example.org/foo" => %{"@value" => "bar", "type" => "http://example.com/type"}
        }
      },
      "@language" => %{
        input: %{
          "http://example.org/foo" => %{"@value" => "bar", "@language" => "baz"}
        },
        context: %{"language" => "@language"},
        output: %{
          "@context" => %{"language" => "@language"},
          "http://example.org/foo" => %{"@value" => "bar", "language" => "baz"}
        }
      },
      "@value" => %{
        input: %{
          "http://example.org/foo" => %{"@value" => "bar", "@language" => "baz"}
        },
        context: %{"literal" => "@value"},
        output: %{
          "@context" => %{"literal" => "@value"},
          "http://example.org/foo" => %{"literal" => "bar", "@language" => "baz"}
        }
      },
      "@list" => %{
        input: %{
          "http://example.org/foo" => %{"@list" => ["bar"]}
        },
        context: %{"list" => "@list"},
        output: %{
          "@context" => %{"list" => "@list"},
          "http://example.org/foo" => %{"list" => ["bar"]}
        }
      },
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: data} do
           assert JSON.LD.compact(data.input, data.context) == data.output
         end
       end)
  end

  describe "term selection" do
    %{
      "Uses term with nil language when two terms conflict on language" => %{
        input: [%{
          "http://example.com/term" => %{"@value" => "v1"}
        }],
        context: %{
          "term5" => %{"@id" => "http://example.com/term","@language" => nil},
          "@language" => "de"
        },
        output: %{
          "@context" => %{
            "term5" => %{"@id" => "http://example.com/term","@language" => nil},
            "@language" => "de"
          },
          "term5" => "v1",
        }
      },
      "Uses subject alias" => %{
        input: [%{
          "@id" => "http://example.com/id1",
          "http://example.com/id1" => %{"@value" => "foo", "@language" => "de"}
        }],
        context: %{
          "id1" => "http://example.com/id1",
          "@language" => "de"
        },
        output: %{
          "@context" => %{
            "id1" => "http://example.com/id1",
            "@language" => "de"
          },
          "@id" => "http://example.com/id1",
          "id1" => "foo"
        }
      },
      "compact-0007" => %{
        input: Jason.decode!("""
          {"http://example.org/vocab#contains": "this-is-not-an-IRI"}
        """),
        context: Jason.decode!("""
          {
          "ex": "http://example.org/vocab#",
          "ex:contains": {"@type": "@id"}
          }
        """),
        output: Jason.decode!("""
          {
            "@context": {
              "ex": "http://example.org/vocab#",
              "ex:contains": {"@type": "@id"}
            },
            "http://example.org/vocab#contains": "this-is-not-an-IRI"
          }
        """),
      }
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: data} do
           assert JSON.LD.compact(data.input, data.context) == data.output
         end
       end)
  end

  describe "@reverse" do
    %{
      "compact-0033" => %{
        input: Jason.decode!("""
          [
            {
              "@id": "http://example.com/people/markus",
              "@reverse": {
                "http://xmlns.com/foaf/0.1/knows": [
                  {
                    "@id": "http://example.com/people/dave",
                    "http://xmlns.com/foaf/0.1/name": [ { "@value": "Dave Longley" } ]
                  }
                ]
              },
              "http://xmlns.com/foaf/0.1/name": [ { "@value": "Markus Lanthaler" } ]
            }
          ]
        """),
        context: Jason.decode!("""
          {
            "name": "http://xmlns.com/foaf/0.1/name",
            "isKnownBy": { "@reverse": "http://xmlns.com/foaf/0.1/knows" }
          }
        """),
        output: Jason.decode!("""
          {
            "@context": {
              "name": "http://xmlns.com/foaf/0.1/name",
              "isKnownBy": {
                "@reverse": "http://xmlns.com/foaf/0.1/knows"
              }
            },
            "@id": "http://example.com/people/markus",
            "name": "Markus Lanthaler",
            "isKnownBy": {
              "@id": "http://example.com/people/dave",
              "name": "Dave Longley"
            }
          }
        """)
      }
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: data} do
           assert JSON.LD.compact(data.input, data.context) == data.output
         end
       end)
  end

  describe "context as value" do
    test "it includes the context in the output document" do
      context = %{
        "foo" => "http://example.com/"
      }
      input = %{
        "http://example.com/" => "bar"
      }
      expected = %{
        "@context" => %{
          "foo" => "http://example.com/"
        },
        "foo" => "bar"
      }
      assert JSON.LD.compact(input, context) == expected
    end
  end

# TODO:
#  describe "context as reference" do
#    let(:remote_doc) do
#      JSON::LD::API::RemoteDocument.new("http://example.com/context", %q({"@context": {"b": "http://example.com/b"}}))
#    end
#    test "uses referenced context" do
#      input = %{
#        "http://example.com/b" => "c"
#      }
#      expected = %{
#        "@context" => "http://example.com/context",
#        "b" => "c"
#      }
#      allow(JSON::LD::API).to receive(:documentLoader).with("http://example.com/context", anything).and_yield(remote_doc)
#      jld = JSON::LD::API.compact(input, "http://example.com/context", logger: logger, validate: true)
#      expect(jld).to produce(expected, logger)
#    end
#  end

  describe "@list" do
    %{
      "1 term 2 lists 2 languages" => %{
        input: [%{
          "http://example.com/foo" => [
            %{"@list" => [%{"@value" => "en", "@language" => "en"}]},
            %{"@list" => [%{"@value" => "de", "@language" => "de"}]}
          ]
        }],
        context: %{
          "foo_en" => %{"@id" => "http://example.com/foo", "@container" => "@list", "@language" => "en"},
          "foo_de" => %{"@id" => "http://example.com/foo", "@container" => "@list", "@language" => "de"}
        },
        output: %{
          "@context" => %{
            "foo_en" => %{"@id" => "http://example.com/foo", "@container" => "@list", "@language" => "en"},
            "foo_de" => %{"@id" => "http://example.com/foo", "@container" => "@list", "@language" => "de"}
          },
          "foo_en" => ["en"],
          "foo_de" => ["de"]
        }
      },
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: data} do
           assert JSON.LD.compact(data.input, data.context) == data.output
         end
       end)
  end

  describe "language maps" do
    %{
      "compact-0024" => %{
        input: [
          %{
            "@id" => "http://example.com/queen",
            "http://example.com/vocab/label" => [
              %{"@value" => "The Queen", "@language" => "en"},
              %{"@value" => "Die Königin", "@language" => "de"},
              %{"@value" => "Ihre Majestät", "@language" => "de"}
            ]
          }
        ],
        context: %{
          "vocab" => "http://example.com/vocab/",
          "label" => %{"@id" => "vocab:label", "@container" => "@language"}
        },
        output: %{
          "@context" => %{
            "vocab" => "http://example.com/vocab/",
            "label" => %{"@id" => "vocab:label", "@container" => "@language"}
          },
          "@id" => "http://example.com/queen",
          "label" => %{
            "en" => "The Queen",
            "de" => ["Die Königin", "Ihre Majestät"]
          }
        }
      },
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: data} do
           assert JSON.LD.compact(data.input, data.context) == data.output
         end
       end)
  end

  describe "@graph" do
    %{
      "Uses @graph given mutliple inputs" => %{
        input: [
          %{"http://example.com/foo" => ["foo"]},
          %{"http://example.com/bar" => ["bar"]}
        ],
        context: %{"ex" => "http://example.com/"},
        output: %{
          "@context" => %{"ex" => "http://example.com/"},
          "@graph" => [
            %{"ex:foo"  => "foo"},
            %{"ex:bar" => "bar"}
          ]
        }
      },
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: data} do
           assert JSON.LD.compact(data.input, data.context) == data.output
         end
       end)
  end

  describe "exceptions" do
    %{
      "@list containing @list" => %{
        input: %{
          "http://example.org/foo" => %{"@list" => [%{"@list" => ["baz"]}]}
        },
        exception: JSON.LD.ListOfListsError
      },
      "@list containing @list (with coercion)" => %{
        input: %{
          "@context" => %{"http://example.org/foo" => %{"@container" => "@list"}},
          "http://example.org/foo" => [%{"@list" => ["baz"]}]
        },
        exception: JSON.LD.ListOfListsError
      },
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: data} do
           assert_raise data.exception, fn -> JSON.LD.compact(data.input, %{}) end
         end
       end)
  end

end
