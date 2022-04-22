defmodule JSON.LD.EncoderTest do
  use ExUnit.Case, async: false

  doctest JSON.LD.Encoder

  alias RDF.{Dataset, Graph, Description}
  alias RDF.NS

  import RDF.Sigils

  defmodule TestNS do
    use RDF.Vocabulary.Namespace
    defvocab EX, base_iri: "http://example.com/", terms: [], strict: false
    defvocab S, base_iri: "http://schema.org/", terms: [], strict: false
  end

  alias TestNS.{EX, S}

  @compile {:no_warn_undefined, JSON.LD.EncoderTest.TestNS.EX}
  @compile {:no_warn_undefined, JSON.LD.EncoderTest.TestNS.S}

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

    @tag skip:
           "TODO: Is this spec conformant or RDF.rb specific? RDF.rb doesn't use the specified RDF to Object Conversion algorithm but reuses a generalized expand_value algorithm"
    test "decimal" do
      {EX.a(), EX.b(), RDF.literal(1.0)}
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

    @tag skip:
           "TODO: Is this spec conformant or RDF.rb specific? RDF.rb doesn't use the specified RDF to Object Conversion algorithm but reuses a generalized expand_value algorithm"
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

  describe "datatyped (non-native) literals" do
    %{
      integer: 1,
      unsignedInt: 1,
      nonNegativeInteger: 1,
      float: 1.0,
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
            "@id" => "http://www.example.com/G",
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
                "@id" => "http://www.example.com/z",
                "http://www.example.com/q" => [%{"@id" => "_:z0"}]
              }
            ]
          },
          %{
            "@id" => "http://www.example.com/G1",
            "@graph" => [
              %{
                "@id" => "http://www.example.com/x",
                "http://www.example.com/p" => [%{"@id" => "_:z1"}]
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

      assert JSON.LD.Encoder.encode!(graph, context: context_with_atom_keys, pretty: true) ==
               expected_result
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

        Plug.Conn.resp(conn, 200, Jason.encode!(context))
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

      assert JSON.LD.Encoder.encode!(graph,
               context: context,
               base: EX.__base_iri__(),
               use_native_types: true,
               use_rdf_type: true,
               pretty: true
             ) ==
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
