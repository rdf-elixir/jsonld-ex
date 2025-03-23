defmodule JSON.LD.ExpansionTest do
  use JSON.LD.Case, async: false

  doctest JSON.LD.Expansion

  import JSON.LD.Expansion, only: [expand_value: 3]

  test "Expanded form of a JSON-LD document (EXAMPLE 55 and 56 of https://www.w3.org/TR/json-ld/#expanded-document-form)" do
    input =
      Jason.decode!("""
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
      """)

    assert JSON.LD.expand(input) ==
             Jason.decode!("""
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
             """)
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
        "foo" => [%{"@value" => "bar"}]
      },
      output: [
        %{
          "http://example.com/foo" => [%{"@list" => [%{"@value" => "bar"}]}]
        }
      ]
    },
    "native values in list" => %{
      input: %{
        "http://example.com/foo" => %{"@list" => [1, 2]}
      },
      output: [
        %{
          "http://example.com/foo" => [%{"@list" => [%{"@value" => 1}, %{"@value" => 2}]}]
        }
      ]
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
  |> Enum.each(fn {title, data} ->
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
          "@type" => RDFS.Resource |> RDF.uri() |> to_string
        },
        output: [
          %{
            "@id" => "http://example.org/",
            "@type" => [RDFS.Resource |> RDF.uri() |> to_string]
          }
        ]
      },
      "relative" => %{
        input: %{
          "@id" => "a/b",
          "@type" => RDFS.Resource |> RDF.uri() |> to_string
        },
        output: [
          %{
            "@id" => "http://example.org/a/b",
            "@type" => [RDFS.Resource |> RDF.uri() |> to_string]
          }
        ]
      },
      "hash" => %{
        input: %{
          "@id" => "#a",
          "@type" => RDFS.Resource |> RDF.uri() |> to_string
        },
        output: [
          %{
            "@id" => "http://example.org/#a",
            "@type" => [RDFS.Resource |> RDF.uri() |> to_string]
          }
        ]
      },
      "unmapped @id" => %{
        input: %{
          "http://example.com/foo" => %{"@id" => "bar"}
        },
        output: [
          %{
            "http://example.com/foo" => [%{"@id" => "http://example.org/bar"}]
          }
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
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
          "@type" => RDFS.Resource |> RDF.uri() |> to_string
        },
        output: [
          %{
            "@id" => "",
            "@type" => [RDFS.Resource |> RDF.uri() |> to_string]
          }
        ]
      },
      "@type" => %{
        input: %{
          "@context" => %{"type" => "@type"},
          "type" => RDFS.Resource |> RDF.uri() |> to_string,
          "http://example.com/foo" => %{"@value" => "bar", "type" => "http://example.com/baz"}
        },
        output: [
          %{
            "@type" => [RDFS.Resource |> RDF.uri() |> to_string],
            "http://example.com/foo" => [
              %{"@value" => "bar", "@type" => "http://example.com/baz"}
            ]
          }
        ]
      },
      "@language" => %{
        input: %{
          "@context" => %{"language" => "@language"},
          "http://example.com/foo" => %{"@value" => "bar", "language" => "baz"}
        },
        output: [
          %{
            "http://example.com/foo" => [%{"@value" => "bar", "@language" => "baz"}]
          }
        ]
      },
      "@value" => %{
        input: %{
          "@context" => %{"literal" => "@value"},
          "http://example.com/foo" => %{"literal" => "bar"}
        },
        output: [
          %{
            "http://example.com/foo" => [%{"@value" => "bar"}]
          }
        ]
      },
      "@list" => %{
        input: %{
          "@context" => %{"list" => "@list"},
          "http://example.com/foo" => %{"list" => ["bar"]}
        },
        output: [
          %{
            "http://example.com/foo" => [%{"@list" => [%{"@value" => "bar"}]}]
          }
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
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
        output: [
          %{
            "http://example.org/vocab#bool" => [%{"@value" => true}]
          }
        ]
      },
      "false" => %{
        input: %{
          "@context" => %{"e" => "http://example.org/vocab#"},
          "e:bool" => false
        },
        output: [
          %{
            "http://example.org/vocab#bool" => [%{"@value" => false}]
          }
        ]
      },
      "double" => %{
        input: %{
          "@context" => %{"e" => "http://example.org/vocab#"},
          "e:double" => 1.23
        },
        output: [
          %{
            "http://example.org/vocab#double" => [%{"@value" => 1.23}]
          }
        ]
      },
      "double-zero" => %{
        input: %{
          "@context" => %{"e" => "http://example.org/vocab#"},
          "e:double-zero" => 0.0e0
        },
        output: [
          %{
            "http://example.org/vocab#double-zero" => [%{"@value" => 0.0e0}]
          }
        ]
      },
      "integer" => %{
        input: %{
          "@context" => %{"e" => "http://example.org/vocab#"},
          "e:integer" => 123
        },
        output: [
          %{
            "http://example.org/vocab#integer" => [%{"@value" => 123}]
          }
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        assert JSON.LD.expand(data.input) == data.output
      end
    end)
  end

  describe "with @type: @json" do
    %{
      "true" => %{
        input: %{
          "@context" => %{
            "@version" => 1.1,
            "e" => %{"@id" => "http://example.org/vocab#bool", "@type" => "@json"}
          },
          "e" => true
        },
        output: [
          %{
            "http://example.org/vocab#bool" => [%{"@value" => true, "@type" => "@json"}]
          }
        ]
      },
      "object" => %{
        input: %{
          "@context" => %{
            "@version" => 1.1,
            "e" => %{"@id" => "http://example.org/vocab#object", "@type" => "@json"}
          },
          "e" => %{"foo" => "bar"}
        },
        output: [
          %{
            "http://example.org/vocab#object" => [
              %{"@value" => %{"foo" => "bar"}, "@type" => "@json"}
            ]
          }
        ]
      },
      "array" => %{
        input: %{
          "@context" => %{
            "@version" => 1.1,
            "e" => %{"@id" => "http://example.org/vocab#array", "@type" => "@json"}
          },
          "e" => [%{"foo" => "bar"}]
        },
        output: [
          %{
            "http://example.org/vocab#array" => [
              %{"@value" => [%{"foo" => "bar"}], "@type" => "@json"}
            ]
          }
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
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
          "@context" => %{
            "foo" => %{"@id" => "http://example.org/foo", "@type" => to_string(XSD.boolean())}
          },
          "foo" => "true"
        },
        output: [
          %{
            "http://example.org/foo" => [
              %{"@value" => "true", "@type" => to_string(XSD.boolean())}
            ]
          }
        ]
      },
      "date" => %{
        input: %{
          "@context" => %{
            "foo" => %{"@id" => "http://example.org/foo", "@type" => to_string(XSD.date())}
          },
          "foo" => "2011-03-26"
        },
        output: [
          %{
            "http://example.org/foo" => [
              %{"@value" => "2011-03-26", "@type" => to_string(XSD.date())}
            ]
          }
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
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
        output: [
          %{
            "http://example.com/foo" => []
          }
        ]
      },
      "@set with null @value" => %{
        input: %{
          "http://example.com/foo" => [
            %{"@value" => nil, "@type" => "http://example.org/Type"}
          ]
        },
        output: [
          %{
            "http://example.com/foo" => []
          }
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        assert JSON.LD.expand(data.input) == data.output
      end
    end)
  end

  describe "@none handling" do
    %{
      "In language maps" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example.org/",
            "label" => %{
              "@container" => "@language"
            }
          },
          "label" => %{
            "en" => "The Queen",
            "de" => ["Die Königin", "Ihre Majestät"],
            "@none" => "No language"
          }
        },
        output: [
          %{
            "http://example.org/label" => [
              %{"@value" => "No language"},
              %{"@value" => "Die Königin", "@language" => "de"},
              %{"@value" => "Ihre Majestät", "@language" => "de"},
              %{"@value" => "The Queen", "@language" => "en"}
            ]
          }
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
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
            "ex:german" => %{"@language" => "de"},
            "ex:nolang" => %{"@language" => nil}
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
      }
    }
    |> Enum.each(fn {title, data} ->
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
        output: [
          %{
            "http://example.com/verb" => [%{"@value" => "foo"}]
          }
        ]
      },
      "datatype" => %{
        input: %{
          "@context" => %{"@vocab" => "http://example.com/"},
          "http://example.org/verb" => %{"@value" => "foo", "@type" => "string"}
        },
        output: [
          %{
            "http://example.org/verb" => [
              %{"@value" => "foo", "@type" => "http://example.com/string"}
            ]
          }
        ]
      },
      "expand-0028" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example.org/vocab#",
            "date" => %{"@type" => "dateTime"}
          },
          "@id" => "example1",
          "@type" => "test",
          "date" => "2011-01-25T00:00:00Z",
          "embed" => %{
            "@id" => "example2",
            "expandedDate" => %{"@value" => "2012-08-01T00:00:00Z", "@type" => "dateTime"}
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
    |> Enum.each(fn {title, data} ->
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
        output: [
          %{
            "http://example.com/foo" => [%{"@value" => "bar", "@type" => "http://example/baz"}]
          }
        ]
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
        output: [
          %{
            "@id" => "http://example.org/id1",
            "http://example.org/prop" => [%{"@value" => "prop"}],
            "http://example.org/chain" => [%{"@id" => "http://example.org/id2"}]
          }
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
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
          "http://example.com/foo" => ["foo"]
        },
        output: [%{"http://example.com/foo" => [%{"@list" => [%{"@value" => "foo"}]}]}]
      },
      "coerced multiple elements" => %{
        input: %{
          "@context" => %{"http://example.com/foo" => %{"@container" => "@list"}},
          "http://example.com/foo" => ["foo", "bar"]
        },
        output: [
          %{
            "http://example.com/foo" => [
              %{"@list" => [%{"@value" => "foo"}, %{"@value" => "bar"}]}
            ]
          }
        ]
      },
      "explicit list with coerced @id values" => %{
        input: %{
          "@context" => %{"http://example.com/foo" => %{"@type" => "@id"}},
          "http://example.com/foo" => %{"@list" => ["http://foo", "http://bar"]}
        },
        output: [
          %{
            "http://example.com/foo" => [
              %{"@list" => [%{"@id" => "http://foo"}, %{"@id" => "http://bar"}]}
            ]
          }
        ]
      },
      "explicit list with coerced datatype values" => %{
        input: %{
          "@context" => %{"http://example.com/foo" => %{"@type" => to_string(XSD.date())}},
          "http://example.com/foo" => %{"@list" => ["2012-04-12"]}
        },
        output: [
          %{
            "http://example.com/foo" => [
              %{"@list" => [%{"@value" => "2012-04-12", "@type" => to_string(XSD.date())}]}
            ]
          }
        ]
      },
      "expand-0004" => %{
        input: Jason.decode!(~s({
          "@context": {
            "mylist1": {"@id": "http://example.com/mylist1", "@container": "@list"},
            "mylist2": {"@id": "http://example.com/mylist2", "@container": "@list"},
            "myset2": {"@id": "http://example.com/myset2", "@container": "@set"},
            "myset3": {"@id": "http://example.com/myset3", "@container": "@set"}
          },
          "http://example.org/property": { "@list": "one item" }
        })),
        output: Jason.decode!(~s([
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
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        assert JSON.LD.expand(data.input) == data.output
      end
    end)
  end

  describe "nested lists in JSON-LD 1.1" do
    %{
      "@list containing @list" => %{
        input: %{
          "http://example.com/foo" => %{"@list" => [%{"@list" => ["baz"]}]}
        },
        output: [
          %{
            "http://example.com/foo" => [%{"@list" => [%{"@list" => [%{"@value" => "baz"}]}]}]
          }
        ]
      },
      "@list containing empty @list" => %{
        input: %{
          "http://example.com/foo" => %{"@list" => [%{"@list" => []}]}
        },
        output: [
          %{
            "http://example.com/foo" => [%{"@list" => [%{"@list" => []}]}]
          }
        ]
      },
      "@list containing @list (with coercion)" => %{
        input: %{
          "@context" => %{"foo" => %{"@id" => "http://example.com/foo", "@container" => "@list"}},
          "foo" => [%{"@list" => ["baz"]}]
        },
        output: [
          %{
            "http://example.com/foo" => [%{"@list" => [%{"@list" => [%{"@value" => "baz"}]}]}]
          }
        ]
      },
      "@list containing empty @list (with coercion)" => %{
        input: %{
          "@context" => %{"foo" => %{"@id" => "http://example.com/foo", "@container" => "@list"}},
          "foo" => [%{"@list" => []}]
        },
        output: [
          %{
            "http://example.com/foo" => [%{"@list" => [%{"@list" => []}]}]
          }
        ]
      },
      "coerced @list containing an array" => %{
        input: %{
          "@context" => %{"foo" => %{"@id" => "http://example.com/foo", "@container" => "@list"}},
          "foo" => [["baz"]]
        },
        output: [
          %{
            "http://example.com/foo" => [%{"@list" => [%{"@list" => [%{"@value" => "baz"}]}]}]
          }
        ]
      },
      "coerced @list containing an empty array" => %{
        input: %{
          "@context" => %{"foo" => %{"@id" => "http://example.com/foo", "@container" => "@list"}},
          "foo" => [[]]
        },
        output: [
          %{
            "http://example.com/foo" => [%{"@list" => [%{"@list" => []}]}]
          }
        ]
      },
      "coerced @list containing deep arrays" => %{
        input: %{
          "@context" => %{"foo" => %{"@id" => "http://example.com/foo", "@container" => "@list"}},
          "foo" => [[["baz"]]]
        },
        output: [
          %{
            "http://example.com/foo" => [
              %{"@list" => [%{"@list" => [%{"@list" => [%{"@value" => "baz"}]}]}]}
            ]
          }
        ]
      },
      "coerced @list containing deep empty arrays" => %{
        input: %{
          "@context" => %{"foo" => %{"@id" => "http://example.com/foo", "@container" => "@list"}},
          "foo" => [[[]]]
        },
        output: [
          %{
            "http://example.com/foo" => [%{"@list" => [%{"@list" => [%{"@list" => []}]}]}]
          }
        ]
      },
      "coerced @list containing multiple lists" => %{
        input: %{
          "@context" => %{"foo" => %{"@id" => "http://example.com/foo", "@container" => "@list"}},
          "foo" => [["a"], ["b"]]
        },
        output: [
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
        ]
      },
      "coerced @list containing mixed list values" => %{
        input: %{
          "@context" => %{"foo" => %{"@id" => "http://example.com/foo", "@container" => "@list"}},
          "foo" => [["a"], "b"]
        },
        output: [
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
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
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
        output: [
          %{
            "http://example.com/foo" => []
          }
        ]
      },
      "coerced empty" => %{
        input: %{
          "@context" => %{"http://example.com/foo" => %{"@container" => "@set"}},
          "http://example.com/foo" => []
        },
        output: [
          %{
            "http://example.com/foo" => []
          }
        ]
      },
      "coerced single element" => %{
        input: %{
          "@context" => %{"http://example.com/foo" => %{"@container" => "@set"}},
          "http://example.com/foo" => ["foo"]
        },
        output: [
          %{
            "http://example.com/foo" => [%{"@value" => "foo"}]
          }
        ]
      },
      "coerced multiple elements" => %{
        input: %{
          "@context" => %{"http://example.com/foo" => %{"@container" => "@set"}},
          "http://example.com/foo" => ["foo", "bar"]
        },
        output: [
          %{
            "http://example.com/foo" => [%{"@value" => "foo"}, %{"@value" => "bar"}]
          }
        ]
      },
      "array containing set" => %{
        input: %{
          "http://example.com/foo" => [%{"@set" => []}]
        },
        output: [
          %{
            "http://example.com/foo" => []
          }
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        assert JSON.LD.expand(data.input) == data.output
      end
    end)
  end

  describe "@direction" do
    %{
      "value with coerced null direction" => %{
        input: %{
          "@context" => %{
            "@direction" => "rtl",
            "ex" => "http://example.org/vocab#",
            "ex:ltr" => %{"@direction" => "ltr"},
            "ex:none" => %{"@direction" => nil}
          },
          "ex:rtl" => "rtl",
          "ex:ltr" => "ltr",
          "ex:none" => "no direction"
        },
        output: [
          %{
            "http://example.org/vocab#rtl" => [%{"@value" => "rtl", "@direction" => "rtl"}],
            "http://example.org/vocab#ltr" => [%{"@value" => "ltr", "@direction" => "ltr"}],
            "http://example.org/vocab#none" => [%{"@value" => "no direction"}]
          }
        ]
      },
      "default language and default direction" => %{
        input: %{
          "@context" => %{
            "@language" => "en",
            "@direction" => "rtl",
            "ex" => "http://example.org/vocab#",
            "ex:ltr" => %{"@direction" => "ltr"},
            "ex:none" => %{"@direction" => nil},
            "ex:german" => %{"@language" => "de"},
            "ex:nolang" => %{"@language" => nil},
            "ex:german_ltr" => %{"@language" => "de", "@direction" => "ltr"},
            "ex:nolang_ltr" => %{"@language" => nil, "@direction" => "ltr"},
            "ex:none_none" => %{"@language" => nil, "@direction" => nil},
            "ex:german_none" => %{"@language" => "de", "@direction" => nil}
          },
          "ex:rtl" => "rtl en",
          "ex:ltr" => "ltr en",
          "ex:none" => "no direction en",
          "ex:german" => "german rtl",
          "ex:nolang" => "no language rtl",
          "ex:german_ltr" => "german ltr",
          "ex:nolang_ltr" => "no language ltr",
          "ex:none_none" => "no language or direction",
          "ex:german_none" => "german no direction"
        },
        output: [
          %{
            "http://example.org/vocab#rtl" => [
              %{"@value" => "rtl en", "@language" => "en", "@direction" => "rtl"}
            ],
            "http://example.org/vocab#ltr" => [
              %{"@value" => "ltr en", "@language" => "en", "@direction" => "ltr"}
            ],
            "http://example.org/vocab#none" => [
              %{"@value" => "no direction en", "@language" => "en"}
            ],
            "http://example.org/vocab#german" => [
              %{"@value" => "german rtl", "@language" => "de", "@direction" => "rtl"}
            ],
            "http://example.org/vocab#nolang" => [
              %{"@value" => "no language rtl", "@direction" => "rtl"}
            ],
            "http://example.org/vocab#german_ltr" => [
              %{"@value" => "german ltr", "@language" => "de", "@direction" => "ltr"}
            ],
            "http://example.org/vocab#nolang_ltr" => [
              %{"@value" => "no language ltr", "@direction" => "ltr"}
            ],
            "http://example.org/vocab#none_none" => [%{"@value" => "no language or direction"}],
            "http://example.org/vocab#german_none" => [
              %{"@value" => "german no direction", "@language" => "de"}
            ]
          }
        ]
      },
      "Simple language map with direction" => %{
        input: %{
          "@context" => %{
            "@direction" => "ltr",
            "vocab" => "http://example.com/vocab/",
            "label" => %{
              "@id" => "vocab:label",
              "@container" => "@language"
            }
          },
          "@id" => "http://example.com/queen",
          "label" => %{
            "en" => "The Queen",
            "de" => ["Die Königin", "Ihre Majestät"]
          }
        },
        output: [
          %{
            "@id" => "http://example.com/queen",
            "http://example.com/vocab/label" => [
              %{"@value" => "Die Königin", "@language" => "de", "@direction" => "ltr"},
              %{"@value" => "Ihre Majestät", "@language" => "de", "@direction" => "ltr"},
              %{"@value" => "The Queen", "@language" => "en", "@direction" => "ltr"}
            ]
          }
        ]
      },
      "Language map with term direction" => %{
        input: %{
          "@context" => %{
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
        },
        output: [
          %{
            "@id" => "http://example.com/queen",
            "http://example.com/vocab/label" => [
              %{"@value" => "Die Königin", "@language" => "de", "@direction" => "ltr"},
              %{"@value" => "Ihre Majestät", "@language" => "de", "@direction" => "ltr"},
              %{"@value" => "The Queen", "@language" => "en", "@direction" => "ltr"}
            ]
          }
        ]
      },
      "Invalid @direction and @type combination" => %{
        input: %{
          "ex:p" => %{
            "@value" => "v",
            "@type" => "ex:t",
            "@direction" => "rtl"
          }
        },
        exception: JSON.LD.InvalidValueObjectError
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        if Map.has_key?(data, :exception) do
          assert_raise data.exception, fn ->
            JSON.LD.expand(data.input)
          end
        else
          assert JSON.LD.expand(data.input) == data.output
        end
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
            "de" => ["Die Königin", "Ihre Majestät"]
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
      "expand-0035" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example.com/vocab/",
            "@language" => "it",
            "label" => %{
              "@container" => "@language"
            }
          },
          "@id" => "http://example.com/queen",
          "label" => %{
            "en" => "The Queen",
            "de" => ["Die Königin", "Ihre Majestät"]
          },
          "http://example.com/vocab/label" => [
            "Il re",
            %{"@value" => "The king", "@language" => "en"}
          ]
        },
        output: [
          %{
            "@id" => "http://example.com/queen",
            "http://example.com/vocab/label" => [
              %{"@value" => "Die Königin", "@language" => "de"},
              %{"@value" => "Ihre Majestät", "@language" => "de"},
              %{"@value" => "The Queen", "@language" => "en"},
              %{"@value" => "Il re", "@language" => "it"},
              %{"@value" => "The king", "@language" => "en"}
            ]
          }
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        assert JSON.LD.expand(data.input) == data.output
      end
    end)
  end

  describe "@reverse" do
    %{
      "expand-0037" => %{
        input: Jason.decode!(~s({
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
        output: Jason.decode!(~s([
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
        input: Jason.decode!(~s({
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
        output: Jason.decode!(~s([
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
      }
    }
    |> Enum.each(fn {title, data} ->
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
            "de" => ["Die Königin", "Ihre Majestät"]
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
      "it expands to property value, instead of @index" => %{
        input: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/",
            "input" => %{"@container" => ["@graph", "@index"], "@index" => "prop"}
          },
          "input" => %{
            "g1" => %{"value" => "x"}
          }
        },
        output: [
          %{
            "http://example.org/input" => [
              %{
                "http://example.org/prop" => [%{"@value" => "g1"}],
                "@graph" => [
                  %{
                    "http://example.org/value" => [%{"@value" => "x"}]
                  }
                ]
              }
            ]
          }
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        assert JSON.LD.expand(data.input) == data.output
      end
    end)
  end

  describe "@container: @id" do
    %{
      "Adds @id to object not having an @id" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example/",
            "idmap" => %{"@container" => "@id"}
          },
          "idmap" => %{
            "http://example.org/foo" => %{"label" => "Object with @id <foo>"},
            "_:bar" => %{"label" => "Object with @id _:bar"}
          }
        },
        output: [
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
        ]
      },
      "Retains @id in object already having an @id" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example/",
            "idmap" => %{"@container" => "@id"}
          },
          "idmap" => %{
            "http://example.org/foo" => %{
              "@id" => "http://example.org/bar",
              "label" => "Object with @id <foo>"
            },
            "_:bar" => %{"@id" => "_:foo", "label" => "Object with @id _:bar"}
          }
        },
        output: [
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
        ]
      },
      "Does not add @id if it is @none" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example/",
            "idmap" => %{"@container" => "@id"},
            "none" => "@none"
          },
          "idmap" => %{
            "@none" => %{"label" => "Object with no @id"},
            "none" => %{"label" => "Another object with no @id"}
          }
        },
        output: [
          %{
            "http://example/idmap" => [
              %{"http://example/label" => [%{"@value" => "Object with no @id"}]},
              %{"http://example/label" => [%{"@value" => "Another object with no @id"}]}
            ]
          }
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        assert JSON.LD.expand(data.input) == data.output
      end
    end)
  end

  describe "@container: @type" do
    %{
      "Adds @type to object not having an @type" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example/",
            "typemap" => %{"@container" => "@type"}
          },
          "typemap" => %{
            "http://example.org/foo" => %{"label" => "Object with @type <foo>"},
            "_:bar" => %{"label" => "Object with @type _:bar"}
          }
        },
        output: [
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
        ]
      },
      "Prepends @type in object already having an @type" => %{
        input: %{
          "@context" => %{
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
        },
        output: [
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
        ]
      },
      "Does not add @type if it is @none" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example/",
            "typemap" => %{"@container" => "@type"},
            "none" => "@none"
          },
          "typemap" => %{
            "@none" => %{"label" => "Object with no @type"},
            "none" => %{"label" => "Another object with no @type"}
          }
        },
        output: [
          %{
            "http://example/typemap" => [
              %{"http://example/label" => [%{"@value" => "Object with no @type"}]},
              %{"http://example/label" => [%{"@value" => "Another object with no @type"}]}
            ]
          }
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        assert JSON.LD.expand(data.input) == data.output
      end
    end)
  end

  describe "@container: @graph" do
    %{
      "Creates a graph object given a value" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example.org/",
            "input" => %{"@container" => "@graph"}
          },
          "input" => %{
            "value" => "x"
          }
        },
        output: [
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
        ]
      },
      "Creates a graph object within an array given a value" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example.org/",
            "input" => %{"@container" => ["@graph", "@set"]}
          },
          "input" => %{
            "value" => "x"
          }
        },
        output: [
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
        ]
      },
      "Creates a graph object if value is a graph" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example.org/",
            "input" => %{"@container" => "@graph"}
          },
          "input" => %{
            "@graph" => %{
              "value" => "x"
            }
          }
        },
        output: [
          %{
            "http://example.org/input" => [
              %{
                "@graph" => [
                  %{
                    "@graph" => [
                      %{
                        "http://example.org/value" => [%{"@value" => "x"}]
                      }
                    ]
                  }
                ]
              }
            ]
          }
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        if Map.has_key?(data, :exception) do
          assert_raise data.exception, fn ->
            JSON.LD.expand(data.input)
          end
        else
          assert JSON.LD.expand(data.input) == data.output
        end
      end
    end)
  end

  describe "@container: @graph + @index" do
    %{
      "Creates a graph object given an indexed value" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example.org/",
            "input" => %{"@container" => ["@graph", "@index"]}
          },
          "input" => %{
            "g1" => %{"value" => "x"}
          }
        },
        output: [
          %{
            "http://example.org/input" => [
              %{
                "@index" => "g1",
                "@graph" => [
                  %{
                    "http://example.org/value" => [%{"@value" => "x"}]
                  }
                ]
              }
            ]
          }
        ]
      },
      "Creates a graph object given an indexed value with index @none" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example.org/",
            "input" => %{"@container" => ["@graph", "@index"]}
          },
          "input" => %{
            "@none" => %{"value" => "x"}
          }
        },
        output: [
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
        ]
      },
      "Does not create a new graph object if indexed value is already a graph object" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example.org/",
            "input" => %{"@container" => ["@graph", "@index"]}
          },
          "input" => %{
            "g1" => %{
              "@graph" => %{
                "value" => "x"
              }
            }
          }
        },
        output: [
          %{
            "http://example.org/input" => [
              %{
                "@index" => "g1",
                "@graph" => [
                  %{
                    "http://example.org/value" => [%{"@value" => "x"}]
                  }
                ]
              }
            ]
          }
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        if Map.has_key?(data, :exception) do
          assert_raise data.exception, fn ->
            JSON.LD.expand(data.input)
          end
        else
          assert JSON.LD.expand(data.input) == data.output
        end
      end
    end)
  end

  describe "@container: @graph + @id" do
    %{
      "Creates a graph object given an indexed value" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example.org/",
            "input" => %{"@container" => ["@graph", "@id"]}
          },
          "input" => %{
            "http://example.com/g1" => %{"value" => "x"}
          }
        },
        output: [
          %{
            "http://example.org/input" => [
              %{
                "@id" => "http://example.com/g1",
                "@graph" => [
                  %{
                    "http://example.org/value" => [%{"@value" => "x"}]
                  }
                ]
              }
            ]
          }
        ]
      },
      "Creates a graph object given an indexed value of @none" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example.org/",
            "input" => %{"@container" => ["@graph", "@id"]}
          },
          "input" => %{
            "@none" => %{"value" => "x"}
          }
        },
        output: [
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
        ]
      },
      "Does not create a new graph object if indexed value is already a graph object" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example.org/",
            "input" => %{"@container" => ["@graph", "@id"]}
          },
          "input" => %{
            "http://example.com/g1" => %{
              "@graph" => %{
                "value" => "x"
              }
            }
          }
        },
        output: [
          %{
            "http://example.org/input" => [
              %{
                "@id" => "http://example.com/g1",
                "@graph" => [
                  %{
                    "http://example.org/value" => [%{"@value" => "x"}]
                  }
                ]
              }
            ]
          }
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        if Map.has_key?(data, :exception) do
          assert_raise data.exception, fn ->
            JSON.LD.expand(data.input)
          end
        else
          assert JSON.LD.expand(data.input) == data.output
        end
      end
    end)
  end

  describe "@nest" do
    %{
      "Expands input using @nest" => %{
        input: %{
          "@context" => %{"@vocab" => "http://example.org/"},
          "p1" => "v1",
          "@nest" => %{
            "p2" => "v2"
          }
        },
        output: [
          %{
            "http://example.org/p1" => [%{"@value" => "v1"}],
            "http://example.org/p2" => [%{"@value" => "v2"}]
          }
        ]
      },
      "Expands input using aliased @nest" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example.org/",
            "nest" => "@nest"
          },
          "p1" => "v1",
          "nest" => %{
            "p2" => "v2"
          }
        },
        output: [
          %{
            "http://example.org/p1" => [%{"@value" => "v1"}],
            "http://example.org/p2" => [%{"@value" => "v2"}]
          }
        ]
      },
      "Appends nested values when property at base and nested" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example.org/",
            "nest" => "@nest"
          },
          "p1" => "v1",
          "nest" => %{
            "p2" => "v3"
          },
          "p2" => "v2"
        },
        output: [
          %{
            "http://example.org/p1" => [%{"@value" => "v1"}],
            "http://example.org/p2" => [
              %{"@value" => "v2"},
              %{"@value" => "v3"}
            ]
          }
        ]
      },
      "Nested nested containers" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example.org/"
          },
          "p1" => "v1",
          "@nest" => %{
            "p2" => "v3",
            "@nest" => %{
              "p2" => "v4"
            }
          },
          "p2" => "v2"
        },
        output: [
          %{
            "http://example.org/p1" => [%{"@value" => "v1"}],
            "http://example.org/p2" => [
              %{"@value" => "v2"},
              %{"@value" => "v3"},
              %{"@value" => "v4"}
            ]
          }
        ]
      },
      "Arrays of nested values" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example.org/",
            "nest" => "@nest"
          },
          "p1" => "v1",
          "nest" => %{
            "p2" => ["v4", "v5"]
          },
          "p2" => ["v2", "v3"]
        },
        output: [
          %{
            "http://example.org/p1" => [%{"@value" => "v1"}],
            "http://example.org/p2" => [
              %{"@value" => "v2"},
              %{"@value" => "v3"},
              %{"@value" => "v4"},
              %{"@value" => "v5"}
            ]
          }
        ]
      },
      "@nest MUST NOT have a string value" => %{
        input: %{
          "@context" => %{"@vocab" => "http://example.org/"},
          "@nest" => "This should generate an error"
        },
        exception: JSON.LD.InvalidNestValueError
      },
      "Nested @container: @list" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example.org/",
            "list" => %{"@container" => "@list", "@nest" => "nestedlist"},
            "nestedlist" => "@nest"
          },
          "nestedlist" => %{
            "list" => ["a", "b"]
          }
        },
        output: [
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
        ]
      },
      "Applies property scoped contexts which are aliases of @nest" => %{
        input: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/",
            "nest" => %{
              "@id" => "@nest",
              "@context" => %{
                "@vocab" => "http://example.org/nest/"
              }
            }
          },
          "nest" => %{
            "property" => "should be in /nest"
          }
        },
        output: [
          %{
            "http://example.org/nest/property" => [%{"@value" => "should be in /nest"}]
          }
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        if Map.has_key?(data, :exception) do
          assert_raise data.exception, fn ->
            JSON.LD.expand(data.input)
          end
        else
          assert JSON.LD.expand(data.input) == data.output
        end
      end
    end)
  end

  describe "@included" do
    %{
      "Basic Included array" => %{
        input: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/"
          },
          "prop" => "value",
          "@included" => [
            %{
              "prop" => "value2"
            }
          ]
        },
        output: [
          %{
            "http://example.org/prop" => [%{"@value" => "value"}],
            "@included" => [
              %{
                "http://example.org/prop" => [%{"@value" => "value2"}]
              }
            ]
          }
        ]
      },
      "Basic Included object" => %{
        input: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/"
          },
          "prop" => "value",
          "@included" => %{
            "prop" => "value2"
          }
        },
        output: [
          %{
            "http://example.org/prop" => [%{"@value" => "value"}],
            "@included" => [
              %{
                "http://example.org/prop" => [%{"@value" => "value2"}]
              }
            ]
          }
        ]
      },
      "Multiple properties mapping to @included are folded together" => %{
        input: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/",
            "included1" => "@included",
            "included2" => "@included"
          },
          "included1" => %{"prop" => "value1"},
          "included2" => %{"prop" => "value2"}
        },
        output: [
          %{
            "@included" => [
              %{"http://example.org/prop" => [%{"@value" => "value2"}]},
              %{"http://example.org/prop" => [%{"@value" => "value1"}]}
            ]
          }
        ]
      },
      "Included containing @included" => %{
        input: %{
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
        },
        output: [
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
        ]
      },
      "Property value with @included" => %{
        input: %{
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
        },
        output: [
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
        ]
      },
      "Error if @included value is a string" => %{
        input: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/"
          },
          "@included" => "string"
        },
        exception: JSON.LD.InvalidIncludedValueError
      },
      "Error if @included value is a value object" => %{
        input: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/"
          },
          "@included" => %{"@value" => "value"}
        },
        exception: JSON.LD.InvalidIncludedValueError
      },
      "Error if @included value is a list object" => %{
        input: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.org/"
          },
          "@included" => %{"@list" => ["value"]}
        },
        exception: JSON.LD.InvalidIncludedValueError
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        if Map.has_key?(data, :exception) do
          assert_raise data.exception, fn ->
            JSON.LD.expand(data.input)
          end
        else
          assert JSON.LD.expand(data.input) == data.output
        end
      end
    end)
  end

  describe "scoped context" do
    %{
      "adding new term" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example/",
            "foo" => %{"@context" => %{"bar" => "http://example.org/bar"}}
          },
          "foo" => %{
            "bar" => "baz"
          }
        },
        output: [
          %{
            "http://example/foo" => [%{"http://example.org/bar" => [%{"@value" => "baz"}]}]
          }
        ]
      },
      "overriding a term" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example/",
            "foo" => %{"@context" => %{"bar" => %{"@type" => "@id"}}},
            "bar" => %{"@type" => "http://www.w3.org/2001/XMLSchema#string"}
          },
          "foo" => %{
            "bar" => "http://example/baz"
          }
        },
        output: [
          %{
            "http://example/foo" => [
              %{"http://example/bar" => [%{"@id" => "http://example/baz"}]}
            ]
          }
        ]
      },
      "property and value with different terms mapping to the same expanded property" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example/",
            "foo" => %{"@context" => %{"Bar" => %{"@id" => "bar"}}}
          },
          "foo" => %{
            "Bar" => "baz"
          }
        },
        output: [
          %{
            "http://example/foo" => [
              %{
                "http://example/bar" => [
                  %{"@value" => "baz"}
                ]
              }
            ]
          }
        ]
      },
      "deep @context affects nested nodes" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example/",
            "foo" => %{"@context" => %{"baz" => %{"@type" => "@vocab"}}}
          },
          "foo" => %{
            "bar" => %{
              "baz" => "buzz"
            }
          }
        },
        output: [
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
        ]
      },
      "scoped context layers on intermediate contexts" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example/",
            "b" => %{"@context" => %{"c" => "http://example.org/c"}}
          },
          "a" => %{
            "@context" => %{"@vocab" => "http://example.com/"},
            "b" => %{
              "a" => "A in example.com",
              "c" => "C in example.org"
            },
            "c" => "C in example.com"
          },
          "c" => "C in example"
        },
        output: [
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
        ]
      },
      "Scoped on id map" => %{
        input: %{
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
        },
        output: [
          %{
            "@id" => "http://example.com/",
            "@type" => ["http://schema.org/Blog"],
            "http://schema.org/name" => [%{"@value" => "World Financial News"}],
            "http://schema.org/blogPost" => [
              %{
                "@id" => "http://example.com/posts/1/de",
                "http://schema.org/articleBody" => [
                  %{
                    "@value" =>
                      "Die Werte an Warenbörsen stiegen im Sog eines starken Handels von Rohöl..."
                  }
                ],
                "http://schema.org/wordCount" => [%{"@value" => 1204}]
              },
              %{
                "@id" => "http://example.com/posts/1/en",
                "http://schema.org/articleBody" => [
                  %{
                    "@value" =>
                      "World commodities were up today with heavy trading of crude oil..."
                  }
                ],
                "http://schema.org/wordCount" => [%{"@value" => 1539}]
              }
            ]
          }
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
      if title == "Scoped on id map" do
        @tag skip:
               "TODO: Should we support this? The algorithm spec doesn't contain the necessary context update and the W3C test don't cover this scenario ..."
      end

      @tag data: data
      test title, %{data: data} do
        if Map.has_key?(data, :exception) do
          assert_raise data.exception, fn ->
            JSON.LD.expand(data.input)
          end
        else
          assert JSON.LD.expand(data.input) == data.output
        end
      end
    end)
  end

  describe "scoped context on @type" do
    %{
      "adding new term" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example/",
            "Foo" => %{"@context" => %{"bar" => "http://example.org/bar"}}
          },
          "a" => %{"@type" => "Foo", "bar" => "baz"}
        },
        output: [
          %{
            "http://example/a" => [
              %{
                "@type" => ["http://example/Foo"],
                "http://example.org/bar" => [%{"@value" => "baz"}]
              }
            ]
          }
        ]
      },
      "overriding a term" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example/",
            "Foo" => %{"@context" => %{"bar" => %{"@type" => "@id"}}},
            "bar" => %{"@type" => "http://www.w3.org/2001/XMLSchema#string"}
          },
          "a" => %{"@type" => "Foo", "bar" => "http://example/baz"}
        },
        output: [
          %{
            "http://example/a" => [
              %{
                "@type" => ["http://example/Foo"],
                "http://example/bar" => [%{"@id" => "http://example/baz"}]
              }
            ]
          }
        ]
      },
      "alias of @type" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example/",
            "type" => "@type",
            "Foo" => %{"@context" => %{"bar" => "http://example.org/bar"}}
          },
          "a" => %{"type" => "Foo", "bar" => "baz"}
        },
        output: [
          %{
            "http://example/a" => [
              %{
                "@type" => ["http://example/Foo"],
                "http://example.org/bar" => [%{"@value" => "baz"}]
              }
            ]
          }
        ]
      },
      "deep @context does not affect nested nodes" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example/",
            "Foo" => %{"@context" => %{"baz" => %{"@type" => "@vocab"}}}
          },
          "@type" => "Foo",
          "bar" => %{"baz" => "buzz"}
        },
        output: [
          %{
            "@type" => ["http://example/Foo"],
            "http://example/bar" => [
              %{
                "http://example/baz" => [%{"@value" => "buzz"}]
              }
            ]
          }
        ]
      },
      "scoped context layers on intermediate contexts" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example/",
            "B" => %{"@context" => %{"c" => "http://example.org/c"}}
          },
          "a" => %{
            "@context" => %{"@vocab" => "http://example.com/"},
            "@type" => "B",
            "a" => "A in example.com",
            "c" => "C in example.org"
          },
          "c" => "C in example"
        },
        output: [
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
        ]
      },
      "with @container: @type" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example/",
            "typemap" => %{"@container" => "@type"},
            "Type" => %{"@context" => %{"a" => "http://example.org/a"}}
          },
          "typemap" => %{
            "Type" => %{"a" => "Object with @type <Type>"}
          }
        },
        output: [
          %{
            "http://example/typemap" => [
              %{
                "http://example.org/a" => [%{"@value" => "Object with @type <Type>"}],
                "@type" => ["http://example/Type"]
              }
            ]
          }
        ]
      },
      "orders lexicographically" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example/",
            "t1" => %{"@context" => %{"foo" => %{"@id" => "http://example.com/foo"}}},
            "t2" => %{
              "@context" => %{"foo" => %{"@id" => "http://example.org/foo", "@type" => "@id"}}
            }
          },
          "@type" => ["t2", "t1"],
          "foo" => "urn:bar"
        },
        output: [
          %{
            "@type" => ["http://example/t2", "http://example/t1"],
            "http://example.org/foo" => [
              %{"@id" => "urn:bar"}
            ]
          }
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        if Map.has_key?(data, :exception) do
          assert_raise data.exception, fn ->
            JSON.LD.expand(data.input)
          end
        else
          assert JSON.LD.expand(data.input) == data.output
        end
      end
    end)
  end

  describe "@version" do
    %{
      "Accepts version 1.1" => %{
        input: %{
          "@context" => %{
            "@version" => 1.1,
            "foo" => "http://example.org/foo"
          },
          "foo" => "bar"
        },
        output: [
          %{
            "http://example.org/foo" => [%{"@value" => "bar"}]
          }
        ]
      },
      "Rejects non-number version" => %{
        input: %{
          "@context" => %{
            "@version" => "1.1",
            "foo" => "http://example.org/foo"
          },
          "foo" => "bar"
        },
        exception: JSON.LD.InvalidVersionValueError
      },
      "Reject version 1.0" => %{
        input: %{
          "@context" => %{
            "@version" => 1.0,
            "foo" => "http://example.org/foo"
          },
          "foo" => "bar"
        },
        exception: JSON.LD.InvalidVersionValueError
      },
      "Rejects unsupported version" => %{
        input: %{
          "@context" => %{
            "@version" => 2.0,
            "foo" => "http://example.org/foo"
          },
          "foo" => "bar"
        },
        exception: JSON.LD.InvalidVersionValueError
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        if Map.has_key?(data, :exception) do
          assert_raise data.exception, fn -> JSON.LD.expand(data.input) end
        else
          assert JSON.LD.expand(data.input) == data.output
        end
      end
    end)
  end

  describe "errors" do
    %{
      "non-null @value and null @type" => %{
        input: %{"http://example.com/foo" => %{"@value" => "foo", "@type" => nil}},
        exception: JSON.LD.InvalidTypeValueError
      },
      "non-null @value and blank node @type" => %{
        input: %{"http://example.com/foo" => %{"@value" => "foo", "@type" => "_:foo"}},
        exception: JSON.LD.InvalidTypedValueError
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
      "@reverse object with an @id property" => %{
        input: Jason.decode!(~s({
          "@id": "http://example/foo",
          "@reverse": {
            "@id": "http://example/bar"
          }
        })),
        exception: JSON.LD.InvalidReversePropertyMapError
      },
      "colliding keywords" => %{
        input: Jason.decode!(~s({
          "@context": {
            "id": "@id",
            "ID": "@id"
          },
          "id": "http://example/foo",
          "ID": "http://example/bar"
        })),
        exception: JSON.LD.CollidingKeywordsError
      },
      "Error if @index is a keyword" => %{
        input: %{
          "@context" => %{
            "@version" => 1.1,
            "@vocab" => "http://example.com/",
            "container" => %{
              "@container" => "@index",
              "@index" => "@index"
            }
          }
        },
        exception: JSON.LD.InvalidTermDefinitionError
      },
      "Error if processing mode 1.0 with 1.1 features" => %{
        input: %{
          "@context" => %{
            "@vocab" => "http://example/",
            "Foo" => %{"@context" => %{"bar" => "http://example.org/bar"}}
          },
          "a" => %{"@type" => "Foo", "bar" => "baz"}
        },
        processingMode: "json-ld-1.0",
        exception: JSON.LD.InvalidTermDefinitionError
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        assert_raise data.exception, fn ->
          JSON.LD.expand(data.input, processing_mode: data[:processingMode] || [])
        end
      end
    end)
  end

  describe "expand_value" do
    setup do
      context =
        JSON.LD.context(%{
          "dc" => "http://purl.org/dc/terms/",
          "ex" => "http://example.org/",
          "foaf" => "http://xmlns.com/foaf/0.1/",
          "xsd" => "http://www.w3.org/2001/XMLSchema#",
          "foaf:age" => %{"@type" => "xsd:integer"},
          "foaf:knows" => %{"@type" => "@id"},
          "dc:created" => %{"@type" => "xsd:date"},
          "ex:integer" => %{"@type" => "xsd:integer"},
          "ex:double" => %{"@type" => "xsd:double"},
          "ex:boolean" => %{"@type" => "xsd:boolean"}
        })

      language_context = Map.put(context, "@language", "en")
      %{example_context: context, language_context: language_context}
    end

    %{
      "absolute IRI" => ["foaf:knows", "http://example.com/", %{"@id" => "http://example.com/"}],
      "term" => ["foaf:knows", "ex", %{"@id" => "ex"}],
      "prefix:suffix" => ["foaf:knows", "ex:suffix", %{"@id" => "http://example.org/suffix"}],
      "no IRI" => ["foo", "http://example.com/", %{"@value" => "http://example.com/"}],
      "no term" => ["foo", "ex", %{"@value" => "ex"}],
      "no prefix" => ["foo", "ex:suffix", %{"@value" => "ex:suffix"}],
      "integer" => ["foaf:age", "54", %{"@value" => "54", "@type" => XSD.integer() |> to_string}],
      "date " => [
        "dc:created",
        "2011-12-27Z",
        %{"@value" => "2011-12-27Z", "@type" => XSD.date() |> to_string}
      ],
      "native boolean" => ["foo", true, %{"@value" => true}],
      "native integer" => ["foo", 1, %{"@value" => 1}],
      "native double" => ["foo", 1.1e1, %{"@value" => 1.1e1}]
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: [key, compacted, expanded], example_context: context} do
        assert expand_value(context, key, compacted) == expanded
      end
    end)

    %{
      "boolean-boolean" => [
        "ex:boolean",
        true,
        %{"@value" => true, "@type" => XSD.boolean() |> to_string}
      ],
      "boolean-integer" => [
        "ex:integer",
        true,
        %{"@value" => true, "@type" => XSD.integer() |> to_string}
      ],
      "boolean-double" => [
        "ex:double",
        true,
        %{"@value" => true, "@type" => XSD.double() |> to_string}
      ],
      "double-boolean" => [
        "ex:boolean",
        1.1,
        %{"@value" => 1.1, "@type" => XSD.boolean() |> to_string}
      ],
      "double-double" => [
        "ex:double",
        1.1,
        %{"@value" => 1.1, "@type" => XSD.double() |> to_string}
      ],
      "double-integer" => [
        "foaf:age",
        1.1,
        %{"@value" => 1.1, "@type" => XSD.integer() |> to_string}
      ],
      "integer-boolean" => [
        "ex:boolean",
        1,
        %{"@value" => 1, "@type" => XSD.boolean() |> to_string}
      ],
      "integer-double" => ["ex:double", 1, %{"@value" => 1, "@type" => XSD.double() |> to_string}],
      "integer-integer" => [
        "foaf:age",
        1,
        %{"@value" => 1, "@type" => XSD.integer() |> to_string}
      ],
      "string-boolean" => [
        "ex:boolean",
        "foo",
        %{"@value" => "foo", "@type" => XSD.boolean() |> to_string}
      ],
      "string-double" => [
        "ex:double",
        "foo",
        %{"@value" => "foo", "@type" => XSD.double() |> to_string}
      ],
      "string-integer" => [
        "foaf:age",
        "foo",
        %{"@value" => "foo", "@type" => XSD.integer() |> to_string}
      ]
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test "coercion #{title}", %{data: [key, compacted, expanded], example_context: context} do
        assert expand_value(context, key, compacted) == expanded
      end
    end)
  end
end
