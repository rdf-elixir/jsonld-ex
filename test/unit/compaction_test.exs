defmodule JSON.LD.CompactionTest do
  use JSON.LD.Case, async: false

  doctest JSON.LD.Compaction

  test "Flattened form of a JSON-LD document (EXAMPLES 57-59 of https://www.w3.org/TR/json-ld/#compacted-document-form)" do
    input =
      Jason.decode!("""
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
      """)

    context =
      Jason.decode!("""
      {
        "@context": {
          "name": "http://xmlns.com/foaf/0.1/name",
          "homepage": {
            "@id": "http://xmlns.com/foaf/0.1/homepage",
            "@type": "@id"
          }
        }
      }
      """)

    assert JSON.LD.compact(input, context) ==
             Jason.decode!("""
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
             """)
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
        "http://example.com/b" => %{"@value" => "2012-01-04", "@type" => to_string(XSD.date())}
      },
      context: %{
        "xsd" => XSD.__base_iri__(),
        "b" => %{"@id" => "http://example.com/b", "@type" => "xsd:date"}
      },
      output: %{
        "@context" => %{
          "xsd" => XSD.__base_iri__(),
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
          %{"@list" => [1]}
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
        "term4" => [1]
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
    "@set coercion on @type" => %{
      input: %{
        "@type" => "http://www.w3.org/2000/01/rdf-schema#Resource",
        "http://example.org/foo" => %{"@value" => "bar", "@type" => "http://example.com/type"}
      },
      context: %{"@version" => 1.1, "@type" => %{"@container" => "@set"}},
      output: %{
        "@context" => %{"@version" => 1.1, "@type" => %{"@container" => "@set"}},
        "@type" => ["http://www.w3.org/2000/01/rdf-schema#Resource"],
        "http://example.org/foo" => %{"@value" => "bar", "@type" => ["http://example.com/type"]}
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
        "@type" => RDFS.Resource |> RDF.iri() |> to_string()
      },
      context: %{},
      output: %{
        "@id" => "http://example.com/",
        "@type" => RDFS.Resource |> RDF.iri() |> to_string()
      }
    },
    "@type with array @id" => %{
      input: %{
        "@id" => "http://example.com/",
        "@type" => [RDFS.Resource |> RDF.iri() |> to_string()]
      },
      context: %{},
      output: %{
        "@id" => "http://example.com/",
        "@type" => RDFS.Resource |> RDF.iri() |> to_string()
      }
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
        "term5" => ["v5", "plain literal"]
      }
    },
    "default direction" => %{
      input: %{
        "http://example.com/term" => [
          "v5",
          %{"@value" => "plain literal"}
        ]
      },
      context: %{
        "term5" => %{"@id" => "http://example.com/term", "@direction" => nil},
        "@direction" => "ltr"
      },
      output: %{
        "@context" => %{
          "term5" => %{"@id" => "http://example.com/term", "@direction" => nil},
          "@direction" => "ltr"
        },
        "term5" => ["v5", "plain literal"]
      }
    }
  }
  |> Enum.each(fn {title, data} ->
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
          "@type" => RDFS.Resource |> RDF.iri() |> to_string()
        },
        context: %{"id" => "@id"},
        output: %{
          "@context" => %{"id" => "@id"},
          "id" => "",
          "@type" => RDFS.Resource |> RDF.iri() |> to_string()
        }
      },
      "@type" => %{
        input: %{
          "@type" => RDFS.Resource |> RDF.iri() |> to_string(),
          "http://example.org/foo" => %{"@value" => "bar", "@type" => "http://example.com/type"}
        },
        context: %{"type" => "@type"},
        output: %{
          "@context" => %{"type" => "@type"},
          "type" => RDFS.Resource |> RDF.iri() |> to_string(),
          "http://example.org/foo" => %{"@value" => "bar", "type" => "http://example.com/type"}
        }
      },
      "@type with @container: @set" => %{
        input: %{
          "@type" => RDFS.Resource |> RDF.iri() |> to_string(),
          "http://example.org/foo" => %{"@value" => "bar", "@type" => "http://example.com/type"}
        },
        context: %{"@version" => 1.1, "type" => %{"@id" => "@type", "@container" => "@set"}},
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "type" => %{"@id" => "@type", "@container" => "@set"}
          },
          "type" => [RDFS.Resource |> RDF.iri() |> to_string()],
          "http://example.org/foo" => %{"@value" => "bar", "type" => ["http://example.com/type"]}
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
      "@direction" => %{
        input: %{
          "http://example.org/foo" => %{"@value" => "bar", "@direction" => "ltr"}
        },
        context: %{"direction" => "@direction"},
        output: %{
          "@context" => %{"direction" => "@direction"},
          "http://example.org/foo" => %{"@value" => "bar", "direction" => "ltr"}
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
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        assert JSON.LD.compact(data.input, data.context) == data.output
      end
    end)
  end

  describe "term selection" do
    %{
      "Uses term with nil language when two terms conflict on language" => %{
        input: [
          %{
            "http://example.com/term" => %{"@value" => "v1"}
          }
        ],
        context: %{
          "term5" => %{"@id" => "http://example.com/term", "@language" => nil},
          "@language" => "de"
        },
        output: %{
          "@context" => %{
            "term5" => %{"@id" => "http://example.com/term", "@language" => nil},
            "@language" => "de"
          },
          "term5" => "v1"
        }
      },
      "Uses term with nil direction when two terms conflict on direction" => %{
        input: [
          %{
            "http://example.com/term" => %{"@value" => "v1"}
          }
        ],
        context: %{
          "term5" => %{"@id" => "http://example.com/term", "@direction" => nil},
          "@direction" => "ltr"
        },
        output: %{
          "@context" => %{
            "term5" => %{"@id" => "http://example.com/term", "@direction" => nil},
            "@direction" => "ltr"
          },
          "term5" => "v1"
        }
      },
      "Uses subject alias" => %{
        input: [
          %{
            "@id" => "http://example.com/id1",
            "http://example.com/id1" => %{"@value" => "foo", "@language" => "de"}
          }
        ],
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
        input:
          Jason.decode!("""
            {"http://example.org/vocab#contains": "this-is-not-an-IRI"}
          """),
        context:
          Jason.decode!("""
            {
            "ex": "http://example.org/vocab#",
            "ex:contains": {"@type": "@id"}
            }
          """),
        output:
          Jason.decode!("""
            {
              "@context": {
                "ex": "http://example.org/vocab#",
                "ex:contains": {"@type": "@id"}
              },
              "http://example.org/vocab#contains": "this-is-not-an-IRI"
            }
          """)
      },
      "Language map term with language value" => %{
        input: [%{"http://example/t" => %{"@value" => "foo", "@language" => "en"}}],
        context: %{"t" => %{"@id" => "http://example/t", "@container" => "@language"}},
        output: %{
          "@context" => %{
            "t" => %{"@id" => "http://example/t", "@container" => "@language"}
          },
          "t" => %{"en" => "foo"}
        }
      },
      "Datatyped term with datatyped value" => %{
        input: [%{"http://example/t" => %{"@value" => "foo", "@type" => "http:/example/type"}}],
        context: %{"t" => %{"@id" => "http://example/t", "@type" => "http:/example/type"}},
        output: %{
          "@context" => %{
            "t" => %{"@id" => "http://example/t", "@type" => "http:/example/type"}
          },
          "t" => "foo"
        }
      },
      "Datatyped term with simple value" => %{
        input: [%{"http://example/t" => %{"@value" => "foo"}}],
        context: %{"t" => %{"@id" => "http://example/t", "@type" => "http:/example/type"}},
        output: %{
          "@context" => %{
            "t" => %{"@id" => "http://example/t", "@type" => "http:/example/type"}
          },
          "http://example/t" => "foo"
        }
      },
      "Datatyped term with object value" => %{
        input: [%{"http://example/t" => %{"@id" => "http://example/id"}}],
        context: %{"t" => %{"@id" => "http://example/t", "@type" => "http:/example/type"}},
        output: %{
          "@context" => %{
            "t" => %{"@id" => "http://example/t", "@type" => "http:/example/type"}
          },
          "http://example/t" => %{"@id" => "http://example/id"}
        }
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        assert JSON.LD.compact(data.input, data.context) == data.output
      end
    end)
  end

  describe "@reverse" do
    %{
      "@container: @reverse" => %{
        input: [
          %{
            "@id" => "http://example/one",
            "@reverse" => %{
              "http://example/forward" => [
                %{
                  "@id" => "http://example/two"
                }
              ]
            }
          }
        ],
        context: %{
          "@vocab" => "http://example/",
          "rev" => %{"@reverse" => "forward", "@type" => "@id"}
        },
        output: %{
          "@context" => %{
            "@vocab" => "http://example/",
            "rev" => %{"@reverse" => "forward", "@type" => "@id"}
          },
          "@id" => "http://example/one",
          "rev" => "http://example/two"
        }
      },
      "compact-0033" => %{
        input:
          Jason.decode!("""
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
        context:
          Jason.decode!("""
            {
              "name": "http://xmlns.com/foaf/0.1/name",
              "isKnownBy": { "@reverse": "http://xmlns.com/foaf/0.1/knows" }
            }
          """),
        output:
          Jason.decode!("""
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
    |> Enum.each(fn {title, data} ->
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

  describe "@list" do
    %{
      "1 term 2 lists 2 languages" => %{
        input: [
          %{
            "http://example.com/foo" => [
              %{"@list" => [%{"@value" => "en", "@language" => "en"}]},
              %{"@list" => [%{"@value" => "de", "@language" => "de"}]}
            ]
          }
        ],
        context: %{
          "foo_en" => %{
            "@id" => "http://example.com/foo",
            "@container" => "@list",
            "@language" => "en"
          },
          "foo_de" => %{
            "@id" => "http://example.com/foo",
            "@container" => "@list",
            "@language" => "de"
          }
        },
        output: %{
          "@context" => %{
            "foo_en" => %{
              "@id" => "http://example.com/foo",
              "@container" => "@list",
              "@language" => "en"
            },
            "foo_de" => %{
              "@id" => "http://example.com/foo",
              "@container" => "@list",
              "@language" => "de"
            }
          },
          "foo_en" => ["en"],
          "foo_de" => ["de"]
        }
      },
      "1 term 2 lists 2 directions" => %{
        input: [
          %{
            "http://example.com/foo" => [
              %{"@list" => [%{"@value" => "en", "@direction" => "ltr"}]},
              %{"@list" => [%{"@value" => "ar", "@direction" => "rtl"}]}
            ]
          }
        ],
        context: %{
          "foo_ltr" => %{
            "@id" => "http://example.com/foo",
            "@container" => "@list",
            "@direction" => "ltr"
          },
          "foo_rtl" => %{
            "@id" => "http://example.com/foo",
            "@container" => "@list",
            "@direction" => "rtl"
          }
        },
        output: %{
          "@context" => %{
            "foo_ltr" => %{
              "@id" => "http://example.com/foo",
              "@container" => "@list",
              "@direction" => "ltr"
            },
            "foo_rtl" => %{
              "@id" => "http://example.com/foo",
              "@container" => "@list",
              "@direction" => "rtl"
            }
          },
          "foo_ltr" => ["en"],
          "foo_rtl" => ["ar"]
        }
      },
      "coerced @list containing an empty list" => %{
        input: [
          %{
            "http://example.com/foo" => [%{"@list" => [%{"@list" => []}]}]
          }
        ],
        context: %{
          "foo" => %{"@id" => "http://example.com/foo", "@container" => "@list"}
        },
        output: %{
          "@context" => %{"foo" => %{"@id" => "http://example.com/foo", "@container" => "@list"}},
          "foo" => [[]]
        }
      },
      "coerced @list containing a list" => %{
        input: [
          %{
            "http://example.com/foo" => [%{"@list" => [%{"@list" => [%{"@value" => "baz"}]}]}]
          }
        ],
        context: %{
          "foo" => %{"@id" => "http://example.com/foo", "@container" => "@list"}
        },
        output: %{
          "@context" => %{"foo" => %{"@id" => "http://example.com/foo", "@container" => "@list"}},
          "foo" => [["baz"]]
        }
      },
      "coerced @list containing a deep list" => %{
        input: [
          %{
            "http://example.com/foo" => [
              %{"@list" => [%{"@list" => [%{"@list" => [%{"@value" => "baz"}]}]}]}
            ]
          }
        ],
        context: %{
          "foo" => %{"@id" => "http://example.com/foo", "@container" => "@list"}
        },
        output: %{
          "@context" => %{"foo" => %{"@id" => "http://example.com/foo", "@container" => "@list"}},
          "foo" => [[["baz"]]]
        }
      },
      "coerced @list containing multiple lists" => %{
        input: [
          %{
            "http://example.com/foo" => [
              %{
                "@list" => [
                  %{"@list" => [%{"@value" => "a"}]},
                  %{"@list" => [%{"@value" => "b"}]}
                ]
              }
            ]
          }
        ],
        context: %{
          "foo" => %{"@id" => "http://example.com/foo", "@container" => "@list"}
        },
        output: %{
          "@context" => %{"foo" => %{"@id" => "http://example.com/foo", "@container" => "@list"}},
          "foo" => [["a"], ["b"]]
        }
      },
      "coerced @list containing mixed list values" => %{
        input: [
          %{
            "http://example.com/foo" => [
              %{
                "@list" => [
                  %{"@list" => [%{"@value" => "a"}]},
                  %{"@value" => "b"}
                ]
              }
            ]
          }
        ],
        context: %{
          "foo" => %{"@id" => "http://example.com/foo", "@container" => "@list"}
        },
        output: %{
          "@context" => %{"foo" => %{"@id" => "http://example.com/foo", "@container" => "@list"}},
          "foo" => [["a"], "b"]
        }
      },
      "list with index compaction" => %{
        input: %{
          "http://example.com/property" => %{
            "@list" => ["one item"],
            "@index" => "an annotation"
          }
        },
        context: %{
          "prop" => %{
            "@id" => "http://example.com/property",
            "@container" => "@list"
          }
        },
        output: %{
          "@context" => %{
            "prop" => %{
              "@id" => "http://example.com/property",
              "@container" => "@list"
            }
          },
          "http://example.com/property" => %{
            "@list" => ["one item"],
            "@index" => "an annotation"
          }
        }
      }
    }
    |> Enum.each(fn {title, data} ->
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
      "with no @language" => %{
        input: [
          %{
            "@id" => "http://example.com/queen",
            "http://example.com/vocab/label" => [
              %{"@value" => "The Queen", "@language" => "en"},
              %{"@value" => "Die Königin", "@language" => "de"},
              %{"@value" => "Ihre Majestät"}
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
            "de" => "Die Königin",
            "@none" => "Ihre Majestät"
          }
        }
      },
      "with no @language using alias of @none" => %{
        input: [
          %{
            "@id" => "http://example.com/queen",
            "http://example.com/vocab/label" => [
              %{"@value" => "The Queen", "@language" => "en"},
              %{"@value" => "Die Königin", "@language" => "de"},
              %{"@value" => "Ihre Majestät"}
            ]
          }
        ],
        context: %{
          "vocab" => "http://example.com/vocab/",
          "label" => %{"@id" => "vocab:label", "@container" => "@language"},
          "none" => "@none"
        },
        output: %{
          "@context" => %{
            "vocab" => "http://example.com/vocab/",
            "label" => %{"@id" => "vocab:label", "@container" => "@language"},
            "none" => "@none"
          },
          "@id" => "http://example.com/queen",
          "label" => %{
            "en" => "The Queen",
            "de" => "Die Königin",
            "none" => "Ihre Majestät"
          }
        }
      },
      "simple map with term direction" => %{
        input: [
          %{
            "@id" => "http://example.com/queen",
            "http://example.com/vocab/label" => [
              %{"@value" => "Die Königin", "@language" => "de", "@direction" => "ltr"},
              %{"@value" => "Ihre Majestät", "@language" => "de", "@direction" => "ltr"},
              %{"@value" => "The Queen", "@language" => "en", "@direction" => "ltr"}
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "vocab" => "http://example.com/vocab/",
          "label" => %{
            "@id" => "vocab:label",
            "@direction" => "ltr",
            "@container" => "@language"
          }
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "vocab" => "http://example.com/vocab/",
            "label" => %{
              "@id" => "vocab:label",
              "@direction" => "ltr",
              "@container" => "@language"
            }
          },
          "@id" => "http://example.com/queen",
          "label" => %{
            "en" => "The Queen",
            "de" => ["Die Königin", "Ihre Majestät"]
          }
        }
      },
      "simple map with overriding term direction" => %{
        input: [
          %{
            "@id" => "http://example.com/queen",
            "http://example.com/vocab/label" => [
              %{"@value" => "Die Königin", "@language" => "de", "@direction" => "ltr"},
              %{"@value" => "Ihre Majestät", "@language" => "de", "@direction" => "ltr"},
              %{"@value" => "The Queen", "@language" => "en", "@direction" => "ltr"}
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@direction" => "rtl",
          "vocab" => "http://example.com/vocab/",
          "label" => %{
            "@id" => "vocab:label",
            "@direction" => "ltr",
            "@container" => "@language"
          }
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@direction" => "rtl",
            "vocab" => "http://example.com/vocab/",
            "label" => %{
              "@id" => "vocab:label",
              "@direction" => "ltr",
              "@container" => "@language"
            }
          },
          "@id" => "http://example.com/queen",
          "label" => %{
            "en" => "The Queen",
            "de" => ["Die Königin", "Ihre Majestät"]
          }
        }
      },
      "simple map with overriding null direction" => %{
        input: [
          %{
            "@id" => "http://example.com/queen",
            "http://example.com/vocab/label" => [
              %{"@value" => "Die Königin", "@language" => "de"},
              %{"@value" => "Ihre Majestät", "@language" => "de"},
              %{"@value" => "The Queen", "@language" => "en"}
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@direction" => "rtl",
          "vocab" => "http://example.com/vocab/",
          "label" => %{
            "@id" => "vocab:label",
            "@direction" => nil,
            "@container" => "@language"
          }
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@direction" => "rtl",
            "vocab" => "http://example.com/vocab/",
            "label" => %{
              "@id" => "vocab:label",
              "@direction" => nil,
              "@container" => "@language"
            }
          },
          "@id" => "http://example.com/queen",
          "label" => %{
            "en" => "The Queen",
            "de" => ["Die Königin", "Ihre Majestät"]
          }
        }
      },
      "simple map with mismatching term direction" => %{
        input: [
          %{
            "@id" => "http://example.com/queen",
            "http://example.com/vocab/label" => [
              %{"@value" => "Die Königin", "@language" => "de"},
              %{"@value" => "Ihre Majestät", "@language" => "de", "@direction" => "ltr"},
              %{"@value" => "The Queen", "@language" => "en", "@direction" => "rtl"}
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "vocab" => "http://example.com/vocab/",
          "label" => %{
            "@id" => "vocab:label",
            "@direction" => "rtl",
            "@container" => "@language"
          }
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "vocab" => "http://example.com/vocab/",
            "label" => %{
              "@id" => "vocab:label",
              "@direction" => "rtl",
              "@container" => "@language"
            }
          },
          "@id" => "http://example.com/queen",
          "label" => %{
            "en" => "The Queen"
          },
          "vocab:label" => [
            %{"@value" => "Die Königin", "@language" => "de"},
            %{"@value" => "Ihre Majestät", "@language" => "de", "@direction" => "ltr"}
          ]
        }
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        assert JSON.LD.compact(data.input, data.context) == data.output
      end
    end)
  end

  describe "@graph" do
    %{
      "Uses @graph given multiple inputs" => %{
        input: [
          %{"http://example.com/foo" => ["foo"]},
          %{"http://example.com/bar" => ["bar"]}
        ],
        context: %{"ex" => "http://example.com/"},
        output: %{
          "@context" => %{"ex" => "http://example.com/"},
          "@graph" => [
            %{"ex:foo" => "foo"},
            %{"ex:bar" => "bar"}
          ]
        }
      },
      "Compacts simple graph" => %{
        input: [
          %{
            "http://example.org/input" => [
              %{
                "@graph" => [
                  %{
                    "http://example.org/value" => [%{"@value" => "x"}]
                  }
                ]
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example.org/",
          "input" => %{"@container" => "@graph"}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/",
            "input" => %{"@container" => "@graph"}
          },
          "input" => %{
            "value" => "x"
          }
        }
      },
      "Compacts simple graph with @set" => %{
        input: [
          %{
            "http://example.org/input" => [
              %{
                "@graph" => [
                  %{
                    "http://example.org/value" => [%{"@value" => "x"}]
                  }
                ]
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example.org/",
          "input" => %{"@container" => ["@graph", "@set"]}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/",
            "input" => %{"@container" => ["@graph", "@set"]}
          },
          "input" => [
            %{
              "value" => "x"
            }
          ]
        }
      },
      "Compacts simple graph with @index" => %{
        input: [
          %{
            "http://example.org/input" => [
              %{
                "@graph" => [
                  %{
                    "http://example.org/value" => [%{"@value" => "x"}]
                  }
                ],
                "@index" => "ndx"
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example.org/",
          "input" => %{"@container" => "@graph"}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/",
            "input" => %{"@container" => "@graph"}
          },
          "input" => %{
            "value" => "x"
          }
        }
      },
      "Compacts simple graph with @index and multiple nodes" => %{
        input: [
          %{
            "http://example.org/input" => [
              %{
                "@graph" => [
                  %{
                    "http://example.org/value" => [%{"@value" => "x"}]
                  },
                  %{
                    "http://example.org/value" => [%{"@value" => "y"}]
                  }
                ],
                "@index" => "ndx"
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example.org/",
          "input" => %{"@container" => "@graph"}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/",
            "input" => %{"@container" => "@graph"}
          },
          "input" => %{
            "@included" => [
              %{
                "value" => "x"
              },
              %{
                "value" => "y"
              }
            ]
          }
        }
      },
      "Does not compact graph with @id" => %{
        input: [
          %{
            "http://example.org/input" => [
              %{
                "@graph" => [
                  %{
                    "http://example.org/value" => [%{"@value" => "x"}]
                  }
                ],
                "@id" => "http://example.org/id"
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example.org/",
          "input" => %{"@container" => "@graph"}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/",
            "input" => %{"@container" => "@graph"}
          },
          "input" => %{
            "@id" => "http://example.org/id",
            "@graph" => %{"value" => "x"}
          }
        }
      },
      "Odd framing test" => %{
        input: [
          %{
            "http://example.org/claim" => [
              %{
                "@graph" => [
                  %{
                    "@id" => "http://example.org/1",
                    "https://example.com#test" => [
                      %{
                        "@value" => "foo"
                      }
                    ]
                  }
                ]
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "https://example.com#",
          "ex" => "http://example.org/",
          "claim" => %{
            "@id" => "ex:claim",
            "@container" => "@graph"
          },
          "id" => "@id"
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "https://example.com#",
            "ex" => "http://example.org/",
            "claim" => %{
              "@id" => "ex:claim",
              "@container" => "@graph"
            },
            "id" => "@id"
          },
          "claim" => %{
            "id" => "ex:1",
            "test" => "foo"
          }
        }
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        assert JSON.LD.compact(data.input, data.context) == data.output
      end
    end)
  end

  describe "@container: @index" do
    %{
      "compact-0029" => %{
        input: [
          %{
            "@id" => "http://example.com/article",
            "http://example.com/vocab/author" => [
              %{
                "@id" => "http://example.org/person/1",
                "@index" => "regular"
              },
              %{
                "@id" => "http://example.org/guest/cd24f329aa",
                "@index" => "guest"
              }
            ]
          }
        ],
        context: %{
          "author" => %{"@id" => "http://example.com/vocab/author", "@container" => "@index"}
        },
        output: %{
          "@context" => %{
            "author" => %{
              "@id" => "http://example.com/vocab/author",
              "@container" => "@index"
            }
          },
          "@id" => "http://example.com/article",
          "author" => %{
            "regular" => %{
              "@id" => "http://example.org/person/1"
            },
            "guest" => %{
              "@id" => "http://example.org/guest/cd24f329aa"
            }
          }
        }
      },
      "simple map with @none node definition" => %{
        input: [
          %{
            "@id" => "http://example.com/article",
            "http://example.com/vocab/author" => [
              %{
                "@id" => "http://example.org/person/1",
                "@index" => "regular"
              },
              %{
                "@id" => "http://example.org/guest/cd24f329aa"
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "author" => %{"@id" => "http://example.com/vocab/author", "@container" => "@index"}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "author" => %{
              "@id" => "http://example.com/vocab/author",
              "@container" => "@index"
            }
          },
          "@id" => "http://example.com/article",
          "author" => %{
            "regular" => %{
              "@id" => "http://example.org/person/1"
            },
            "@none" => %{
              "@id" => "http://example.org/guest/cd24f329aa"
            }
          }
        }
      },
      "simple map with @none value" => %{
        input: [
          %{
            "@id" => "http://example.com/article",
            "http://example.com/vocab/author" => [
              %{
                "@value" => "Gregg",
                "@index" => "regular"
              },
              %{
                "@value" => "Manu"
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "author" => %{"@id" => "http://example.com/vocab/author", "@container" => "@index"}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "author" => %{
              "@id" => "http://example.com/vocab/author",
              "@container" => "@index"
            }
          },
          "@id" => "http://example.com/article",
          "author" => %{
            "regular" => "Gregg",
            "@none" => "Manu"
          }
        }
      },
      "simple map with @none value using alias of @none" => %{
        input: [
          %{
            "@id" => "http://example.com/article",
            "http://example.com/vocab/author" => [
              %{
                "@value" => "Gregg",
                "@index" => "regular"
              },
              %{
                "@value" => "Manu"
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "author" => %{"@id" => "http://example.com/vocab/author", "@container" => "@index"},
          "none" => "@none"
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "author" => %{
              "@id" => "http://example.com/vocab/author",
              "@container" => "@index"
            },
            "none" => "@none"
          },
          "@id" => "http://example.com/article",
          "author" => %{
            "regular" => "Gregg",
            "none" => "Manu"
          }
        }
      },
      "property-valued index indexes property value, instead of property (value)" => %{
        input: [
          %{
            "@id" => "http://example.com/article",
            "http://example.com/author" => [
              %{
                "@id" => "http://example.com/person/1",
                "http://example.com/prop" => [%{"@value" => "regular"}]
              },
              %{
                "@id" => "http://example.com/person/2",
                "http://example.com/prop" => [%{"@value" => "guest"}]
              },
              %{
                "@id" => "http://example.com/person/3",
                "http://example.com/prop" => [%{"@value" => "guest"}]
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@base" => "http://example.com/",
          "@vocab" => "http://example.com/",
          "author" => %{"@type" => "@id", "@container" => "@index", "@index" => "prop"}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@base" => "http://example.com/",
            "@vocab" => "http://example.com/",
            "author" => %{"@type" => "@id", "@container" => "@index", "@index" => "prop"}
          },
          "@id" => "article",
          "author" => %{
            "regular" => %{"@id" => "person/1"},
            "guest" => [%{"@id" => "person/2"}, %{"@id" => "person/3"}]
          }
        }
      },
      "property-valued index indexes property value, instead of @index (multiple values)" => %{
        input: [
          %{
            "@id" => "http://example.com/article",
            "http://example.com/author" => [
              %{
                "@id" => "http://example.com/person/1",
                "http://example.com/prop" => [%{"@value" => "regular"}, %{"@value" => "foo"}]
              },
              %{
                "@id" => "http://example.com/person/2",
                "http://example.com/prop" => [%{"@value" => "guest"}, %{"@value" => "foo"}]
              },
              %{
                "@id" => "http://example.com/person/3",
                "http://example.com/prop" => [%{"@value" => "guest"}, %{"@value" => "foo"}]
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@base" => "http://example.com/",
          "@vocab" => "http://example.com/",
          "author" => %{"@type" => "@id", "@container" => "@index", "@index" => "prop"}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@base" => "http://example.com/",
            "@vocab" => "http://example.com/",
            "author" => %{"@type" => "@id", "@container" => "@index", "@index" => "prop"}
          },
          "@id" => "article",
          "author" => %{
            "regular" => %{"@id" => "person/1", "prop" => "foo"},
            "guest" => [
              %{"@id" => "person/2", "prop" => "foo"},
              %{"@id" => "person/3", "prop" => "foo"}
            ]
          }
        }
      },
      "property-valued index indexes using @none if no property value exists" => %{
        input: [
          %{
            "@id" => "http://example.com/article",
            "http://example.com/author" => [
              %{"@id" => "http://example.com/person/1"},
              %{"@id" => "http://example.com/person/2"},
              %{"@id" => "http://example.com/person/3"}
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@base" => "http://example.com/",
          "@vocab" => "http://example.com/",
          "author" => %{"@type" => "@id", "@container" => "@index", "@index" => "prop"}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@base" => "http://example.com/",
            "@vocab" => "http://example.com/",
            "author" => %{"@type" => "@id", "@container" => "@index", "@index" => "prop"}
          },
          "@id" => "article",
          "author" => %{
            "@none" => ["person/1", "person/2", "person/3"]
          }
        }
      },
      "issue-514" => %{
        input: %{
          "http://example.org/ns/prop" => [
            %{
              "@id" => "http://example.org/ns/bar",
              "http://example.org/ns/name" => "bar"
            },
            %{
              "@id" => "http://example.org/ns/foo",
              "http://example.org/ns/name" => "foo"
            }
          ]
        },
        context: %{
          "@context" => %{
            "@version" => 1.1,
            "ex" => "http://example.org/ns/",
            "prop" => %{
              "@id" => "ex:prop",
              "@container" => "@index",
              "@index" => "ex:name"
            }
          }
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "ex" => "http://example.org/ns/",
            "prop" => %{
              "@id" => "ex:prop",
              "@container" => "@index",
              "@index" => "ex:name"
            }
          },
          "prop" => %{
            "foo" => %{"@id" => "ex:foo"},
            "bar" => %{"@id" => "ex:bar"}
          }
        }
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        assert JSON.LD.compact(data.input, data.context) == data.output
      end
    end)
  end

  describe "@container: @id" do
    %{
      "Indexes to object not having an @id" => %{
        input: [
          %{
            "http://example/idmap" => [
              %{
                "http://example/label" => [%{"@value" => "Object with @id _:bar"}],
                "@id" => "_:bar"
              },
              %{
                "http://example/label" => [%{"@value" => "Object with @id <foo>"}],
                "@id" => "http://example.org/foo"
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example/",
          "idmap" => %{"@container" => "@id"}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example/",
            "idmap" => %{"@container" => "@id"}
          },
          "idmap" => %{
            "http://example.org/foo" => %{"label" => "Object with @id <foo>"},
            "_:bar" => %{"label" => "Object with @id _:bar"}
          }
        }
      },
      "Indexes to object already having an @id" => %{
        input: [
          %{
            "http://example/idmap" => [
              %{
                "@id" => "_:foo",
                "http://example/label" => [%{"@value" => "Object with @id _:bar"}]
              },
              %{
                "@id" => "http://example.org/bar",
                "http://example/label" => [%{"@value" => "Object with @id <foo>"}]
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example/",
          "idmap" => %{"@container" => "@id"}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example/",
            "idmap" => %{"@container" => "@id"}
          },
          "idmap" => %{
            "_:foo" => %{"label" => "Object with @id _:bar"},
            "http://example.org/bar" => %{"label" => "Object with @id <foo>"}
          }
        }
      },
      "Indexes to object using compact IRI @id" => %{
        input: [
          %{
            "http://example/idmap" => [
              %{
                "http://example/label" => [%{"@value" => "Object with @id <foo>"}],
                "@id" => "http://example.org/foo"
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example/",
          "ex" => "http://example.org/",
          "idmap" => %{"@container" => "@id"}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example/",
            "ex" => "http://example.org/",
            "idmap" => %{"@container" => "@id"}
          },
          "idmap" => %{
            "ex:foo" => %{"label" => "Object with @id <foo>"}
          }
        }
      },
      "Indexes using @none" => %{
        input: [
          %{
            "http://example/idmap" => [
              %{"http://example/label" => [%{"@value" => "Object with no @id"}]}
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example/",
          "ex" => "http://example.org/",
          "idmap" => %{"@container" => "@id"}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example/",
            "ex" => "http://example.org/",
            "idmap" => %{"@container" => "@id"}
          },
          "idmap" => %{
            "@none" => %{"label" => "Object with no @id"}
          }
        }
      },
      "Indexes using @none with alias" => %{
        input: [
          %{
            "http://example/idmap" => [
              %{"http://example/label" => [%{"@value" => "Object with no @id"}]}
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example/",
          "ex" => "http://example.org/",
          "idmap" => %{"@container" => "@id"},
          "none" => "@none"
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example/",
            "ex" => "http://example.org/",
            "idmap" => %{"@container" => "@id"},
            "none" => "@none"
          },
          "idmap" => %{
            "none" => %{"label" => "Object with no @id"}
          }
        }
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        assert JSON.LD.compact(data.input, data.context) == data.output
      end
    end)
  end

  describe "@container: @type" do
    %{
      "Indexes to object not having an @type" => %{
        input: [
          %{
            "http://example/typemap" => [
              %{
                "http://example/label" => [%{"@value" => "Object with @type _:bar"}],
                "@type" => ["_:bar"]
              },
              %{
                "http://example/label" => [%{"@value" => "Object with @type <foo>"}],
                "@type" => ["http://example.org/foo"]
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example/",
          "typemap" => %{"@container" => "@type"}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example/",
            "typemap" => %{"@container" => "@type"}
          },
          "typemap" => %{
            "http://example.org/foo" => %{"label" => "Object with @type <foo>"},
            "_:bar" => %{"label" => "Object with @type _:bar"}
          }
        }
      },
      "Indexes to object already having an @type" => %{
        input: [
          %{
            "http://example/typemap" => [
              %{
                "@type" => ["_:bar", "_:foo"],
                "http://example/label" => [%{"@value" => "Object with @type _:bar"}]
              },
              %{
                "@type" => ["http://example.org/foo", "http://example.org/bar"],
                "http://example/label" => [%{"@value" => "Object with @type <foo>"}]
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example/",
          "typemap" => %{"@container" => "@type"}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example/",
            "typemap" => %{"@container" => "@type"}
          },
          "typemap" => %{
            "http://example.org/foo" => %{
              "@type" => "http://example.org/bar",
              "label" => "Object with @type <foo>"
            },
            "_:bar" => %{"@type" => "_:foo", "label" => "Object with @type _:bar"}
          }
        }
      },
      "Indexes to object already having multiple @type values" => %{
        input: [
          %{
            "http://example/typemap" => [
              %{
                "@type" => ["_:bar", "_:foo", "_:baz"],
                "http://example/label" => [%{"@value" => "Object with @type _:bar"}]
              },
              %{
                "@type" => [
                  "http://example.org/foo",
                  "http://example.org/bar",
                  "http://example.org/baz"
                ],
                "http://example/label" => [%{"@value" => "Object with @type <foo>"}]
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example/",
          "typemap" => %{"@container" => "@type"}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example/",
            "typemap" => %{"@container" => "@type"}
          },
          "typemap" => %{
            "http://example.org/foo" => %{
              "@type" => ["http://example.org/bar", "http://example.org/baz"],
              "label" => "Object with @type <foo>"
            },
            "_:bar" => %{"@type" => ["_:foo", "_:baz"], "label" => "Object with @type _:bar"}
          }
        }
      },
      "Indexes using compacted @type" => %{
        input: [
          %{
            "http://example/typemap" => [
              %{
                "http://example/label" => [%{"@value" => "Object with @type <foo>"}],
                "@type" => ["http://example/Foo"]
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example/",
          "typemap" => %{"@container" => "@type"}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example/",
            "typemap" => %{"@container" => "@type"}
          },
          "typemap" => %{
            "Foo" => %{"label" => "Object with @type <foo>"}
          }
        }
      },
      "Indexes using @none" => %{
        input: [
          %{
            "http://example/typemap" => [
              %{"http://example/label" => [%{"@value" => "Object with no @type"}]}
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example/",
          "ex" => "http://example.org/",
          "typemap" => %{"@container" => "@type"}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example/",
            "ex" => "http://example.org/",
            "typemap" => %{"@container" => "@type"}
          },
          "typemap" => %{
            "@none" => %{"label" => "Object with no @type"}
          }
        }
      },
      "Indexes using @none with alias" => %{
        input: [
          %{
            "http://example/typemap" => [
              %{"http://example/label" => [%{"@value" => "Object with no @id"}]}
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example/",
          "ex" => "http://example.org/",
          "typemap" => %{"@container" => "@type"},
          "none" => "@none"
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example/",
            "ex" => "http://example.org/",
            "typemap" => %{"@container" => "@type"},
            "none" => "@none"
          },
          "typemap" => %{
            "none" => %{"label" => "Object with no @id"}
          }
        }
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        assert JSON.LD.compact(data.input, data.context) == data.output
      end
    end)
  end

  describe "@nest" do
    %{
      "Indexes to @nest for property with @nest" => %{
        input: [
          %{
            "http://example.org/p1" => [%{"@value" => "v1"}],
            "http://example.org/p2" => [%{"@value" => "v2"}]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example.org/",
          "p2" => %{"@nest" => "@nest"}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/",
            "p2" => %{"@nest" => "@nest"}
          },
          "p1" => "v1",
          "@nest" => %{
            "p2" => "v2"
          }
        }
      },
      "Indexes to @nest for all properties with @nest" => %{
        input: [
          %{
            "http://example.org/p1" => [%{"@value" => "v1"}],
            "http://example.org/p2" => [%{"@value" => "v2"}]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example.org/",
          "p1" => %{"@nest" => "@nest"},
          "p2" => %{"@nest" => "@nest"}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/",
            "p1" => %{"@nest" => "@nest"},
            "p2" => %{"@nest" => "@nest"}
          },
          "@nest" => %{
            "p1" => "v1",
            "p2" => "v2"
          }
        }
      },
      "Nests using alias of @nest" => %{
        input: [
          %{
            "http://example.org/p1" => [%{"@value" => "v1"}],
            "http://example.org/p2" => [%{"@value" => "v2"}]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example.org/",
          "nest" => "@nest",
          "p2" => %{"@nest" => "nest"}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/",
            "nest" => "@nest",
            "p2" => %{"@nest" => "nest"}
          },
          "p1" => "v1",
          "nest" => %{
            "p2" => "v2"
          }
        }
      },
      "Arrays of nested values" => %{
        input: [
          %{
            "http://example.org/p1" => [%{"@value" => "v1"}],
            "http://example.org/p2" => [%{"@value" => "v2"}, %{"@value" => "v3"}]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example.org/",
          "p2" => %{"@nest" => "@nest"}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/",
            "p2" => %{"@nest" => "@nest"}
          },
          "p1" => "v1",
          "@nest" => %{
            "p2" => ["v2", "v3"]
          }
        }
      },
      "Nested @container: @list" => %{
        input: [
          %{
            "http://example.org/list" => [
              %{
                "@list" => [
                  %{"@value" => "a"},
                  %{"@value" => "b"}
                ]
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example.org/",
          "list" => %{"@container" => "@list", "@nest" => "nestedlist"},
          "nestedlist" => "@nest"
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/",
            "list" => %{"@container" => "@list", "@nest" => "nestedlist"},
            "nestedlist" => "@nest"
          },
          "nestedlist" => %{
            "list" => ["a", "b"]
          }
        }
      },
      "Nested @container: @index" => %{
        input: [
          %{
            "http://example.org/index" => [
              %{"@value" => "a", "@index" => "A"},
              %{"@value" => "b", "@index" => "B"}
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example.org/",
          "index" => %{"@container" => "@index", "@nest" => "nestedindex"},
          "nestedindex" => "@nest"
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/",
            "index" => %{"@container" => "@index", "@nest" => "nestedindex"},
            "nestedindex" => "@nest"
          },
          "nestedindex" => %{
            "index" => %{
              "A" => "a",
              "B" => "b"
            }
          }
        }
      },
      "Nested @container: @language" => %{
        input: [
          %{
            "http://example.org/container" => [
              %{"@value" => "Die Königin", "@language" => "de"},
              %{"@value" => "The Queen", "@language" => "en"}
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example.org/",
          "container" => %{"@container" => "@language", "@nest" => "nestedlanguage"},
          "nestedlanguage" => "@nest"
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/",
            "container" => %{"@container" => "@language", "@nest" => "nestedlanguage"},
            "nestedlanguage" => "@nest"
          },
          "nestedlanguage" => %{
            "container" => %{
              "en" => "The Queen",
              "de" => "Die Königin"
            }
          }
        }
      },
      "Nested @container: @type" => %{
        input: [
          %{
            "http://example/typemap" => [
              %{
                "http://example/label" => [%{"@value" => "Object with @type _:bar"}],
                "@type" => ["_:bar"]
              },
              %{
                "http://example/label" => [%{"@value" => "Object with @type <foo>"}],
                "@type" => ["http://example.org/foo"]
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example/",
          "typemap" => %{"@container" => "@type", "@nest" => "nestedtypemap"},
          "nestedtypemap" => "@nest"
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example/",
            "typemap" => %{"@container" => "@type", "@nest" => "nestedtypemap"},
            "nestedtypemap" => "@nest"
          },
          "nestedtypemap" => %{
            "typemap" => %{
              "_:bar" => %{"label" => "Object with @type _:bar"},
              "http://example.org/foo" => %{"label" => "Object with @type <foo>"}
            }
          }
        }
      },
      "Nested @container: @id" => %{
        input: [
          %{
            "http://example/idmap" => [
              %{
                "http://example/label" => [%{"@value" => "Object with @id _:bar"}],
                "@id" => "_:bar"
              },
              %{
                "http://example/label" => [%{"@value" => "Object with @id <foo>"}],
                "@id" => "http://example.org/foo"
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example/",
          "idmap" => %{"@container" => "@id", "@nest" => "nestedidmap"},
          "nestedidmap" => "@nest"
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example/",
            "idmap" => %{"@container" => "@id", "@nest" => "nestedidmap"},
            "nestedidmap" => "@nest"
          },
          "nestedidmap" => %{
            "idmap" => %{
              "http://example.org/foo" => %{"label" => "Object with @id <foo>"},
              "_:bar" => %{"label" => "Object with @id _:bar"}
            }
          }
        }
      },
      "Multiple nest aliases" => %{
        input: %{
          "http://example.org/foo" => "bar",
          "http://example.org/bar" => "foo"
        },
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example.org/",
          "foonest" => "@nest",
          "barnest" => "@nest",
          "foo" => %{"@nest" => "foonest"},
          "bar" => %{"@nest" => "barnest"}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/",
            "foonest" => "@nest",
            "barnest" => "@nest",
            "foo" => %{"@nest" => "foonest"},
            "bar" => %{"@nest" => "barnest"}
          },
          "barnest" => %{"bar" => "foo"},
          "foonest" => %{"foo" => "bar"}
        }
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        assert JSON.LD.compact(data.input, data.context) == data.output
      end
    end)
  end

  describe "@included" do
    %{
      "Basic Included array" => %{
        input: [
          %{
            "http://example.org/prop" => [%{"@value" => "value"}],
            "@included" => [
              %{
                "http://example.org/prop" => [%{"@value" => "value2"}]
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example.org/",
          "included" => %{"@id" => "@included", "@container" => "@set"}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/",
            "included" => %{"@id" => "@included", "@container" => "@set"}
          },
          "prop" => "value",
          "included" => [
            %{
              "prop" => "value2"
            }
          ]
        }
      },
      "Basic Included object" => %{
        input: [
          %{
            "http://example.org/prop" => [%{"@value" => "value"}],
            "@included" => [
              %{
                "http://example.org/prop" => [%{"@value" => "value2"}]
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example.org/"
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/"
          },
          "prop" => "value",
          "@included" => %{
            "prop" => "value2"
          }
        }
      },
      "Multiple properties mapping to @included are folded together" => %{
        input: [
          %{
            "@included" => [
              %{"http://example.org/prop" => [%{"@value" => "value1"}]},
              %{"http://example.org/prop" => [%{"@value" => "value2"}]}
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example.org/",
          "included1" => "@included",
          "included2" => "@included"
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/",
            "included1" => "@included",
            "included2" => "@included"
          },
          "included1" => [
            %{"prop" => "value1"},
            %{"prop" => "value2"}
          ]
        }
      },
      "Included containing @included" => %{
        input: [
          %{
            "http://example.org/prop" => [%{"@value" => "value"}],
            "@included" => [
              %{
                "http://example.org/prop" => [%{"@value" => "value2"}],
                "@included" => [
                  %{
                    "http://example.org/prop" => [%{"@value" => "value3"}]
                  }
                ]
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example.org/"
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/"
          },
          "prop" => "value",
          "@included" => %{
            "prop" => "value2",
            "@included" => %{
              "prop" => "value3"
            }
          }
        }
      },
      "Property value with @included" => %{
        input: [
          %{
            "http://example.org/prop" => [
              %{
                "@type" => ["http://example.org/Foo"],
                "@included" => [
                  %{
                    "@type" => ["http://example.org/Bar"]
                  }
                ]
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example.org/"
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/"
          },
          "prop" => %{
            "@type" => "Foo",
            "@included" => %{
              "@type" => "Bar"
            }
          }
        }
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        assert JSON.LD.compact(data.input, data.context) == data.output
      end
    end)
  end

  describe "scoped context" do
    %{
      "adding new term" => %{
        input: [
          %{
            "http://example/foo" => [%{"http://example.org/bar" => [%{"@value" => "baz"}]}]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example/",
          "foo" => %{"@context" => %{"bar" => "http://example.org/bar"}}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example/",
            "foo" => %{"@context" => %{"bar" => "http://example.org/bar"}}
          },
          "foo" => %{
            "bar" => "baz"
          }
        }
      },
      "overriding a term" => %{
        input: [
          %{
            "http://example/foo" => [
              %{"http://example/bar" => [%{"@id" => "http://example/baz"}]}
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example/",
          "foo" => %{"@context" => %{"bar" => %{"@type" => "@id"}}},
          "bar" => %{"@type" => "http://www.w3.org/2001/XMLSchema#string"}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example/",
            "foo" => %{"@context" => %{"bar" => %{"@type" => "@id"}}},
            "bar" => %{"@type" => "http://www.w3.org/2001/XMLSchema#string"}
          },
          "foo" => %{
            "bar" => "http://example/baz"
          }
        }
      },
      "property and value with different terms mapping to the same expanded property" => %{
        input: [
          %{
            "http://example/foo" => [
              %{
                "http://example/bar" => [
                  %{"@value" => "baz"}
                ]
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example/",
          "foo" => %{"@context" => %{"Bar" => %{"@id" => "bar"}}}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example/",
            "foo" => %{"@context" => %{"Bar" => %{"@id" => "bar"}}}
          },
          "foo" => %{
            "Bar" => "baz"
          }
        }
      },
      "deep @context affects nested nodes" => %{
        input: [
          %{
            "http://example/foo" => [
              %{
                "http://example/bar" => [
                  %{
                    "http://example/baz" => [%{"@id" => "http://example/buzz"}]
                  }
                ]
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example/",
          "foo" => %{"@context" => %{"baz" => %{"@type" => "@vocab"}}}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example/",
            "foo" => %{"@context" => %{"baz" => %{"@type" => "@vocab"}}}
          },
          "foo" => %{
            "bar" => %{
              "baz" => "buzz"
            }
          }
        }
      },
      "scoped context layers on intemediate contexts" => %{
        input: [
          %{
            "http://example/a" => [
              %{
                "http://example.com/c" => [%{"@value" => "C in example.com"}],
                "http://example/b" => [
                  %{
                    "http://example.com/a" => [%{"@value" => "A in example.com"}],
                    "http://example.org/c" => [%{"@value" => "C in example.org"}]
                  }
                ]
              }
            ],
            "http://example/c" => [%{"@value" => "C in example"}]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example/",
          "b" => %{"@context" => %{"c" => "http://example.org/c"}}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example/",
            "b" => %{"@context" => %{"c" => "http://example.org/c"}}
          },
          "a" => %{
            "b" => %{
              "c" => "C in example.org",
              "http://example.com/a" => "A in example.com"
            },
            "http://example.com/c" => "C in example.com"
          },
          "c" => "C in example"
        }
      },
      "Scoped on id map" => %{
        input: [
          %{
            "@id" => "http://example.com/",
            "@type" => ["http://schema.org/Blog"],
            "http://schema.org/name" => [%{"@value" => "World Financial News"}],
            "http://schema.org/blogPost" => [
              %{
                "@id" => "http://example.com/posts/1/en",
                "http://schema.org/articleBody" => [
                  %{
                    "@value" =>
                      "World commodities were up today with heavy trading of crude oil..."
                  }
                ],
                "http://schema.org/wordCount" => [%{"@value" => 1539}]
              },
              %{
                "@id" => "http://example.com/posts/1/de",
                "http://schema.org/articleBody" => [
                  %{
                    "@value" =>
                      "Die Werte an Warenbörsen stiegen im Sog eines starken Handels von Rohöl..."
                  }
                ],
                "http://schema.org/wordCount" => [%{"@value" => 1204}]
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "schema" => "http://schema.org/",
          "name" => "schema:name",
          "body" => "schema:articleBody",
          "words" => "schema:wordCount",
          "post" => %{
            "@id" => "schema:blogPost",
            "@container" => "@id",
            "@context" => %{
              "@base" => "http://example.com/posts/"
            }
          }
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "schema" => "http://schema.org/",
            "name" => "schema:name",
            "body" => "schema:articleBody",
            "words" => "schema:wordCount",
            "post" => %{
              "@id" => "schema:blogPost",
              "@container" => "@id",
              "@context" => %{
                "@base" => "http://example.com/posts/"
              }
            }
          },
          "@id" => "http://example.com/",
          "@type" => "schema:Blog",
          "name" => "World Financial News",
          "post" => %{
            "1/en" => %{
              "body" => "World commodities were up today with heavy trading of crude oil...",
              "words" => 1539
            },
            "1/de" => %{
              "body" =>
                "Die Werte an Warenbörsen stiegen im Sog eines starken Handels von Rohöl...",
              "words" => 1204
            }
          }
        }
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        assert JSON.LD.compact(data.input, data.context) == data.output
      end
    end)
  end

  describe "scoped context on @type" do
    %{
      "adding new term" => %{
        input: [
          %{
            "http://example/a" => [
              %{
                "@type" => ["http://example/Foo"],
                "http://example.org/bar" => [%{"@value" => "baz"}]
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example/",
          "Foo" => %{"@context" => %{"bar" => "http://example.org/bar"}}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example/",
            "Foo" => %{"@context" => %{"bar" => "http://example.org/bar"}}
          },
          "a" => %{"@type" => "Foo", "bar" => "baz"}
        }
      },
      "overriding a term" => %{
        input: [
          %{
            "http://example/a" => [
              %{
                "@type" => ["http://example/Foo"],
                "http://example/bar" => [%{"@id" => "http://example/baz"}]
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example/",
          "Foo" => %{"@context" => %{"bar" => %{"@type" => "@id"}}},
          "bar" => %{"@type" => "http://www.w3.org/2001/XMLSchema#string"}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example/",
            "Foo" => %{"@context" => %{"bar" => %{"@type" => "@id"}}},
            "bar" => %{"@type" => "http://www.w3.org/2001/XMLSchema#string"}
          },
          "a" => %{"@type" => "Foo", "bar" => "http://example/baz"}
        }
      },
      "alias of @type" => %{
        input: [
          %{
            "http://example/a" => [
              %{
                "@type" => ["http://example/Foo"],
                "http://example.org/bar" => [%{"@value" => "baz"}]
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example/",
          "type" => "@type",
          "Foo" => %{"@context" => %{"bar" => "http://example.org/bar"}}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example/",
            "type" => "@type",
            "Foo" => %{"@context" => %{"bar" => "http://example.org/bar"}}
          },
          "a" => %{"type" => "Foo", "bar" => "baz"}
        }
      },
      "deep @context does not affect nested nodes" => %{
        input: [
          %{
            "@type" => ["http://example/Foo"],
            "http://example/bar" => [
              %{
                "http://example/baz" => [%{"@id" => "http://example/buzz"}]
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example/",
          "Foo" => %{"@context" => %{"baz" => %{"@type" => "@vocab"}}}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example/",
            "Foo" => %{"@context" => %{"baz" => %{"@type" => "@vocab"}}}
          },
          "@type" => "Foo",
          "bar" => %{"baz" => %{"@id" => "http://example/buzz"}}
        }
      },
      "scoped context layers on intemediate contexts" => %{
        input: [
          %{
            "http://example/a" => [
              %{
                "@type" => ["http://example/B"],
                "http://example.com/a" => [%{"@value" => "A in example.com"}],
                "http://example.org/c" => [%{"@value" => "C in example.org"}]
              }
            ],
            "http://example/c" => [%{"@value" => "C in example"}]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example/",
          "B" => %{"@context" => %{"c" => "http://example.org/c"}}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example/",
            "B" => %{"@context" => %{"c" => "http://example.org/c"}}
          },
          "a" => %{
            "@type" => "B",
            "c" => "C in example.org",
            "http://example.com/a" => "A in example.com"
          },
          "c" => "C in example"
        }
      },
      "orders lexicographically" => %{
        input: [
          %{
            "@type" => ["http://example/t2", "http://example/t1"],
            "http://example.org/foo" => [
              %{"@id" => "urn:bar"}
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example/",
          "t1" => %{"@context" => %{"foo" => %{"@id" => "http://example.com/foo"}}},
          "t2" => %{
            "@context" => %{"foo" => %{"@id" => "http://example.org/foo", "@type" => "@id"}}
          }
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example/",
            "t1" => %{"@context" => %{"foo" => %{"@id" => "http://example.com/foo"}}},
            "t2" => %{
              "@context" => %{"foo" => %{"@id" => "http://example.org/foo", "@type" => "@id"}}
            }
          },
          "@type" => ["t2", "t1"],
          "foo" => "urn:bar"
        }
      },
      "with @container: @type" => %{
        input: [
          %{
            "http://example/typemap" => [
              %{
                "http://example.org/a" => [%{"@value" => "Object with @type <Type>"}],
                "@type" => ["http://example/Type"]
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example/",
          "typemap" => %{"@container" => "@type"},
          "Type" => %{"@context" => %{"a" => "http://example.org/a"}}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example/",
            "typemap" => %{"@container" => "@type"},
            "Type" => %{"@context" => %{"a" => "http://example.org/a"}}
          },
          "typemap" => %{
            "Type" => %{"a" => "Object with @type <Type>"}
          }
        }
      },
      "applies context for all values" => %{
        input: [
          %{
            "@id" => "http://example.org/id",
            "@type" => ["http://example/type"],
            "http://example/a" => [
              %{
                "@id" => "http://example.org/Foo",
                "@type" => ["http://example/Foo"],
                "http://example/bar" => [%{"@id" => "http://example.org/baz"}]
              }
            ]
          }
        ],
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example/",
          "id" => "@id",
          "type" => "@type",
          "Foo" => %{"@context" => %{"id" => nil, "type" => nil}}
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example/",
            "id" => "@id",
            "type" => "@type",
            "Foo" => %{"@context" => %{"id" => nil, "type" => nil}}
          },
          "id" => "http://example.org/id",
          "type" => "http://example/type",
          "a" => %{
            "@id" => "http://example.org/Foo",
            "@type" => "Foo",
            "bar" => %{"@id" => "http://example.org/baz"}
          }
        }
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        assert JSON.LD.compact(data.input, data.context) == data.output
      end
    end)
  end

  describe "remote document handling" do
    test "compacts a document from a URL" do
      bypass = Bypass.open()

      Bypass.expect(bypass, fn conn ->
        assert "GET" == conn.method
        assert "/document.jsonld" == conn.request_path

        json_content =
          Jason.encode!(%{
            "@id" => "http://example.org/test",
            "http://xmlns.com/foaf/0.1/name" => [%{"@value" => "Test Name"}],
            "http://xmlns.com/foaf/0.1/homepage" => [%{"@id" => "http://example.org/"}]
          })

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, json_content)
      end)

      context = %{
        "@context" => %{
          "foaf" => "http://xmlns.com/foaf/0.1/",
          "name" => "foaf:name",
          "homepage" => %{"@id" => "foaf:homepage", "@type" => "@id"}
        }
      }

      assert JSON.LD.compact("http://localhost:#{bypass.port}/document.jsonld", context) == %{
               "@context" => context["@context"],
               "@id" => "http://example.org/test",
               "name" => "Test Name",
               "homepage" => "http://example.org/"
             }
    end

    test "compacts a document from a URL with relative IRIs" do
      bypass = Bypass.open()

      Bypass.expect(bypass, fn conn ->
        assert "GET" == conn.method
        assert "/document.jsonld" == conn.request_path

        json_content =
          Jason.encode!(%{
            "@id" => "test",
            "http://xmlns.com/foaf/0.1/homepage" => [%{"@id" => "foo"}]
          })

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, json_content)
      end)

      context = %{
        "@context" => %{
          "foaf" => "http://xmlns.com/foaf/0.1/",
          "homepage" => %{"@id" => "foaf:homepage", "@type" => "@id"}
        }
      }

      base_url = "http://localhost:#{bypass.port}"
      document_url = "#{base_url}/document.jsonld"

      assert JSON.LD.compact(document_url, context) == %{
               "@context" => context["@context"],
               "@id" => "test",
               "homepage" => "foo"
             }

      assert JSON.LD.compact(document_url, context, compact_to_relative: false) == %{
               "@context" => context["@context"],
               "@id" => "#{base_url}/test",
               "homepage" => "#{base_url}/foo"
             }
    end

    test "fails on non-existent remote document" do
      bypass = Bypass.open()

      Bypass.expect(bypass, fn conn ->
        Plug.Conn.resp(conn, 404, "Not Found")
      end)

      assert_raise_json_ld_error "loading document failed", fn ->
        JSON.LD.compact("http://localhost:#{bypass.port}/non-existent.jsonld", %{})
      end
    end

    test "compacts a document with remote context" do
      bypass = Bypass.open()

      Bypass.expect(bypass, fn
        %{request_path: "/context.jsonld"} = conn ->
          json_content =
            Jason.encode!(%{
              "@context" => %{
                "name" => "http://xmlns.com/foaf/0.1/name",
                "homepage" => %{
                  "@id" => "http://xmlns.com/foaf/0.1/homepage",
                  "@type" => "@id"
                }
              }
            })

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, json_content)

        %{request_path: "/document.jsonld"} = conn ->
          json_content =
            Jason.encode!(%{
              "@id" => "http://example.org/test",
              "http://xmlns.com/foaf/0.1/name" => [%{"@value" => "Test Name"}],
              "http://xmlns.com/foaf/0.1/homepage" => [%{"@id" => "http://example.org/"}]
            })

          conn
          |> Plug.Conn.put_resp_header("content-type", "application/json")
          |> Plug.Conn.resp(200, json_content)
      end)

      context_url = "http://localhost:#{bypass.port}/context.jsonld"
      document_url = "http://localhost:#{bypass.port}/document.jsonld"

      assert JSON.LD.compact(document_url, context_url) == %{
               "@context" => context_url,
               "@id" => "http://example.org/test",
               "name" => "Test Name",
               "homepage" => "http://example.org/"
             }
    end
  end

  describe "problem cases" do
    %{
      "issue json-ld-framing#64" => %{
        input: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/vocab#"
          },
          "@id" => "http://example.org/1",
          "@type" => "HumanMadeObject",
          "produced_by" => %{
            "@type" => "Production",
            "_label" => "Top Production",
            "part" => %{
              "@type" => "Production",
              "_label" => "Test Part"
            }
          }
        },
        context: %{
          "@version" => 1.1,
          "@vocab" => "http://example.org/vocab#",
          "Production" => %{
            "@context" => %{
              "part" => %{
                "@type" => "@id",
                "@container" => "@set"
              }
            }
          }
        },
        output: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/vocab#",
            "Production" => %{
              "@context" => %{
                "part" => %{
                  "@type" => "@id",
                  "@container" => "@set"
                }
              }
            }
          },
          "@id" => "http://example.org/1",
          "@type" => "HumanMadeObject",
          "produced_by" => %{
            "@type" => "Production",
            "part" => [
              %{
                "@type" => "Production",
                "_label" => "Test Part"
              }
            ],
            "_label" => "Top Production"
          }
        }
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        assert JSON.LD.compact(data.input, data.context) == data.output
      end
    end)
  end
end
