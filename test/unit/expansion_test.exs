defmodule JSON.LD.ExpansionTest do
  use ExUnit.Case, async: false

  import JSON.LD.Expansion, only: [expand_value: 3]

  alias RDF.NS.{RDFS, XSD}

  test "Expanded form of a JSON-LD document (EXAMPLE 55 and 56 of https://www.w3.org/TR/json-ld/#expanded-document-form)" do
    input = Poison.Parser.parse! """
      {
         "@context":
         {
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
    assert JSON.LD.expand(input) == Poison.Parser.parse! """
      [
        {
          "http://xmlns.com/foaf/0.1/name": [
            { "@value": "Manu Sporny" }
          ],
          "http://xmlns.com/foaf/0.1/homepage": [
            { "@id": "http://manu.sporny.org/" }
          ]
        }
      ]
      """
  end

  %{
    "empty doc" => %{
      input: %{},
      output: []
    },
    "@list coercion" => %{
      input: %{
        "@context" => %{
          "foo" => %{"@id" => "http://example.com/foo", "@container" => "@list"}
        },
        "foo" => [%{"@value" => "bar"}]\
      },
      output: [%{
        "http://example.com/foo" => [%{"@list" => [%{"@value" => "bar"}]}]
      }]
    },
    "native values in list" => %{
      input: %{
        "http://example.com/foo" => %{"@list" => [1, 2]}
      },
      output: [%{
        "http://example.com/foo" => [%{"@list" => [%{"@value" => 1}, %{"@value" => 2}]}]
      }]
    },
    "@graph" => %{
      input: %{
        "@context" => %{"ex" => "http://example.com/"},
        "@graph" => [
          %{"ex:foo" => %{"@value" => "foo"}},
          %{"ex:bar" => %{"@value" => "bar"}}
        ]
      },
      output: [
        %{"http://example.com/foo" => [%{"@value" => "foo"}]},
        %{"http://example.com/bar" => [%{"@value" => "bar"}]}
      ]
    },
    "@type with CURIE" => %{
      input: %{
        "@context" => %{"ex" => "http://example.com/"},
        "@type" => "ex:type"
      },
      output: [
        %{"@type" => ["http://example.com/type"]}
      ]
    },
    "@type with CURIE and muliple values" => %{
      input: %{
        "@context" => %{"ex" => "http://example.com/"},
        "@type" => ["ex:type1", "ex:type2"]
      },
      output: [
        %{"@type" => ["http://example.com/type1", "http://example.com/type2"]}
      ]
    },
    "@value with false" => %{
      input: %{"http://example.com/ex" => %{"@value" => false}},
      output: [%{"http://example.com/ex" => [%{"@value" => false}]}]
    }
  }
  |> Enum.each(fn ({title, data}) ->
       @tag data: data
       test title, %{data: data} do
         assert JSON.LD.expand(data.input) == data.output
       end
     end)

  describe "with relative IRIs" do
    %{
      "base" => %{
        input: %{
          "@id" => "",
          "@type" => (RDFS.Resource |> RDF.uri |> to_string)
        },
        output: [%{
          "@id" => "http://example.org/",
          "@type" => [RDFS.Resource |> RDF.uri |> to_string]
        }]
      },
      "relative" => %{
        input: %{
          "@id" => "a/b",
          "@type" => (RDFS.Resource |> RDF.uri |> to_string)
        },
        output: [%{
          "@id" => "http://example.org/a/b",
          "@type" => [RDFS.Resource |> RDF.uri |> to_string]
        }]
      },
      "hash" => %{
        input: %{
          "@id" => "#a",
          "@type" => (RDFS.Resource |> RDF.uri |> to_string)
        },
        output: [%{
          "@id" => "http://example.org/#a",
          "@type" => [RDFS.Resource |> RDF.uri |> to_string]
        }]
      },
      "unmapped @id" => %{
        input: %{
          "http://example.com/foo" => %{"@id" => "bar"}
        },
        output: [%{
          "http://example.com/foo" => [%{"@id" => "http://example.org/bar"}]
        }]
      },
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: data} do
           assert JSON.LD.expand(data.input, base: "http://example.org/") == data.output
         end
       end)
  end

  describe "keyword aliasing" do
    %{
      "@id" => %{
        input: %{
          "@context" => %{"id" => "@id"},
          "id" => "",
          "@type" => (RDFS.Resource |> RDF.uri |> to_string)
        },
        output: [%{
          "@id" => "",
          "@type" =>[ (RDFS.Resource |> RDF.uri |> to_string)]
        }]
      },
      "@type" => %{
        input: %{
          "@context" => %{"type" => "@type"},
          "type" => (RDFS.Resource |> RDF.uri |> to_string),
          "http://example.com/foo" => %{"@value" => "bar", "type" => "http://example.com/baz"}
        },
        output: [%{
          "@type" => [RDFS.Resource |> RDF.uri |> to_string],
          "http://example.com/foo" => [%{"@value" => "bar", "@type" => "http://example.com/baz"}]
        }]
      },
      "@language" => %{
        input: %{
          "@context" => %{"language" => "@language"},
          "http://example.com/foo" => %{"@value" => "bar", "language" => "baz"}
        },
        output: [%{
          "http://example.com/foo" => [%{"@value" => "bar", "@language" => "baz"}]
        }]
      },
      "@value" => %{
        input: %{
          "@context" => %{"literal" => "@value"},
          "http://example.com/foo" => %{"literal" => "bar"}
        },
        output: [%{
          "http://example.com/foo" => [%{"@value" => "bar"}]
        }]
      },
      "@list" => %{
        input: %{
          "@context" => %{"list" => "@list"},
          "http://example.com/foo" => %{"list" => ["bar"]}
        },
        output: [%{
          "http://example.com/foo" => [%{"@list" => [%{"@value" => "bar"}]}]
        }]
      },
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: data} do
           assert JSON.LD.expand(data.input) == data.output
         end
       end)
  end

  describe "native types" do
    %{
      "true" => %{
        input: %{
          "@context" => %{"e" => "http://example.org/vocab#"},
          "e:bool" => true
        },
        output: [%{
          "http://example.org/vocab#bool" => [%{"@value" => true}]
        }]
      },
      "false" => %{
        input: %{
          "@context" => %{"e" => "http://example.org/vocab#"},
          "e:bool" => false
        },
        output: [%{
          "http://example.org/vocab#bool" => [%{"@value" => false}]
        }]
      },
      "double" => %{
        input: %{
          "@context" => %{"e" => "http://example.org/vocab#"},
          "e:double" => 1.23
        },
        output: [%{
          "http://example.org/vocab#double" => [%{"@value" => 1.23}]
        }]
      },
      "double-zero" => %{
        input: %{
          "@context" => %{"e" => "http://example.org/vocab#"},
          "e:double-zero" => 0.0e0
        },
        output: [%{
          "http://example.org/vocab#double-zero" => [%{"@value" => 0.0e0}]
        }]
      },
      "integer" => %{
        input: %{
          "@context" => %{"e" => "http://example.org/vocab#"},
          "e:integer" => 123
        },
        output: [%{
          "http://example.org/vocab#integer" => [%{"@value" => 123}]
        }]
      },
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: data} do
           assert JSON.LD.expand(data.input) == data.output
         end
       end)
  end

  describe "coerced typed values" do
    %{
      "boolean" => %{
        input: %{
          "@context" => %{"foo" => %{"@id" => "http://example.org/foo", "@type" => to_string(XSD.boolean)}},
          "foo" => "true"
        },
        output: [%{
          "http://example.org/foo" => [%{"@value" => "true", "@type" => to_string(XSD.boolean)}]
        }]
      },
      "date" => %{
        input: %{
          "@context" => %{"foo" => %{"@id" => "http://example.org/foo", "@type" => to_string(XSD.date)}},
          "foo" => "2011-03-26"
        },
        output: [%{
          "http://example.org/foo" => [%{"@value" => "2011-03-26", "@type" => to_string(XSD.date)}]
        }]
      },
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: data} do
           assert JSON.LD.expand(data.input) == data.output
         end
       end)
  end

  describe "null" do
    %{
      "value" => %{
        input: %{"http://example.com/foo" => nil},
        output: []
      },
      "@value" => %{
        input: %{"http://example.com/foo" => %{"@value" => nil}},
        output: []
      },
      "@value and non-null @type" => %{
        input: %{"http://example.com/foo" => %{"@value" => nil, "@type" => "http://type"}},
        output: []
      },
      "@value and non-null @language" => %{
        input: %{"http://example.com/foo" => %{"@value" => nil, "@language" => "en"}},
        output: []
      },
      "array with null elements" => %{
        input: %{
          "http://example.com/foo" => [nil]
        },
        output: [%{
          "http://example.com/foo" => []
        }]
      },
      "@set with null @value" => %{
        input: %{
          "http://example.com/foo" => [
            %{"@value" => nil, "@type" => "http://example.org/Type"}
          ]
        },
        output: [%{
          "http://example.com/foo" => []
        }]
      }
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: data} do
           assert JSON.LD.expand(data.input) == data.output
         end
       end)
  end

  describe "default language" do
    %{
      "value with coerced null language" => %{
        input: %{
          "@context" => %{
            "@language" => "en",
            "ex" => "http://example.org/vocab#",
            "ex:german" => %{ "@language" => "de" },
            "ex:nolang" => %{ "@language" => nil }
          },
          "ex:german" => "german",
          "ex:nolang" => "no language"
        },
        output: [
          %{
            "http://example.org/vocab#german" => [%{"@value" => "german", "@language" => "de"}],
            "http://example.org/vocab#nolang" => [%{"@value" => "no language"}]
          }
        ]
      },
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: data} do
           assert JSON.LD.expand(data.input) == data.output
         end
       end)
  end

  describe "default vocabulary" do
    %{
      "property" => %{
        input: %{
          "@context" => %{"@vocab" => "http://example.com/"},
          "verb" => %{"@value" => "foo"}
        },
        output: [%{
          "http://example.com/verb" => [%{"@value" => "foo"}]
        }]
      },
      "datatype" => %{
        input: %{
          "@context" => %{"@vocab" => "http://example.com/"},
          "http://example.org/verb" => %{"@value" => "foo", "@type" => "string"}
        },
        output: [%{
          "http://example.org/verb" => [%{"@value" => "foo", "@type" => "http://example.com/string"}]
        }]
      },
      "expand-0028" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example.org/vocab#",
            "date" => %{ "@type" => "dateTime" }
          },
          "@id" => "example1",
          "@type" => "test",
          "date" => "2011-01-25T00:00:00Z",
          "embed" => %{
            "@id" => "example2",
            "expandedDate" => %{ "@value" => "2012-08-01T00:00:00Z", "@type" => "dateTime" }
          }
        },
        output: [
          %{
            "@id" => "http://foo/bar/example1",
            "@type" => ["http://example.org/vocab#test"],
            "http://example.org/vocab#date" => [
              %{
                "@value" => "2011-01-25T00:00:00Z",
                "@type" => "http://example.org/vocab#dateTime"
              }
            ],
            "http://example.org/vocab#embed" => [
              %{
                "@id" => "http://foo/bar/example2",
                "http://example.org/vocab#expandedDate" => [
                  %{
                    "@value" => "2012-08-01T00:00:00Z",
                    "@type" => "http://example.org/vocab#dateTime"
                  }
                ]
              }
            ]
          }
        ]
      }
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: data} do
           assert JSON.LD.expand(data.input, base: "http://foo/bar/") == data.output
         end
       end)
  end

  describe "unmapped properties" do
    %{
      "unmapped key" => %{
        input: %{
          "foo" => "bar"
        },
        output: []
      },
      "unmapped @type as datatype" => %{
        input: %{
          "http://example.com/foo" => %{"@value" => "bar", "@type" => "baz"}
        },
        output: [%{
          "http://example.com/foo" => [%{"@value" => "bar", "@type" => "http://example/baz"}]
        }]
      },
      "unknown keyword" => %{
        input: %{
          "@foo" => "bar"
        },
        output: []
      },
      "value" => %{
        input: %{
          "@context" => %{"ex" => %{"@id" => "http://example.org/idrange", "@type" => "@id"}},
          "@id" => "http://example.org/Subj",
          "idrange" => "unmapped"
        },
        output: []
      },
      "context reset" => %{
        input: %{
          "@context" => %{"ex" => "http://example.org/", "prop" => "ex:prop"},
          "@id" => "http://example.org/id1",
          "prop" => "prop",
          "ex:chain" => %{
            "@context" => nil,
            "@id" => "http://example.org/id2",
            "prop" => "prop"
          }
        },
        output: [%{
          "@id" => "http://example.org/id1",
          "http://example.org/prop" => [%{"@value" => "prop"}],
          "http://example.org/chain" => [%{"@id" => "http://example.org/id2"}]
        }
      ]}
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: data} do
           assert JSON.LD.expand(data.input, base: "http://example/") == data.output
         end
       end)
  end

  describe "lists" do
    %{
      "empty" => %{
        input: %{"http://example.com/foo" => %{"@list" => []}},
        output: [%{"http://example.com/foo" => [%{"@list" => []}]}]
      },
      "coerced empty" => %{
        input: %{
          "@context" => %{"http://example.com/foo" => %{"@container" => "@list"}},
          "http://example.com/foo" => []
        },
        output: [%{"http://example.com/foo" => [%{"@list" => []}]}]
      },
      "coerced single element" => %{
        input: %{
          "@context" => %{"http://example.com/foo" => %{"@container" => "@list"}},
          "http://example.com/foo" => [ "foo" ]
        },
        output: [%{"http://example.com/foo" => [%{"@list" => [%{"@value" => "foo"}]}]}]
      },
      "coerced multiple elements" => %{
        input: %{
          "@context" => %{"http://example.com/foo" => %{"@container" => "@list"}},
          "http://example.com/foo" => [ "foo", "bar" ]
        },
        output: [%{
          "http://example.com/foo" => [%{"@list" => [ %{"@value" => "foo"}, %{"@value" => "bar"} ]}]
        }]
      },
      "explicit list with coerced @id values" => %{
        input: %{
          "@context" => %{"http://example.com/foo" => %{"@type" => "@id"}},
          "http://example.com/foo" => %{"@list" => ["http://foo", "http://bar"]}
        },
        output: [%{
          "http://example.com/foo" => [%{"@list" => [%{"@id" => "http://foo"}, %{"@id" => "http://bar"}]}]
        }]
      },
      "explicit list with coerced datatype values" => %{
        input: %{
          "@context" => %{"http://example.com/foo" => %{"@type" => to_string(XSD.date)}},
          "http://example.com/foo" => %{"@list" => ["2012-04-12"]}
        },
        output: [%{
          "http://example.com/foo" => [%{"@list" => [%{"@value" => "2012-04-12", "@type" => to_string(XSD.date)}]}]
        }]
      },
      "expand-0004" => %{
        input: Poison.Parser.parse!(~s({
          "@context": {
            "mylist1": {"@id": "http://example.com/mylist1", "@container": "@list"},
            "mylist2": {"@id": "http://example.com/mylist2", "@container": "@list"},
            "myset2": {"@id": "http://example.com/myset2", "@container": "@set"},
            "myset3": {"@id": "http://example.com/myset3", "@container": "@set"}
          },
          "http://example.org/property": { "@list": "one item" }
        })),
        output: Poison.Parser.parse!(~s([
          {
            "http://example.org/property": [
              {
                "@list": [
                  {
                    "@value": "one item"
                  }
                ]
              }
            ]
          }
        ]))
      }
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: data} do
           assert JSON.LD.expand(data.input) == data.output
         end
       end)
  end

  describe "sets" do
    %{
      "empty" => %{
        input: %{
          "http://example.com/foo" => %{"@set" => []}
        },
        output: [%{
          "http://example.com/foo" => []
        }]
      },
      "coerced empty" => %{
        input: %{
          "@context" => %{"http://example.com/foo" => %{"@container" => "@set"}},
          "http://example.com/foo" => []
        },
        output: [%{
          "http://example.com/foo" => []
        }]
      },
      "coerced single element" => %{
        input: %{
          "@context" => %{"http://example.com/foo" => %{"@container" => "@set"}},
          "http://example.com/foo" => [ "foo" ]
        },
        output: [%{
          "http://example.com/foo" => [ %{"@value" => "foo"} ]
        }]
      },
      "coerced multiple elements" => %{
        input: %{
          "@context" => %{"http://example.com/foo" => %{"@container" => "@set"}},
          "http://example.com/foo" => [ "foo", "bar" ]
        },
        output: [%{
          "http://example.com/foo" => [ %{"@value" => "foo"}, %{"@value" => "bar"} ]
        }]
      },
      "array containing set" => %{
        input: %{
          "http://example.com/foo" => [%{"@set" => []}]
        },
        output: [%{
          "http://example.com/foo" => []
        }]
      },
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: data} do
           assert JSON.LD.expand(data.input) == data.output
         end
       end)
  end

  describe "language maps" do
    %{
      "simple map" => %{
        input: %{
          "@context" => %{
            "vocab" => "http://example.com/vocab/",
            "label" => %{
              "@id" => "vocab:label",
              "@container" => "@language"
            }
          },
          "@id" => "http://example.com/queen",
          "label" => %{
            "en" => "The Queen",
            "de" => [ "Die Königin", "Ihre Majestät" ]
          }
        },
        output: [
          %{
            "@id" => "http://example.com/queen",
            "http://example.com/vocab/label" => [
              %{"@value" => "Die Königin", "@language" => "de"},
              %{"@value" => "Ihre Majestät", "@language" => "de"},
              %{"@value" => "The Queen", "@language" => "en"}
            ]
          }
        ]
      },
# TODO: Only the order of result is not correct, the content seems ok (although
#         it's not clear why, since the "http://example.com/vocab/label" object is not handled in 7.5 code (at least debug statement are not printed
#      "expand-0035" => %{
#        input: %{
#          "@context" => %{
#            "@vocab" => "http://example.com/vocab/",
#            "@language" => "it",
#            "label" => %{
#              "@container" => "@language"
#            }
#          },
#          "@id" => "http://example.com/queen",
#          "label" => %{
#            "en" => "The Queen",
#            "de" => [ "Die Königin", "Ihre Majestät" ]
#          },
#          "http://example.com/vocab/label" => [
#            "Il re",
#            %{ "@value" => "The king", "@language" => "en" }
#          ]
#        },
#        output: [
#          %{
#            "@id" => "http://example.com/queen",
#            "http://example.com/vocab/label" => [
#              %{"@value" => "Il re", "@language" => "it"},
#              %{"@value" => "The king", "@language" => "en"},
#              %{"@value" => "Die Königin", "@language" => "de"},
#              %{"@value" => "Ihre Majestät", "@language" => "de"},
#              %{"@value" => "The Queen", "@language" => "en"},
#            ]
#          }
#        ]
#      }
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: data} do
           assert JSON.LD.expand(data.input) == data.output
         end
       end)
  end

  describe "@reverse" do
    %{
      "expand-0037" => %{
        input: Poison.Parser.parse!(~s({
          "@context": {
            "name": "http://xmlns.com/foaf/0.1/name"
          },
          "@id": "http://example.com/people/markus",
          "name": "Markus Lanthaler",
          "@reverse": {
            "http://xmlns.com/foaf/0.1/knows": {
              "@id": "http://example.com/people/dave",
              "name": "Dave Longley"
            }
          }
        })),
        output: Poison.Parser.parse!(~s([
          {
            "@id": "http://example.com/people/markus",
            "@reverse": {
              "http://xmlns.com/foaf/0.1/knows": [
                {
                  "@id": "http://example.com/people/dave",
                  "http://xmlns.com/foaf/0.1/name": [
                    {
                      "@value": "Dave Longley"
                    }
                  ]
                }
              ]
            },
            "http://xmlns.com/foaf/0.1/name": [
              {
                "@value": "Markus Lanthaler"
              }
            ]
          }
        ]))
      },
      "expand-0043" => %{
        input: Poison.Parser.parse!(~s({
          "@context": {
            "name": "http://xmlns.com/foaf/0.1/name",
            "isKnownBy": { "@reverse": "http://xmlns.com/foaf/0.1/knows" }
          },
          "@id": "http://example.com/people/markus",
          "name": "Markus Lanthaler",
          "@reverse": {
            "isKnownBy": [
              {
                "@id": "http://example.com/people/dave",
                "name": "Dave Longley"
              },
              {
                "@id": "http://example.com/people/gregg",
                "name": "Gregg Kellogg"
              }
            ]
          }
        })),
        output: Poison.Parser.parse!(~s([
          {
            "@id": "http://example.com/people/markus",
            "http://xmlns.com/foaf/0.1/knows": [
              {
                "@id": "http://example.com/people/dave",
                "http://xmlns.com/foaf/0.1/name": [
                  {
                    "@value": "Dave Longley"
                  }
                ]
              },
              {
                "@id": "http://example.com/people/gregg",
                "http://xmlns.com/foaf/0.1/name": [
                  {
                    "@value": "Gregg Kellogg"
                  }
                ]
              }
            ],
            "http://xmlns.com/foaf/0.1/name": [
              {
                "@value": "Markus Lanthaler"
              }
            ]
          }
        ]))
      },
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: data} do
           assert JSON.LD.expand(data.input) == data.output
         end
       end)
  end

  describe "@index" do
    %{
      "string annotation" => %{
        input: %{
          "@context" => %{
            "container" => %{
              "@id" => "http://example.com/container",
              "@container" => "@index"
            }
          },
          "@id" => "http://example.com/annotationsTest",
          "container" => %{
            "en" => "The Queen",
            "de" => [ "Die Königin", "Ihre Majestät" ]
          }
        },
        output: [
          %{
            "@id" => "http://example.com/annotationsTest",
            "http://example.com/container" => [
              %{"@value" => "Die Königin", "@index" => "de"},
              %{"@value" => "Ihre Majestät", "@index" => "de"},
              %{"@value" => "The Queen", "@index" => "en"}
            ]
          }
        ]
      },
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: data} do
           assert JSON.LD.expand(data.input) == data.output
         end
       end)
  end

  describe "errors" do
    %{
      "non-null @value and null @type" => %{
        input: %{"http://example.com/foo" => %{"@value" => "foo", "@type" => nil}},
        exception: JSON.LD.InvalidTypeValueError
      },
      "non-null @value and null @language" => %{
        input: %{"http://example.com/foo" => %{"@value" => "foo", "@language" => nil}},
        exception: JSON.LD.InvalidLanguageTaggedStringError
      },
      "value with null language" => %{
        input: %{
          "@context" => %{"@language" => "en"},
          "http://example.org/nolang" => %{"@value" => "no language", "@language" => nil}
        },
        exception: JSON.LD.InvalidLanguageTaggedStringError
      },
      "@list containing @list" => %{
        input: %{
          "http://example.com/foo" => %{"@list" => [%{"@list" => ["baz"]}]}
        },
        exception: JSON.LD.ListOfListsError
      },
      "@list containing @list (with coercion)" => %{
        input: %{
          "@context" => %{"foo" => %{"@id" => "http://example.com/foo", "@container" => "@list"}},
          "foo" => [%{"@list" => ["baz"]}]
        },
        exception: JSON.LD.ListOfListsError
      },
      "coerced @list containing an array" => %{
        input: %{
          "@context" => %{"foo" => %{"@id" => "http://example.com/foo", "@container" => "@list"}},
          "foo" => [["baz"]]
        },
        exception: JSON.LD.ListOfListsError
      },

      "@reverse object with an @id property" => %{
        input: Poison.Parser.parse!(~s({
          "@id": "http://example/foo",
          "@reverse": {
            "@id": "http://example/bar"
          }
        })),
        exception: JSON.LD.InvalidReversePropertyMapError,
      },
      "colliding keywords" => %{
        input: Poison.Parser.parse!(~s({
          "@context": {
            "id": "@id",
            "ID": "@id"
          },
          "id": "http://example/foo",
          "ID": "http://example/bar"
        })),
        exception: JSON.LD.CollidingKeywordsError,
      }
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: data} do
           assert_raise data.exception, fn -> JSON.LD.expand(data.input) end
         end
       end)
  end

  describe "expand_value" do
    setup do
      context = JSON.LD.context(%{
        "dc" => "http://purl.org/dc/terms/", # TODO: RDF::Vocab::DC.to_uri.to_s,
        "ex" => "http://example.org/",
        "foaf" => "http://xmlns.com/foaf/0.1/", # TODO: RDF::Vocab::FOAF.to_uri.to_s,
        "xsd" => "http://www.w3.org/2001/XMLSchema#",
        "foaf:age" => %{"@type" => "xsd:integer"},
        "foaf:knows" => %{"@type" => "@id"},
        "dc:created" => %{"@type" => "xsd:date"},
        "ex:integer" => %{"@type" => "xsd:integer"},
        "ex:double" => %{"@type" => "xsd:double"},
        "ex:boolean" => %{"@type" => "xsd:boolean"},
      })
      %{example_context: context}
    end

    ~w(boolean integer string dateTime date time)
    |> Enum.each(fn dt ->
      @tag skip: "This seems to be RDF.rb specific. The @id keys are produced when value is an RDF::URI or RDF::Node. Do we need/want something similar?"
      @tag dt: dt
      test "expands datatype xsd:#{dt}", %{dt: dt, example_context: context} do
        assert expand_value(context, "foo", apply(XSD, String.to_atom(dt), []) |> to_string) ==
          %{"@id" => "http://www.w3.org/2001/XMLSchema##{dt}"}
      end
    end)

    %{
      "absolute IRI" =>   ["foaf:knows",  "http://example.com/",  %{"@id" => "http://example.com/"}],
      "term" =>           ["foaf:knows",  "ex",                   %{"@id" => "ex"}],
      "prefix:suffix" =>  ["foaf:knows",  "ex:suffix",            %{"@id" => "http://example.org/suffix"}],
      "no IRI" =>         ["foo",         "http://example.com/",  %{"@value" => "http://example.com/"}],
      "no term" =>        ["foo",         "ex",                   %{"@value" => "ex"}],
      "no prefix" =>      ["foo",         "ex:suffix",            %{"@value" => "ex:suffix"}],
      "integer" =>        ["foaf:age",    "54",                   %{"@value" => "54", "@type" => XSD.integer |> to_string}],
      "date " =>          ["dc:created",  "2011-12-27Z",          %{"@value" => "2011-12-27Z", "@type" => XSD.date |> to_string}],
      "native boolean" => ["foo", true,                           %{"@value" => true}],
      "native integer" => ["foo", 1,                              %{"@value" => 1}],
      "native double" =>  ["foo", 1.1e1,                          %{"@value" => 1.1E1}],
# TODO: Do we really want to support the following? RDF.rb has another implementation and uses this function
#       for its implementation of fromRdf, instead of the  RDF to Object Conversion algorithm in the spec ...
#      "native date" =>    ["foo", ~D[2011-12-27],       %{"@value" => "2011-12-27", "@type" => XSD.date |> to_string}],
#      "native time" =>    ["foo", ~T[10:11:12Z],        %{"@value" => "10:11:12Z", "@type" => XSD.time |> to_string}],
#      "native dateTime" =>["foo", DateTime.from_iso8601("2011-12-27T10:11:12Z") |> elem(1), %{"@value" => "2011-12-27T10:11:12Z", "@type" => XSD.dateTime |> to_string}],
#      "rdf boolean" =>    ["foo", RDF::Literal(true),             %{"@value" => "true", "@type" => RDF::XSD.boolean.to_s}],
#      "rdf integer" =>    ["foo", RDF::Literal(1),                %{"@value" => "1", "@type" => XSD.integer |> to_string],
#      "rdf decimal" =>    ["foo", RDF::Literal::Decimal.new(1.1), %{"@value" => "1.1", "@type" => XSD.decimal |> to_string}],
#      "rdf double" =>     ["foo", RDF::Literal::Double.new(1.1),  %{"@value" => "1.1E0", "@type" => XSD.double |> to_string}],
#      "rdf URI" =>        ["foo", RDF::URI("foo"),                %{"@id" => "foo"}],
#      "rdf date " =>      ["foo", RDF::Literal(Date.parse("2011-12-27")), %{"@value" => "2011-12-27", "@type" => XSD.date |> to_string}],
#      "rdf nonNeg" =>     ["foo", RDF::Literal::NonNegativeInteger.new(1), %{"@value" => "1", "@type" => XSD.nonNegativeInteger |> to_string}],
#      "rdf float" =>      ["foo", RDF::Literal::Float.new(1.0), %{"@value" => "1.0", "@type" => XSD.float |> to_string}],
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: [key, compacted, expanded], example_context: context} do
           assert expand_value(context, key, compacted) == expanded
         end
       end)

#    context "@language" do
#      before(:each) {subject.default_language = "en"}
    %{
      "no IRI" =>         ["foo",         "http://example.com/",  %{"@value" => "http://example.com/", "@language" => "en"}],
      "no term" =>        ["foo",         "ex",                   %{"@value" => "ex", "@language" => "en"}],
      "no prefix" =>      ["foo",         "ex:suffix",            %{"@value" => "ex:suffix", "@language" => "en"}],
      "native boolean" => ["foo",         true,                   %{"@value" => true}],
      "native integer" => ["foo",         1,                      %{"@value" => 1}],
      "native double" =>  ["foo",         1.1,                    %{"@value" => 1.1}],
    }
    |> Enum.each(fn ({title, data}) ->
        # TODO
#         @tag skip: "Do these errors originate from the differing context setup?"
        @tag skip: "Why does this produce @language tags in RDF.rb, although no term definition of foo exists? Is this also RDF.rb specific?"
         @tag data: data
         test "@language #{title}", %{data: [key, compacted, expanded], example_context: context} do
           assert expand_value(context, key, compacted) == expanded
         end
       end)

    %{
      "boolean-boolean" => ["ex:boolean", true,   %{"@value" => true, "@type" => XSD.boolean |> to_string}],
      "boolean-integer" => ["ex:integer", true,   %{"@value" => true, "@type" => XSD.integer |> to_string}],
      "boolean-double"  => ["ex:double",  true,   %{"@value" => true, "@type" => XSD.double |> to_string}],
      "double-boolean"  => ["ex:boolean", 1.1,    %{"@value" => 1.1, "@type" => XSD.boolean |> to_string}],
      "double-double"   => ["ex:double",  1.1,    %{"@value" => 1.1, "@type" => XSD.double |> to_string}],
      "double-integer"  => ["foaf:age",   1.1,    %{"@value" => 1.1, "@type" => XSD.integer |> to_string}],
      "integer-boolean" => ["ex:boolean", 1,      %{"@value" => 1, "@type" => XSD.boolean |> to_string}],
      "integer-double"  => ["ex:double",  1,      %{"@value" => 1, "@type" => XSD.double |> to_string}],
      "integer-integer" => ["foaf:age",   1,      %{"@value" => 1, "@type" => XSD.integer |> to_string}],
      "string-boolean"  => ["ex:boolean", "foo",  %{"@value" => "foo", "@type" => XSD.boolean |> to_string}],
      "string-double"   => ["ex:double",  "foo",  %{"@value" => "foo", "@type" => XSD.double |> to_string}],
      "string-integer"  => ["foaf:age",   "foo",  %{"@value" => "foo", "@type" => XSD.integer |> to_string}],
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test "coercion #{title}", %{data: [key, compacted, expanded], example_context: context} do
           assert expand_value(context, key, compacted) == expanded
         end
       end)
  end

end
