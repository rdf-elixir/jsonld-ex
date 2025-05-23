defmodule JSON.LD.EncoderTest do
  use JSON.LD.Case, async: false

  doctest JSON.LD.Encoder

  def gets_serialized_to(input, output, opts \\ []) do
    data_structs = Keyword.get(opts, :data_structs, [Dataset, Graph])

    Enum.each(data_structs, fn
      RDF.Description ->
        subject =
          case input do
            {subject, _, _} -> subject
            [{subject, _, _} | _] -> subject
          end

        assert JSON.LD.Encoder.from_rdf!(RDF.Description.new(subject, init: input), opts) ==
                 output

      data_struct ->
        assert JSON.LD.Encoder.from_rdf!(data_struct.new(input), opts) == output
    end)
  end

  test "pretty printing" do
    dataset = Dataset.new({~I<http://a/b>, ~I<http://a/c>, ~I<http://a/d>})

    assert JSON.LD.Encoder.encode!(dataset) ==
             "[{\"@id\":\"http://a/b\",\"http://a/c\":[{\"@id\":\"http://a/d\"}]}]"

    assert JSON.LD.Encoder.encode!(dataset, pretty: true) ==
             """
             [
               {
                 "@id": "http://a/b",
                 "http://a/c": [
                   {
                     "@id": "http://a/d"
                   }
                 ]
               }
             ]
             """
             |> String.trim()
  end

  test "an empty RDF.Dataset is serialized to an JSON array string" do
    assert JSON.LD.Encoder.encode!(Dataset.new()) == "[]"
  end

  describe "simple tests" do
    test "One subject IRI object" do
      {~I<http://a/b>, ~I<http://a/c>, ~I<http://a/d>}
      |> gets_serialized_to(
        [
          %{
            "@id" => "http://a/b",
            "http://a/c" => [%{"@id" => "http://a/d"}]
          }
        ],
        data_structs: [Dataset, Graph, Description]
      )
    end

    test "should generate object list" do
      [{EX.b(), EX.c(), EX.d()}, {EX.b(), EX.c(), EX.e()}]
      |> gets_serialized_to(
        [
          %{
            "@id" => "http://example.com/b",
            "http://example.com/c" => [
              %{"@id" => "http://example.com/d"},
              %{"@id" => "http://example.com/e"}
            ]
          }
        ],
        data_structs: [Dataset, Graph, Description]
      )
    end

    test "should generate property list" do
      [{EX.b(), EX.c(), EX.d()}, {EX.b(), EX.e(), EX.f()}]
      |> gets_serialized_to(
        [
          %{
            "@id" => "http://example.com/b",
            "http://example.com/c" => [%{"@id" => "http://example.com/d"}],
            "http://example.com/e" => [%{"@id" => "http://example.com/f"}]
          }
        ],
        data_structs: [Dataset, Graph, Description]
      )
    end

    test "serializes multiple subjects" do
      [
        {~I<http://test-cases/0001>, NS.RDF.type(),
         ~I<http://www.w3.org/2006/03/test-description#TestCase>},
        {~I<http://test-cases/0002>, NS.RDF.type(),
         ~I<http://www.w3.org/2006/03/test-description#TestCase>}
      ]
      |> gets_serialized_to([
        %{
          "@id" => "http://test-cases/0001",
          "@type" => ["http://www.w3.org/2006/03/test-description#TestCase"]
        },
        %{
          "@id" => "http://test-cases/0002",
          "@type" => ["http://www.w3.org/2006/03/test-description#TestCase"]
        }
      ])
    end
  end

  describe "literal coercion" do
    test "typed literal" do
      {EX.a(), EX.b(), RDF.literal("foo", datatype: EX.d())}
      |> gets_serialized_to(
        [
          %{
            "@id" => "http://example.com/a",
            "http://example.com/b" => [%{"@value" => "foo", "@type" => "http://example.com/d"}]
          }
        ],
        data_structs: [Dataset, Graph, Description]
      )
    end

    test "integer" do
      {EX.a(), EX.b(), RDF.literal(1)}
      |> gets_serialized_to(
        [
          %{
            "@id" => "http://example.com/a",
            "http://example.com/b" => [%{"@value" => 1}]
          }
        ],
        use_native_types: true
      )
    end

    test "integer (non-native)" do
      {EX.a(), EX.b(), RDF.literal(1)}
      |> gets_serialized_to(
        [
          %{
            "@id" => "http://example.com/a",
            "http://example.com/b" => [
              %{"@value" => "1", "@type" => "http://www.w3.org/2001/XMLSchema#integer"}
            ]
          }
        ],
        use_native_types: false
      )
    end

    test "boolean" do
      {EX.a(), EX.b(), RDF.literal(true)}
      |> gets_serialized_to(
        [
          %{
            "@id" => "http://example.com/a",
            "http://example.com/b" => [%{"@value" => true}]
          }
        ],
        use_native_types: true
      )
    end

    test "boolean (non-native)" do
      {EX.a(), EX.b(), RDF.literal(true)}
      |> gets_serialized_to(
        [
          %{
            "@id" => "http://example.com/a",
            "http://example.com/b" => [
              %{"@value" => "true", "@type" => "http://www.w3.org/2001/XMLSchema#boolean"}
            ]
          }
        ],
        use_native_types: false
      )
    end

    test "decimal" do
      {EX.a(), EX.b(), RDF.XSD.decimal(1.0)}
      |> gets_serialized_to(
        [
          %{
            "@id" => "http://example.com/a",
            "http://example.com/b" => [
              %{"@value" => "1.0", "@type" => "http://www.w3.org/2001/XMLSchema#decimal"}
            ]
          }
        ],
        use_native_types: true
      )
    end

    test "decimal (non-native)" do
      {EX.a(), EX.b(), RDF.XSD.decimal(1.0)}
      |> gets_serialized_to(
        [
          %{
            "@id" => "http://example.com/a",
            "http://example.com/b" => [
              %{"@value" => "1.0", "@type" => "http://www.w3.org/2001/XMLSchema#decimal"}
            ]
          }
        ],
        use_native_types: false
      )
    end

    test "double" do
      {EX.a(), EX.b(), RDF.literal(1.0e0)}
      |> gets_serialized_to(
        [
          %{
            "@id" => "http://example.com/a",
            "http://example.com/b" => [%{"@value" => 1.0e0}]
          }
        ],
        use_native_types: true
      )
    end

    test "double (non-native)" do
      {EX.a(), EX.b(), RDF.literal(1.0e0)}
      |> gets_serialized_to(
        [
          %{
            "@id" => "http://example.com/a",
            "http://example.com/b" => [
              %{"@value" => "1.0E0", "@type" => "http://www.w3.org/2001/XMLSchema#double"}
            ]
          }
        ],
        use_native_types: false
      )
    end
  end

  describe "rdf:JSON literals" do
    test "with @type: @json for boolean true" do
      {EX.id(), EX.bool(), RDF.literal("true", datatype: NS.RDF.JSON)}
      |> gets_serialized_to([
        %{
          "@id" => "http://example.com/id",
          "http://example.com/bool" => [%{"@value" => true, "@type" => "@json"}]
        }
      ])
    end

    test "with @type: @json for boolean false" do
      {EX.id(), EX.bool(), RDF.literal("false", datatype: NS.RDF.JSON)}
      |> gets_serialized_to([
        %{
          "@id" => "http://example.com/id",
          "http://example.com/bool" => [%{"@value" => false, "@type" => "@json"}]
        }
      ])
    end

    test "with @type: @json for double" do
      {EX.id(), EX.double(), RDF.literal("1.23E0", datatype: NS.RDF.JSON)}
      |> gets_serialized_to([
        %{
          "@id" => "http://example.com/id",
          "http://example.com/double" => [%{"@value" => 1.23e0, "@type" => "@json"}]
        }
      ])
    end

    test "with @type: @json for integer" do
      {EX.id(), EX.integer(), RDF.literal("123", datatype: NS.RDF.JSON)}
      |> gets_serialized_to([
        %{
          "@id" => "http://example.com/id",
          "http://example.com/integer" => [%{"@value" => 123, "@type" => "@json"}]
        }
      ])
    end

    test "with @type: @json for string" do
      {EX.id(), EX.string(), RDF.literal("\"string\"", datatype: NS.RDF.JSON)}
      |> gets_serialized_to([
        %{
          "@id" => "http://example.com/id",
          "http://example.com/string" => [%{"@value" => "string", "@type" => "@json"}]
        }
      ])
    end

    test "with @type: @json for null" do
      {EX.id(), EX.null(), RDF.literal("null", datatype: NS.RDF.JSON)}
      |> gets_serialized_to([
        %{
          "@id" => "http://example.com/id",
          "http://example.com/null" => [%{"@value" => nil, "@type" => "@json"}]
        }
      ])
    end

    test "with @type: @json for object" do
      {EX.id(), EX.object(), RDF.literal("{\"foo\":\"bar\"}", datatype: NS.RDF.JSON)}
      |> gets_serialized_to([
        %{
          "@id" => "http://example.com/id",
          "http://example.com/object" => [%{"@value" => %{"foo" => "bar"}, "@type" => "@json"}]
        }
      ])
    end

    test "with @type: @json for array" do
      {EX.id(), EX.array(), RDF.literal("[{\"foo\":\"bar\"}]", datatype: NS.RDF.JSON)}
      |> gets_serialized_to([
        %{
          "@id" => "http://example.com/id",
          "http://example.com/array" => [%{"@value" => [%{"foo" => "bar"}], "@type" => "@json"}]
        }
      ])
    end
  end

  describe "datatyped (non-native) literals" do
    %{
      integer: 1,
      unsignedInt: 1,
      nonNegativeInteger: 1,
      float: "1.0E0",
      nonPositiveInteger: -1,
      negativeInteger: -1
    }
    |> Enum.each(fn {type, _} = data ->
      @tag data: data
      test "#{type}", %{data: {type, value}} do
        {EX.a(), EX.b(), RDF.literal(value, datatype: apply(NS.XSD, type, []))}
        |> gets_serialized_to(
          [
            %{
              "@id" => "http://example.com/a",
              "http://example.com/b" => [
                %{"@value" => "#{value}", "@type" => "http://www.w3.org/2001/XMLSchema##{type}"}
              ]
            }
          ],
          use_native_types: false
        )
      end
    end)

    test "when useNativeTypes" do
      {EX.a(), EX.b(), RDF.literal("foo", datatype: EX.customType())}
      |> gets_serialized_to(
        [
          %{
            "@id" => "http://example.com/a",
            "http://example.com/b" => [
              %{"@value" => "foo", "@type" => to_string(EX.customType())}
            ]
          }
        ],
        use_native_types: true
      )
    end
  end

  test "encodes language literal" do
    {EX.a(), EX.b(), RDF.literal("foo", language: "en-us")}
    |> gets_serialized_to([
      %{
        "@id" => "http://example.com/a",
        "http://example.com/b" => [%{"@value" => "foo", "@language" => "en-us"}]
      }
    ])
  end

  describe "@direction (with rdfDirection: i18n-datatype)" do
    test "no language rtl datatype" do
      {EX.a(), EX.label(),
       RDF.literal("no language", datatype: ~I<https://www.w3.org/ns/i18n#_rtl>)}
      |> gets_serialized_to(
        [
          %{
            "@id" => "http://example.com/a",
            "http://example.com/label" => [
              %{"@value" => "no language", "@direction" => "rtl"}
            ]
          }
        ],
        rdf_direction: "i18n-datatype"
      )
    end

    test "with language rtl datatype" do
      {EX.a(), EX.label(),
       RDF.literal("en-US", datatype: ~I<https://www.w3.org/ns/i18n#en-US_rtl>)}
      |> gets_serialized_to(
        [
          %{
            "@id" => "http://example.com/a",
            "http://example.com/label" => [
              %{"@value" => "en-US", "@language" => "en-US", "@direction" => "rtl"}
            ]
          }
        ],
        rdf_direction: "i18n-datatype"
      )
    end
  end

  describe "@direction (with rdfDirection: compound-literal)" do
    test "no language rtl compound-literal" do
      [
        {EX.a(), EX.label(), RDF.bnode(:cl1)},
        {RDF.bnode(:cl1), NS.RDF.value(), RDF.literal("no language")},
        {RDF.bnode(:cl1), RDF.iri(RDF.__base_iri__() <> "direction"), RDF.literal("rtl")}
      ]
      |> gets_serialized_to(
        [
          %{
            "@id" => "http://example.com/a",
            "http://example.com/label" => [
              %{"@value" => "no language", "@direction" => "rtl"}
            ]
          }
        ],
        rdf_direction: "compound-literal"
      )
    end

    test "with language rtl compound-literal" do
      [
        {EX.a(), EX.label(), RDF.bnode(:cl1)},
        {RDF.bnode(:cl1), NS.RDF.value(), RDF.literal("en-US")},
        {RDF.bnode(:cl1), RDF.iri(RDF.__base_iri__() <> "language"), RDF.literal("en-US")},
        {RDF.bnode(:cl1), RDF.iri(RDF.__base_iri__() <> "direction"), RDF.literal("rtl")}
      ]
      |> gets_serialized_to(
        [
          %{
            "@id" => "http://example.com/a",
            "http://example.com/label" => [
              %{"@value" => "en-US", "@language" => "en-US", "@direction" => "rtl"}
            ]
          }
        ],
        rdf_direction: "compound-literal"
      )
    end
  end

  describe "blank nodes" do
    test "should generate blank nodes" do
      {RDF.bnode(:a), EX.a(), EX.b()}
      |> gets_serialized_to(
        [
          %{
            "@id" => "_:a",
            "http://example.com/a" => [%{"@id" => "http://example.com/b"}]
          }
        ],
        data_structs: [Dataset, Graph, Description]
      )
    end

    test "should generate blank nodes as object" do
      [
        {EX.a(), EX.b(), RDF.bnode(:a)},
        {RDF.bnode(:a), EX.c(), EX.d()}
      ]
      |> gets_serialized_to([
        %{
          "@id" => "_:a",
          "http://example.com/c" => [%{"@id" => "http://example.com/d"}]
        },
        %{
          "@id" => "http://example.com/a",
          "http://example.com/b" => [%{"@id" => "_:a"}]
        }
      ])
    end
  end

  describe "lists" do
    %{
      "literal list" => {
        [
          {EX.a(), EX.b(), RDF.bnode(:e1)},
          {RDF.bnode(:e1), NS.RDF.first(), ~L"apple"},
          {RDF.bnode(:e1), NS.RDF.rest(), RDF.bnode(:e2)},
          {RDF.bnode(:e2), NS.RDF.first(), ~L"banana"},
          {RDF.bnode(:e2), NS.RDF.rest(), NS.RDF.nil()}
        ],
        [
          %{
            "@id" => "http://example.com/a",
            "http://example.com/b" => [
              %{
                "@list" => [
                  %{"@value" => "apple"},
                  %{"@value" => "banana"}
                ]
              }
            ]
          }
        ]
      },
      "iri list" => {
        [
          {EX.a(), EX.b(), RDF.bnode(:list)},
          {RDF.bnode(:list), NS.RDF.first(), EX.c()},
          {RDF.bnode(:list), NS.RDF.rest(), NS.RDF.nil()}
        ],
        [
          %{
            "@id" => "http://example.com/a",
            "http://example.com/b" => [
              %{
                "@list" => [
                  %{"@id" => "http://example.com/c"}
                ]
              }
            ]
          }
        ]
      },
      "empty list" => {
        [
          {EX.a(), EX.b(), NS.RDF.nil()}
        ],
        [
          %{
            "@id" => "http://example.com/a",
            "http://example.com/b" => [%{"@list" => []}]
          }
        ]
      },
      "single element list" => {
        [
          {EX.a(), EX.b(), RDF.bnode(:list)},
          {RDF.bnode(:list), NS.RDF.first(), ~L"apple"},
          {RDF.bnode(:list), NS.RDF.rest(), NS.RDF.nil()}
        ],
        [
          %{
            "@id" => "http://example.com/a",
            "http://example.com/b" => [%{"@list" => [%{"@value" => "apple"}]}]
          }
        ]
      },
      "single element list without @type" => {
        [
          {EX.a(), EX.b(), RDF.bnode(:list)},
          {RDF.bnode(:list), NS.RDF.first(), RDF.bnode(:a)},
          {RDF.bnode(:list), NS.RDF.rest(), NS.RDF.nil()},
          {RDF.bnode(:a), EX.b(), ~L"foo"}
        ],
        [
          %{
            "@id" => "_:a",
            "http://example.com/b" => [%{"@value" => "foo"}]
          },
          %{
            "@id" => "http://example.com/a",
            "http://example.com/b" => [%{"@list" => [%{"@id" => "_:a"}]}]
          }
        ]
      },
      "multiple graphs with shared BNode" => {
        [
          {EX.z(), EX.q(), RDF.bnode(:z0), EX.G},
          {RDF.bnode(:z0), NS.RDF.first(), ~L"cell-A", EX.G},
          {RDF.bnode(:z0), NS.RDF.rest(), RDF.bnode(:z1), EX.G},
          {RDF.bnode(:z1), NS.RDF.first(), ~L"cell-B", EX.G},
          {RDF.bnode(:z1), NS.RDF.rest(), NS.RDF.nil(), EX.G},
          {EX.x(), EX.p(), RDF.bnode(:z1), EX.G1}
        ],
        [
          %{
            "@id" => "http://example.com/G",
            "@graph" => [
              %{
                "@id" => "_:z0",
                "http://www.w3.org/1999/02/22-rdf-syntax-ns#first" => [%{"@value" => "cell-A"}],
                "http://www.w3.org/1999/02/22-rdf-syntax-ns#rest" => [%{"@id" => "_:z1"}]
              },
              %{
                "@id" => "_:z1",
                "http://www.w3.org/1999/02/22-rdf-syntax-ns#first" => [%{"@value" => "cell-B"}],
                "http://www.w3.org/1999/02/22-rdf-syntax-ns#rest" => [%{"@list" => []}]
              },
              %{
                "@id" => "http://example.com/z",
                "http://example.com/q" => [%{"@id" => "_:z0"}]
              }
            ]
          },
          %{
            "@id" => "http://example.com/G1",
            "@graph" => [
              %{
                "@id" => "http://example.com/x",
                "http://example.com/p" => [%{"@id" => "_:z1"}]
              }
            ]
          }
        ]
      },
      "@list containing empty @list" => {
        [
          {EX.a(), EX.property(), RDF.bnode(:l1)},
          {RDF.bnode(:l1), NS.RDF.first(), RDF.bnode(:l2)},
          {RDF.bnode(:l1), NS.RDF.rest(), NS.RDF.nil()},
          {RDF.bnode(:l2), NS.RDF.first(), NS.RDF.nil()},
          {RDF.bnode(:l2), NS.RDF.rest(), NS.RDF.nil()}
        ],
        [
          %{
            "@id" => "http://example.com/a",
            "http://example.com/property" => [%{"@list" => [%{"@list" => [%{"@list" => []}]}]}]
          }
        ]
      },
      "@list containing multiple lists" => {
        [
          {EX.a(), EX.property(), RDF.bnode(:l1)},
          {RDF.bnode(:l1), NS.RDF.first(), RDF.bnode(:l2)},
          {RDF.bnode(:l1), NS.RDF.rest(), RDF.bnode(:l3)},
          {RDF.bnode(:l2), NS.RDF.first(), ~L"a"},
          {RDF.bnode(:l2), NS.RDF.rest(), NS.RDF.nil()},
          {RDF.bnode(:l3), NS.RDF.first(), RDF.bnode(:l4)},
          {RDF.bnode(:l3), NS.RDF.rest(), NS.RDF.nil()},
          {RDF.bnode(:l4), NS.RDF.first(), ~L"b"},
          {RDF.bnode(:l4), NS.RDF.rest(), NS.RDF.nil()}
        ],
        [
          %{
            "@id" => "http://example.com/a",
            "http://example.com/property" => [
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
      "complex nested lists" => {
        [
          {EX.url(), EX.property(), RDF.bnode(:outerlist)},
          {RDF.bnode(:outerlist), NS.RDF.first(), RDF.bnode(:lista)},
          {RDF.bnode(:outerlist), NS.RDF.rest(), RDF.bnode(:b0)},
          {RDF.bnode(:lista), NS.RDF.first(), ~L"a1"},
          {RDF.bnode(:lista), NS.RDF.rest(), RDF.bnode(:a2)},
          {RDF.bnode(:a2), NS.RDF.first(), ~L"a2"},
          {RDF.bnode(:a2), NS.RDF.rest(), RDF.bnode(:a3)},
          {RDF.bnode(:a3), NS.RDF.first(), ~L"a3"},
          {RDF.bnode(:a3), NS.RDF.rest(), NS.RDF.nil()},
          {RDF.bnode(:c0), NS.RDF.first(), RDF.bnode(:c1)},
          {RDF.bnode(:c0), NS.RDF.rest(), NS.RDF.nil()},
          {RDF.bnode(:c1), NS.RDF.first(), ~L"c1"},
          {RDF.bnode(:c1), NS.RDF.rest(), RDF.bnode(:c2)},
          {RDF.bnode(:c2), NS.RDF.first(), ~L"c2"},
          {RDF.bnode(:c2), NS.RDF.rest(), RDF.bnode(:c3)},
          {RDF.bnode(:c3), NS.RDF.first(), ~L"c3"},
          {RDF.bnode(:c3), NS.RDF.rest(), NS.RDF.nil()},
          {RDF.bnode(:b0), NS.RDF.first(), RDF.bnode(:b1)},
          {RDF.bnode(:b0), NS.RDF.rest(), RDF.bnode(:c0)},
          {RDF.bnode(:b1), NS.RDF.first(), ~L"b1"},
          {RDF.bnode(:b1), NS.RDF.rest(), RDF.bnode(:b2)},
          {RDF.bnode(:b2), NS.RDF.first(), ~L"b2"},
          {RDF.bnode(:b2), NS.RDF.rest(), RDF.bnode(:b3)},
          {RDF.bnode(:b3), NS.RDF.first(), ~L"b3"},
          {RDF.bnode(:b3), NS.RDF.rest(), NS.RDF.nil()}
        ],
        [
          %{
            "@id" => "http://example.com/url",
            "http://example.com/property" => [
              %{
                "@list" => [
                  %{"@list" => [%{"@value" => "a1"}, %{"@value" => "a2"}, %{"@value" => "a3"}]},
                  %{"@list" => [%{"@value" => "b1"}, %{"@value" => "b2"}, %{"@value" => "b3"}]},
                  %{"@list" => [%{"@value" => "c1"}, %{"@value" => "c2"}, %{"@value" => "c3"}]}
                ]
              }
            ]
          }
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
      if title == "multiple graphs with shared BNode" do
        @tag skip: "TODO: https://github.com/json-ld/json-ld.org/issues/357"
      end

      @tag data: data
      test title, %{data: {input, output}} do
        input |> gets_serialized_to(output)
      end
    end)
  end

  describe "quads" do
    %{
      "simple named graph" => %{
        input: {EX.a(), EX.b(), EX.c(), EX.U},
        output: [
          %{
            "@id" => "http://example.com/U",
            "@graph" => [
              %{
                "@id" => "http://example.com/a",
                "http://example.com/b" => [%{"@id" => "http://example.com/c"}]
              }
            ]
          }
        ]
      },
      "with properties" => %{
        input: [
          {EX.a(), EX.b(), EX.c(), EX.U},
          {EX.U, EX.d(), EX.e()}
        ],
        output: [
          %{
            "@id" => "http://example.com/U",
            "@graph" => [
              %{
                "@id" => "http://example.com/a",
                "http://example.com/b" => [%{"@id" => "http://example.com/c"}]
              }
            ],
            "http://example.com/d" => [%{"@id" => "http://example.com/e"}]
          }
        ]
      },
      "with lists" => %{
        input: [
          {EX.a(), EX.b(), RDF.bnode(:a), EX.U},
          {RDF.bnode(:a), NS.RDF.first(), EX.c(), EX.U},
          {RDF.bnode(:a), NS.RDF.rest(), NS.RDF.nil(), EX.U},
          {EX.U, EX.d(), RDF.bnode(:b)},
          {RDF.bnode(:b), NS.RDF.first(), EX.e()},
          {RDF.bnode(:b), NS.RDF.rest(), NS.RDF.nil()}
        ],
        output: [
          %{
            "@id" => "http://example.com/U",
            "@graph" => [
              %{
                "@id" => "http://example.com/a",
                "http://example.com/b" => [%{"@list" => [%{"@id" => "http://example.com/c"}]}]
              }
            ],
            "http://example.com/d" => [%{"@list" => [%{"@id" => "http://example.com/e"}]}]
          }
        ]
      },
      "Two Graphs with same subject and lists" => %{
        input: [
          {EX.a(), EX.b(), RDF.bnode(:a), EX.U},
          {RDF.bnode(:a), NS.RDF.first(), EX.c(), EX.U},
          {RDF.bnode(:a), NS.RDF.rest(), NS.RDF.nil(), EX.U},
          {EX.a(), EX.b(), RDF.bnode(:b), EX.V},
          {RDF.bnode(:b), NS.RDF.first(), EX.e(), EX.V},
          {RDF.bnode(:b), NS.RDF.rest(), NS.RDF.nil(), EX.V}
        ],
        output: [
          %{
            "@id" => "http://example.com/U",
            "@graph" => [
              %{
                "@id" => "http://example.com/a",
                "http://example.com/b" => [
                  %{
                    "@list" => [%{"@id" => "http://example.com/c"}]
                  }
                ]
              }
            ]
          },
          %{
            "@id" => "http://example.com/V",
            "@graph" => [
              %{
                "@id" => "http://example.com/a",
                "http://example.com/b" => [
                  %{
                    "@list" => [%{"@id" => "http://example.com/e"}]
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
      test title, %{data: %{input: input, output: output}} do
        input |> gets_serialized_to(output, data_structs: [Dataset])
      end
    end)
  end

  describe "encode options" do
    test ":context with a context map" do
      graph =
        ~I<http://manu.sporny.org/about#manu>
        |> S.givenName("Manu")
        |> S.familyName("Sporny")
        |> S.url(~I<http://manu.sporny.org/>)
        |> Graph.new()

      context = %{
        "givenName" => "http://schema.org/givenName",
        "familyName" => "http://schema.org/familyName",
        "homepage" => %{
          "@id" => "http://schema.org/url",
          "@type" => "@id"
        }
      }

      expected_result =
        """
        {
          "@context": {
            "familyName": "http://schema.org/familyName",
            "givenName": "http://schema.org/givenName",
            "homepage": {
              "@id": "http://schema.org/url",
              "@type": "@id"
            }
          },
          "@id": "http://manu.sporny.org/about#manu",
          "familyName": "Sporny",
          "givenName": "Manu",
          "homepage": "http://manu.sporny.org/"
        }
        """
        |> String.trim()

      assert JSON.LD.Encoder.encode!(graph, context: context, pretty: true) ==
               expected_result

      context_with_atom_keys = %{
        givenName: "http://schema.org/givenName",
        familyName: "http://schema.org/familyName",
        homepage: %{
          "@id": "http://schema.org/url",
          "@type": "@id"
        }
      }

      assert graph
             |> JSON.LD.Encoder.encode!(context: context_with_atom_keys, pretty: true)
             |> Jason.decode!() ==
               Jason.decode!(expected_result)
    end

    test ":context with a remote context" do
      bypass = Bypass.open()

      Bypass.expect(bypass, fn conn ->
        assert "GET" == conn.method
        assert "/test-context" == conn.request_path

        context = %{
          "@context" => %{
            "givenName" => "http://schema.org/givenName",
            "familyName" => "http://schema.org/familyName",
            "homepage" => %{
              "@id" => "http://schema.org/url",
              "@type" => "@id"
            }
          }
        }

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(context))
      end)

      remote_context = "http://localhost:#{bypass.port}/test-context"

      graph =
        ~I<http://manu.sporny.org/about#manu>
        |> S.givenName("Manu")
        |> S.familyName("Sporny")
        |> S.url(~I<http://manu.sporny.org/>)
        |> Graph.new()

      assert JSON.LD.Encoder.encode!(graph, context: remote_context, pretty: true) ==
               """
               {
                 "@context": "#{remote_context}",
                 "@id": "http://manu.sporny.org/about#manu",
                 "familyName": "Sporny",
                 "givenName": "Manu",
                 "homepage": "http://manu.sporny.org/"
               }
               """
               |> String.trim()
    end

    test "compaction options" do
      graph =
        ~I<http://manu.sporny.org/about#manu>
        |> S.givenName("Manu")
        |> S.familyName("Sporny")
        |> RDF.type(S.Person)
        |> EX.foo(3.14)
        |> EX.bar(EX.Bar)
        |> Graph.new()

      context = %{
        "givenName" => "http://schema.org/givenName",
        "familyName" => "http://schema.org/familyName"
      }

      expected_result =
        """
        {
          "@context": {
            "familyName": "http://schema.org/familyName",
            "givenName": "http://schema.org/givenName"
          },
          "@id": "http://manu.sporny.org/about#manu",
          "familyName": "Sporny",
          "givenName": "Manu",
          "http://example.com/bar": {
            "@id": "Bar"
          },
          "http://example.com/foo": 3.14,
          "http://www.w3.org/1999/02/22-rdf-syntax-ns#type": {
            "@id": "http://schema.org/Person"
          }
        }
        """
        |> String.trim()

      assert JSON.LD.Encoder.encode!(graph,
               context: context,
               base: EX.__base_iri__(),
               use_native_types: true,
               use_rdf_type: true,
               pretty: true
             ) == expected_result

      assert JSON.LD.Encoder.encode!(graph,
               context: context,
               base: EX,
               use_native_types: true,
               use_rdf_type: true,
               pretty: true
             ) == expected_result
    end

    test "base_iri of a RDF.Graph is used as the default for :base" do
      context = %{
        "p" => %{
          "@id" => IRI.to_string(EX.p()),
          "@type" => "@id"
        }
      }

      assert JSON.LD.Encoder.encode!(
               Graph.new({EX.S, EX.p(), EX.O}, base_iri: EX),
               context: context,
               pretty: true
             ) ==
               """
               {
                 "@context": {
                   "p": {
                     "@id": "#{EX.p()}",
                     "@type": "@id"
                   }
                 },
                 "@id": "S",
                 "p": "O"
               }
               """
               |> String.trim()

      assert JSON.LD.Encoder.encode!(
               Graph.new({EX.S, EX.p(), S.O}, base_iri: EX),
               context: context,
               base: S,
               pretty: true
             ) ==
               """
               {
                 "@context": {
                   "p": {
                     "@id": "#{EX.p()}",
                     "@type": "@id"
                   }
                 },
                 "@id": "http://example.com/S",
                 "p": "O"
               }
               """
               |> String.trim()
    end

    test "rdf_direction option with i18n-datatype" do
      {EX.a(), EX.label(),
       RDF.literal("text with direction", datatype: ~I<https://www.w3.org/ns/i18n#_rtl>)}
      |> gets_serialized_to(
        [
          %{
            "@id" => "http://example.com/a",
            "http://example.com/label" => [
              %{"@value" => "text with direction", "@direction" => "rtl"}
            ]
          }
        ],
        rdf_direction: "i18n-datatype"
      )
    end

    test "rdf_direction option with compound-literal" do
      [
        {EX.a(), EX.label(), RDF.bnode(:cl1)},
        {RDF.bnode(:cl1), NS.RDF.value(), RDF.literal("text with direction")},
        {RDF.bnode(:cl1), RDF.iri(RDF.__base_iri__() <> "direction"), RDF.literal("rtl")}
      ]
      |> gets_serialized_to(
        [
          %{
            "@id" => "http://example.com/a",
            "http://example.com/label" => [
              %{"@value" => "text with direction", "@direction" => "rtl"}
            ]
          }
        ],
        rdf_direction: "compound-literal"
      )
    end
  end

  describe "problems" do
    %{
      "xsd:boolean as value" => {
        {~I<http://data.wikia.com/terms#playable>, NS.RDFS.range(), NS.XSD.boolean()},
        [
          %{
            "@id" => "http://data.wikia.com/terms#playable",
            "http://www.w3.org/2000/01/rdf-schema#range" => [
              %{"@id" => "http://www.w3.org/2001/XMLSchema#boolean"}
            ]
          }
        ]
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: {input, output}} do
        input |> gets_serialized_to(output)
      end
    end)
  end
end
