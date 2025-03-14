defmodule JSON.LD.ContextTest do
  use JSON.LD.Case

  alias JSON.LD.Context.TermDefinition

  doctest JSON.LD.Context

  describe "create from Hash" do
    test "extracts @base" do
      assert JSON.LD.context(%{"@base" => "http://base/"}).base_iri == "http://base/"
    end

    test "extracts @language" do
      assert JSON.LD.context(%{"@language" => "en"}).default_language == "en"
    end

    test "extracts @direction" do
      assert JSON.LD.context(%{"@direction" => "rtl"}).base_direction == :rtl
    end

    test "extracts @vocab" do
      assert JSON.LD.context(%{"@vocab" => "http://schema.org/"}).vocab ==
               "http://schema.org/"
    end

    test "maps term with IRI value" do
      c = JSON.LD.context(%{"foo" => "http://example.com/"})
      assert c.term_defs["foo"]
      assert c.term_defs["foo"].iri_mapping == "http://example.com/"
    end

    test "maps term with @id" do
      c = JSON.LD.context(%{"foo" => %{"@id" => "http://example.com/"}})
      assert c.term_defs["foo"]
      assert c.term_defs["foo"].iri_mapping == "http://example.com/"
    end

    test "maps blank node @id (with deprecation)" do
      c = JSON.LD.context(%{"foo" => %{"@id" => "_:bn"}})
      assert c.term_defs["foo"]
      assert c.term_defs["foo"].iri_mapping == "_:bn"
    end

    test "associates @list container mapping with predicate" do
      c = JSON.LD.context(%{"foo" => %{"@id" => "http://example.com/", "@container" => "@list"}})
      assert c.term_defs["foo"]
      assert c.term_defs["foo"].iri_mapping == "http://example.com/"
      assert c.term_defs["foo"].container_mapping == ["@list"]
    end

    test "associates @set container mapping with predicate" do
      c = JSON.LD.context(%{"foo" => %{"@id" => "http://example.com/", "@container" => "@set"}})
      assert c.term_defs["foo"]
      assert c.term_defs["foo"].iri_mapping == "http://example.com/"
      assert c.term_defs["foo"].container_mapping == ["@set"]
    end

    test "associates @language container mapping with predicate" do
      c =
        JSON.LD.context(%{"foo" => %{"@id" => "http://example.com/", "@container" => "@language"}})

      assert c.term_defs["foo"]
      assert c.term_defs["foo"].iri_mapping == "http://example.com/"
      assert c.term_defs["foo"].container_mapping == ["@language"]
    end

    test "associates @index container mapping with predicate" do
      c = JSON.LD.context(%{"foo" => %{"@id" => "http://example.com/", "@container" => "@index"}})
      assert c.term_defs["foo"]
      assert c.term_defs["foo"].iri_mapping == "http://example.com/"
      assert c.term_defs["foo"].container_mapping == ["@index"]
    end

    test "associates @id container mapping with predicate" do
      c = JSON.LD.context(%{"foo" => %{"@id" => "http://example.com/", "@container" => "@id"}})
      assert c.term_defs["foo"]
      assert c.term_defs["foo"].iri_mapping == "http://example.com/"
      assert c.term_defs["foo"].container_mapping == ["@id"]
    end

    test "associates @type container mapping with predicate" do
      c = JSON.LD.context(%{"foo" => %{"@id" => "http://example.com/", "@container" => "@type"}})
      assert c.term_defs["foo"]
      assert c.term_defs["foo"].iri_mapping == "http://example.com/"
      assert c.term_defs["foo"].container_mapping == ["@type"]
    end

    test "associates @graph container mapping with predicate" do
      c = JSON.LD.context(%{"foo" => %{"@id" => "http://example.com/", "@container" => "@graph"}})
      assert c.term_defs["foo"]
      assert c.term_defs["foo"].iri_mapping == "http://example.com/"
      assert c.term_defs["foo"].container_mapping == ["@graph"]
    end

    test "associates multiple container mappings with predicate" do
      c =
        JSON.LD.context(%{
          "foo" => %{"@id" => "http://example.com/", "@container" => ["@graph", "@id"]}
        })

      assert c.term_defs["foo"]
      assert c.term_defs["foo"].iri_mapping == "http://example.com/"
      assert c.term_defs["foo"].container_mapping == ["@graph", "@id"]
    end

    test "redefines @type with an @container" do
      context = JSON.LD.context(%{"@type" => %{"@container" => "@set"}})
      assert context.term_defs["@type"].container_mapping == ["@set"]
    end

    test "associates @id type mapping with predicate" do
      c = JSON.LD.context(%{"foo" => %{"@id" => "http://example.com/", "@type" => "@id"}})
      assert c.term_defs["foo"]
      assert c.term_defs["foo"].iri_mapping == "http://example.com/"
      assert c.term_defs["foo"].type_mapping == "@id"
    end

    test "associates @json type mapping with predicate" do
      c = JSON.LD.context(%{"foo" => %{"@id" => "http://example.com/", "@type" => "@json"}})
      assert c.term_defs["foo"]
      assert c.term_defs["foo"].iri_mapping == "http://example.com/"
      assert c.term_defs["foo"].type_mapping == "@json"
    end

    test "associates @none type mapping with predicate" do
      c = JSON.LD.context(%{"foo" => %{"@id" => "http://example.com/", "@type" => "@none"}})
      assert c.term_defs["foo"]
      assert c.term_defs["foo"].iri_mapping == "http://example.com/"
      assert c.term_defs["foo"].type_mapping == "@none"
    end

    test "associates type mapping with predicate" do
      c =
        JSON.LD.context(%{
          "foo" => %{"@id" => "http://example.com/", "@type" => to_string(XSD.string())}
        })

      assert c.term_defs["foo"]
      assert c.term_defs["foo"].iri_mapping == "http://example.com/"
      assert c.term_defs["foo"].type_mapping == to_string(XSD.string())
    end

    test "associates language mapping with predicate" do
      c = JSON.LD.context(%{"foo" => %{"@id" => "http://example.com/", "@language" => "en"}})
      assert c.term_defs["foo"]
      assert c.term_defs["foo"].iri_mapping == "http://example.com/"
      assert c.term_defs["foo"].language_mapping == "en"
    end

    test "associates direction mapping with predicate" do
      c = JSON.LD.context(%{"foo" => %{"@id" => "http://example.com/", "@direction" => "rtl"}})
      assert c.term_defs["foo"]
      assert c.term_defs["foo"].iri_mapping == "http://example.com/"
      assert c.term_defs["foo"].direction_mapping == :rtl
    end

    test "associates both language and direction mapping with predicate" do
      c =
        JSON.LD.context(%{
          "foo" => %{"@id" => "http://example.com/", "@language" => "en", "@direction" => "ltr"}
        })

      assert c.term_defs["foo"]
      assert c.term_defs["foo"].iri_mapping == "http://example.com/"
      assert c.term_defs["foo"].language_mapping == "en"
      assert c.term_defs["foo"].direction_mapping == :ltr
    end

    test "expands chains of term definition/use with string values" do
      assert JSON.LD.context(%{
               "foo" => "bar",
               "bar" => "baz",
               "baz" => "http://example.com/"
             })
             |> iri_mappings == %{
               "foo" => "http://example.com/",
               "bar" => "http://example.com/",
               "baz" => "http://example.com/"
             }
    end

    test "expands terms using @vocab" do
      c =
        JSON.LD.context(%{
          "foo" => "bar",
          "@vocab" => "http://example.com/"
        })

      assert c.term_defs["foo"]
      assert c.term_defs["foo"].iri_mapping == "http://example.com/bar"
    end

    test "associates @prefix with predicate" do
      c = JSON.LD.context(%{"ex" => %{"@id" => "http://example.org/", "@prefix" => true}})
      assert c.term_defs["ex"]
      assert c.term_defs["ex"].iri_mapping == "http://example.org/"
      assert c.term_defs["ex"].prefix_flag == true
    end

    test "associates @context with predicate" do
      c =
        JSON.LD.context(%{
          "foo" => %{
            "@id" => "http://example.com/",
            "@context" => %{
              "bar" => "http://example.com/baz"
            }
          }
        })

      assert c.term_defs["foo"]
      assert c.term_defs["foo"].iri_mapping == "http://example.com/"
      assert c.term_defs["foo"].context == %{"bar" => "http://example.com/baz"}
    end

    test "sets term as protected" do
      c = JSON.LD.context(%{"foo" => %{"@id" => "http://example.com/", "@protected" => true}})
      assert c.term_defs["foo"]
      assert c.term_defs["foo"].iri_mapping == "http://example.com/"
      assert c.term_defs["foo"].protected == true
    end

    test "sets all terms as protected" do
      c =
        JSON.LD.context(%{
          "@protected" => true,
          "foo" => %{"@id" => "http://example.com/"},
          "bar" => %{"@id" => "http://example.org/"}
        })

      assert c.term_defs["foo"]
      assert c.term_defs["foo"].protected == true
      assert c.term_defs["bar"].protected == true
    end

    test "sets @nest on a term definition" do
      c = JSON.LD.context(%{"foo" => %{"@id" => "http://example.com/", "@nest" => "@nest"}})
      assert c.term_defs["foo"]
      assert c.term_defs["foo"].iri_mapping == "http://example.com/"
      assert c.term_defs["foo"].nest_value == "@nest"
    end
  end

  describe "create from Array/List" do
    test "merges definitions from each context" do
      assert JSON.LD.context([
               %{"foo" => "http://example.com/foo"},
               %{"bar" => "foo"}
             ])
             |> iri_mappings == %{
               "foo" => "http://example.com/foo",
               "bar" => "http://example.com/foo"
             }
    end

    test "later contexts override earlier contexts" do
      assert JSON.LD.context([
               %{"term" => "http://example.org/1"},
               %{"term" => "http://example.org/2"}
             ])
             |> iri_mappings == %{
               "term" => "http://example.org/2"
             }
    end
  end

  describe "container types" do
    test "simple @list container" do
      context =
        JSON.LD.context(%{
          "foo" => %{"@id" => "http://example.com/", "@container" => "@list"}
        })

      assert context.term_defs["foo"]
      assert context.term_defs["foo"].iri_mapping == "http://example.com/"
      assert context.term_defs["foo"].container_mapping == ["@list"]
    end

    test "simple @set container" do
      context =
        JSON.LD.context(%{
          "foo" => %{"@id" => "http://example.com/", "@container" => "@set"}
        })

      assert context.term_defs["foo"]
      assert context.term_defs["foo"].iri_mapping == "http://example.com/"
      assert context.term_defs["foo"].container_mapping == ["@set"]
    end

    test "@language container" do
      context =
        JSON.LD.context(%{
          "foo" => %{"@id" => "http://example.com/", "@container" => "@language"}
        })

      assert context.term_defs["foo"]
      assert context.term_defs["foo"].iri_mapping == "http://example.com/"
      assert context.term_defs["foo"].container_mapping == ["@language"]
    end

    test "@index container" do
      context =
        JSON.LD.context(%{
          "foo" => %{"@id" => "http://example.com/", "@container" => "@index"}
        })

      assert context.term_defs["foo"]
      assert context.term_defs["foo"].iri_mapping == "http://example.com/"
      assert context.term_defs["foo"].container_mapping == ["@index"]
    end

    test "@id container" do
      context =
        JSON.LD.context(%{
          "foo" => %{"@id" => "http://example.com/", "@container" => "@id"}
        })

      assert context.term_defs["foo"]
      assert context.term_defs["foo"].iri_mapping == "http://example.com/"
      assert context.term_defs["foo"].container_mapping == ["@id"]
    end

    test "@type container" do
      context =
        JSON.LD.context(%{
          "foo" => %{"@id" => "http://example.com/", "@container" => "@type"}
        })

      assert context.term_defs["foo"]
      assert context.term_defs["foo"].iri_mapping == "http://example.com/"
      assert context.term_defs["foo"].container_mapping == ["@type"]
    end

    test "@graph container" do
      context =
        JSON.LD.context(%{
          "foo" => %{"@id" => "http://example.com/", "@container" => "@graph"}
        })

      assert context.term_defs["foo"]
      assert context.term_defs["foo"].iri_mapping == "http://example.com/"
      assert context.term_defs["foo"].container_mapping == ["@graph"]
    end

    test "multiple container mappings with @graph and @id" do
      context =
        JSON.LD.context(%{
          "foo" => %{"@id" => "http://example.com/", "@container" => ["@graph", "@id"]}
        })

      assert context.term_defs["foo"]
      assert context.term_defs["foo"].iri_mapping == "http://example.com/"
      assert context.term_defs["foo"].container_mapping == ["@graph", "@id"]
    end

    test "multiple container mappings with @graph and @set" do
      context =
        JSON.LD.context(%{
          "foo" => %{"@id" => "http://example.com/", "@container" => ["@graph", "@set"]}
        })

      assert context.term_defs["foo"]
      assert context.term_defs["foo"].iri_mapping == "http://example.com/"
      assert context.term_defs["foo"].container_mapping == ["@graph", "@set"]
    end

    test "multiple container mappings with @id and @set" do
      context =
        JSON.LD.context(%{
          "foo" => %{"@id" => "http://example.com/", "@container" => ["@id", "@set"]}
        })

      assert context.term_defs["foo"]
      assert context.term_defs["foo"].iri_mapping == "http://example.com/"
      assert context.term_defs["foo"].container_mapping == ["@id", "@set"]
    end

    test "multiple container mappings with @index and @set" do
      context =
        JSON.LD.context(%{
          "foo" => %{"@id" => "http://example.com/", "@container" => ["@index", "@set"]}
        })

      assert context.term_defs["foo"]
      assert context.term_defs["foo"].iri_mapping == "http://example.com/"
      assert context.term_defs["foo"].container_mapping == ["@index", "@set"]
    end

    test "multiple container mappings with @language and @set" do
      context =
        JSON.LD.context(%{
          "foo" => %{"@id" => "http://example.com/", "@container" => ["@language", "@set"]}
        })

      assert context.term_defs["foo"]
      assert context.term_defs["foo"].iri_mapping == "http://example.com/"
      assert context.term_defs["foo"].container_mapping == ["@language", "@set"]
    end

    test "multiple container mappings with @type and @set" do
      context =
        JSON.LD.context(%{
          "foo" => %{"@id" => "http://example.com/", "@container" => ["@type", "@set"]}
        })

      assert context.term_defs["foo"]
      assert context.term_defs["foo"].iri_mapping == "http://example.com/"
      assert context.term_defs["foo"].container_mapping == ["@type", "@set"]
    end

    test "three container mappings with @graph, @id and @set" do
      context =
        JSON.LD.context(%{
          "foo" => %{"@id" => "http://example.com/", "@container" => ["@graph", "@id", "@set"]}
        })

      assert context.term_defs["foo"]
      assert context.term_defs["foo"].iri_mapping == "http://example.com/"
      assert context.term_defs["foo"].container_mapping == ["@graph", "@id", "@set"]
    end
  end

  describe "language tests" do
    test "language function extracts language from term definition" do
      context =
        JSON.LD.context(%{
          "ex" => "http://example.org/",
          "nil" => %{"@id" => "ex:nil", "@language" => nil},
          "en" => %{"@id" => "ex:en", "@language" => "en"}
        })

      assert TermDefinition.language(context.term_defs["ex"], context) == nil
      assert TermDefinition.language(context.term_defs["nil"], context) == nil
      assert TermDefinition.language(context.term_defs["en"], context) == "en"
    end

    test "language function uses default language when not specified in term" do
      context =
        JSON.LD.context(%{
          "@language" => "en",
          "foo" => "http://example.org/foo"
        })

      assert TermDefinition.language(context.term_defs["foo"], context) == "en"
    end
  end

  describe "direction tests" do
    test "creates a term with direction" do
      context =
        JSON.LD.context(%{
          "ex" => "http://example.org/",
          "nil" => %{"@id" => "ex:nil", "@direction" => nil},
          "rtl" => %{"@id" => "ex:rtl", "@direction" => "rtl"}
        })

      assert context.term_defs["rtl"].direction_mapping == :rtl
      assert context.term_defs["nil"].direction_mapping == nil
      assert context.term_defs["ex"].direction_mapping == false
    end

    test "establishes default direction" do
      context = JSON.LD.context(%{"@direction" => "rtl"})
      assert context.base_direction == :rtl
    end

    test "supports term with both language and direction" do
      context =
        JSON.LD.context(%{
          "langdir" => %{
            "@id" => "http://example.com/langdir",
            "@language" => "en",
            "@direction" => "ltr"
          }
        })

      assert context.term_defs["langdir"].language_mapping == "en"
      assert context.term_defs["langdir"].direction_mapping == :ltr
    end
  end

  describe "nested context tests" do
    test "creates a term with a nested context" do
      context =
        JSON.LD.context(%{
          "foo" => %{
            "@id" => "http://example.com/",
            "@context" => %{
              "bar" => "http://example.com/baz"
            }
          }
        })

      assert context.term_defs["foo"]
      assert context.term_defs["foo"].iri_mapping == "http://example.com/"
      assert context.term_defs["foo"].context == %{"bar" => "http://example.com/baz"}
    end
  end

  describe "protected contexts" do
    test "seals a term with @protected true" do
      ctx =
        JSON.LD.context(%{
          "protected" => %{"@id" => "http://example.com/protected", "@protected" => true},
          "unprotected" => %{"@id" => "http://example.com/unprotected"}
        })

      assert ctx.term_defs["protected"].protected == true
      assert ctx.term_defs["unprotected"].protected == false
    end

    test "seals all terms with @protected true in context" do
      ctx =
        JSON.LD.context(%{
          "@protected" => true,
          "protected" => %{"@id" => "http://example.com/protected"},
          "protected2" => %{"@id" => "http://example.com/protected2"}
        })

      assert ctx.term_defs["protected"].protected == true
      assert ctx.term_defs["protected2"].protected == true
    end

    test "does not seal term with @protected: false when context is protected" do
      ctx =
        JSON.LD.context(%{
          "@protected" => true,
          "protected" => %{"@id" => "http://example.com/protected"},
          "unprotected" => %{"@id" => "http://example.com/unprotected", "@protected" => false}
        })

      assert ctx.term_defs["protected"].protected == true
      assert ctx.term_defs["unprotected"].protected == false
    end

    test "does not error when redefining an identical term" do
      c = %{
        "protected" => %{"@id" => "http://example.com/protected", "@protected" => true}
      }

      ctx = JSON.LD.context(c)

      # Should not raise error
      assert JSON.LD.Context.update(ctx, c)
    end

    test "errors when redefining a protected term" do
      ctx =
        JSON.LD.context(%{
          "protected" => %{"@id" => "http://example.com/protected", "@protected" => true}
        })

      assert_raise JSON.LD.ProtectedTermRedefinitionError, fn ->
        JSON.LD.Context.update(ctx, %{"protected" => "http://example.com/different"})
      end
    end

    test "errors when clearing a context having protected terms" do
      ctx =
        JSON.LD.context(%{
          "protected" => %{"@id" => "http://example.com/protected", "@protected" => true}
        })

      assert_raise JSON.LD.InvalidContextNullificationError, fn ->
        JSON.LD.Context.update(ctx, nil)
      end
    end
  end

  describe "@nest functionality" do
    test "creates a term with @nest value" do
      context =
        JSON.LD.context(%{
          "ex" => "http://example.org/",
          "nest" => %{"@id" => "ex:nest", "@nest" => "@nest"}
        })

      assert context.term_defs["nest"]
      assert context.term_defs["nest"].iri_mapping == "http://example.org/nest"
      assert context.term_defs["nest"].nest_value == "@nest"
    end

    test "creates a term with custom nest value" do
      context =
        JSON.LD.context(%{
          "ex" => "http://example.org/",
          "nest-alias" => "@nest",
          "nest2" => %{"@id" => "ex:nest2", "@nest" => "nest-alias"}
        })

      assert context.term_defs["nest2"]
      assert context.term_defs["nest2"].iri_mapping == "http://example.org/nest2"
      assert context.term_defs["nest2"].nest_value == "nest-alias"
    end

    test "rejects a keyword other than @nest for the value of @nest" do
      assert_raise JSON.LD.InvalidNestValueError, fn ->
        JSON.LD.context(%{
          "no-keyword-nest" => %{"@id" => "http://example/f", "@nest" => "@id"}
        })
      end
    end

    test "rejects @nest with @reverse" do
      assert_raise JSON.LD.InvalidReversePropertyError, fn ->
        JSON.LD.context(%{
          "no-reverse-nest" => %{"@reverse" => "http://example/f", "@nest" => "@nest"}
        })
      end
    end

    test "creates a context with a custom @nest alias" do
      context =
        JSON.LD.context(%{
          "@vocab" => "http://example.org/",
          "metadata" => "@nest",
          "author" => %{"@nest" => "metadata"},
          "title" => %{"@nest" => "metadata"}
        })

      assert context.term_defs["metadata"].iri_mapping == "@nest"
      assert context.term_defs["author"].nest_value == "metadata"
      assert context.term_defs["title"].nest_value == "metadata"
    end

    test "creates a context with default @nest and nested properties" do
      context =
        JSON.LD.context(%{
          "@vocab" => "http://example.org/",
          "creator" => %{"@nest" => "@nest"},
          "publisher" => %{"@nest" => "@nest"},
          "title" => %{"@id" => "http://purl.org/dc/terms/title"}
        })

      assert context.term_defs["creator"].nest_value == "@nest"
      assert context.term_defs["publisher"].nest_value == "@nest"
      assert context.term_defs["title"].nest_value == nil
    end
  end

  describe "term definitions with null values" do
    test "removes @language if set to null" do
      assert JSON.LD.context([
               %{"@language" => "en"},
               %{"@language" => nil}
             ]).default_language == nil
    end

    test "removes @direction if set to null" do
      assert JSON.LD.context([
               %{"@direction" => "rtl"},
               %{"@direction" => nil}
             ]).base_direction == nil
    end

    test "removes @vocab if set to null" do
      assert JSON.LD.context([
               %{"@vocab" => "http://schema.org/"},
               %{"@vocab" => nil}
             ]).vocab == nil
    end

    test "removes term if set to null with @vocab" do
      assert JSON.LD.context([
               %{
                 "@vocab" => "http://schema.org/",
                 "term" => nil
               }
             ])
             |> iri_mappings == %{
               "term" => nil
             }
    end

    test "loads initial context" do
      init_ec = JSON.LD.Context.new()
      nil_ec = JSON.LD.context(nil)
      assert nil_ec.default_language == init_ec.default_language
      assert nil_ec |> coercions == init_ec |> coercions
      assert nil_ec |> containers == init_ec |> containers
      assert nil_ec |> languages == init_ec |> languages
      assert nil_ec |> iri_mappings == init_ec |> iri_mappings
    end
  end

  describe "remote contexts" do
    test "when the remote context is a list" do
      bypass = Bypass.open()

      Bypass.expect(bypass, fn conn ->
        assert "GET" == conn.method
        assert "/litepub-0.1.jsonld" == conn.request_path
        context = File.read!("test/fixtures/litepub-0.1.jsonld")
        Plug.Conn.resp(conn, 200, context)
      end)

      assert context = JSON.LD.context("http://localhost:#{bypass.port}/litepub-0.1.jsonld")

      assert %{
               "Emoji" => "http://joinmastodon.org/ns#Emoji",
               # https://www.w3.org/ns/activitystreams
               "Accept" => "https://www.w3.org/ns/activitystreams#Accept",
               # https://w3id.org/security/v1
               "CryptographicKey" => "https://w3id.org/security#Key"
             } = iri_mappings(context)
    end

    test "loads a remote context with local mappings" do
      bypass = Bypass.open()

      Bypass.expect(bypass, fn conn ->
        assert "GET" == conn.method
        assert "/context" == conn.request_path
        json_content = ~s({
          "@context": {
            "xsd": "http://www.w3.org/2001/XMLSchema#",
            "name": "http://xmlns.com/foaf/0.1/name",
            "homepage": {"@id": "http://xmlns.com/foaf/0.1/homepage", "@type": "@id"},
            "avatar": {"@id": "http://xmlns.com/foaf/0.1/avatar", "@type": "@id"}
          }
        })
        Plug.Conn.resp(conn, 200, json_content)
      end)

      assert context =
               JSON.LD.context([
                 "http://localhost:#{bypass.port}/context",
                 %{"integer" => "xsd:integer"}
               ])

      assert %{
               "xsd" => "http://www.w3.org/2001/XMLSchema#",
               "name" => "http://xmlns.com/foaf/0.1/name",
               "homepage" => "http://xmlns.com/foaf/0.1/homepage",
               "avatar" => "http://xmlns.com/foaf/0.1/avatar",
               "integer" => "http://www.w3.org/2001/XMLSchema#integer"
             } = iri_mappings(context)
    end

    test "fails given a missing remote @context" do
      bypass = Bypass.open()

      Bypass.expect(bypass, fn conn ->
        Plug.Conn.resp(conn, 404, "Not Found")
      end)

      assert_raise JSON.LD.LoadingRemoteContextFailedError,
                   ~r/http:\/\/localhost:#{bypass.port}\/context/,
                   fn ->
                     JSON.LD.context("http://localhost:#{bypass.port}/context")
                   end
    end
  end

  describe "JSON.LD.context/2" do
    @example_context_map %{
      "@context" => %{
        "givenName" => "http://schema.org/givenName",
        "familyName" => "http://schema.org/familyName",
        "homepage" => %{
          "@id" => "http://schema.org/url",
          "@type" => "@id"
        }
      }
    }

    test "wraps everything under a @context" do
      assert JSON.LD.context(@example_context_map["@context"]) ==
               JSON.LD.context(@example_context_map)
    end

    test "with atom keys" do
      context_with_atom_keys = %{
        givenName: "http://schema.org/givenName",
        familyName: "http://schema.org/familyName",
        homepage: %{
          "@id": "http://schema.org/url",
          "@type": "@id"
        }
      }

      assert JSON.LD.context(context_with_atom_keys) ==
               JSON.LD.context(@example_context_map)

      assert JSON.LD.context(%{"@context": context_with_atom_keys}) ==
               JSON.LD.context(@example_context_map)

      assert JSON.LD.context(%{"@context" => context_with_atom_keys}) ==
               JSON.LD.context(@example_context_map)
    end

    test "with a RDF.PropertyMap" do
      expected_context = %{
        "@context" => %{
          "givenName" => "http://schema.org/givenName",
          "familyName" => "http://schema.org/familyName"
        }
      }

      property_map =
        RDF.property_map(
          givenName: "http://schema.org/givenName",
          familyName: "http://schema.org/familyName"
        )

      assert JSON.LD.context(property_map) == JSON.LD.context(expected_context)
    end
  end

  describe "errors" do
    %{
      "no @id, @type, or @container" => %{
        input: %{"foo" => %{}},
        exception: JSON.LD.InvalidIRIMappingError
      },
      "value as array" => %{
        input: %{"foo" => []},
        exception: JSON.LD.InvalidTermDefinitionError
      },
      "@id as object" => %{
        input: %{"foo" => %{"@id" => %{}}},
        exception: JSON.LD.InvalidIRIMappingError
      },
      "@id as array of object" => %{
        input: %{"foo" => %{"@id" => [{}]}},
        exception: JSON.LD.InvalidIRIMappingError
      },
      "@id as array of null" => %{
        input: %{"foo" => %{"@id" => [nil]}},
        exception: JSON.LD.InvalidIRIMappingError
      },
      "@type as object" => %{
        input: %{"foo" => %{"@type" => %{}}},
        exception: JSON.LD.InvalidTypeMappingError
      },
      "@type as array" => %{
        input: %{"foo" => %{"@type" => []}},
        exception: JSON.LD.InvalidTypeMappingError
      },
      "@type as @list" => %{
        input: %{"foo" => %{"@type" => "@list"}},
        exception: JSON.LD.InvalidTypeMappingError
      },
      "@type as @set" => %{
        input: %{"foo" => %{"@type" => "@set"}},
        exception: JSON.LD.InvalidTypeMappingError
      },
      "@container as object" => %{
        input: %{"foo" => %{"@container" => %{}}},
        exception: JSON.LD.InvalidIRIMappingError
      },
      "@container as empty array" => %{
        input: %{"foo" => %{"@container" => []}},
        exception: JSON.LD.InvalidIRIMappingError
      },
      "@container as string" => %{
        input: %{"foo" => %{"@container" => "true"}},
        exception: JSON.LD.InvalidIRIMappingError
      },
      "@language as @id" => %{
        input: %{"@language" => %{"@id" => "http://example.com/"}},
        exception: JSON.LD.InvalidDefaultLanguageError
      },
      "@direction as non-string" => %{
        input: %{"@direction" => %{"@id" => "http://example.com/"}},
        exception: JSON.LD.InvalidBaseDirectionError
      },
      "@direction as invalid value" => %{
        input: %{"@direction" => "invalid"},
        exception: JSON.LD.InvalidBaseDirectionError
      },
      "@vocab as @id" => %{
        input: %{"@vocab" => %{"@id" => "http://example.com/"}},
        exception: JSON.LD.InvalidVocabMappingError
      },
      "@context which is invalid" => %{
        input: %{"foo" => %{"@context" => %{"bar" => []}}},
        exception: JSON.LD.InvalidIRIMappingError
      },
      "@prefix is not a boolean" => %{
        input: %{"foo" => %{"@id" => "http://example.org/", "@prefix" => "string"}},
        exception: JSON.LD.InvalidPrefixValueError
      },
      "@import is not a string" => %{
        input: %{"@import" => true},
        exception: JSON.LD.InvalidImportValueError
      },
      "@propagate is not a boolean" => %{
        input: %{"@propagate" => "String"},
        exception: JSON.LD.InvalidPropagateValueError
      },
      "@nest is not a valid value" => %{
        input: %{"foo" => %{"@id" => "http://example.org/", "@nest" => "@id"}},
        exception: JSON.LD.InvalidNestValueError
      },
      "@nest with @reverse" => %{
        input: %{"foo" => %{"@reverse" => "http://example.org/", "@nest" => "@nest"}},
        exception: JSON.LD.InvalidReversePropertyError
      },
      "IRI term expands to different IRI" => %{
        input: %{
          "ex" => "http://example.com/",
          "ex2" => "http://example.com/2/",
          "ex:foo" => "ex2:foo"
        },
        exception: JSON.LD.InvalidIRIMappingError
      }
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: data} do
        assert_raise data.exception, fn ->
          JSON.LD.context(data.input)
        end
      end
    end)

    (JSON.LD.keywords() --
       ~w[@base @language @vocab @version @import @direction @propagate @protected])
    |> Enum.each(fn keyword ->
      @tag keyword: keyword
      test "does not redefine #{keyword} as a string", %{keyword: keyword} do
        assert_raise JSON.LD.KeywordRedefinitionError, fn ->
          JSON.LD.context(%{"@context" => %{keyword => "http://example.com/"}})
        end
      end

      @tag keyword: keyword
      test "does not redefine #{keyword} with an @id", %{keyword: keyword} do
        assert_raise JSON.LD.KeywordRedefinitionError, fn ->
          JSON.LD.context(%{"@context" => %{keyword => %{"@id" => "http://example.com/"}}})
        end
      end

      unless keyword == "@type" do
        @tag keyword: keyword
        test "does not redefine #{keyword} with an @container", %{keyword: keyword} do
          assert_raise JSON.LD.KeywordRedefinitionError, fn ->
            JSON.LD.context(%{"@context" => %{keyword => %{"@container" => "@set"}}})
          end
        end
      end
    end)
  end

  def iri_mappings(%JSON.LD.Context{term_defs: term_defs}) do
    Enum.reduce(term_defs, %{}, fn {term, term_def}, iri_mappings ->
      Map.put(iri_mappings, term, (term_def && term_def.iri_mapping) || nil)
    end)
  end

  def languages(%JSON.LD.Context{term_defs: term_defs}) do
    Enum.reduce(term_defs, %{}, fn {term, term_def}, language_mappings ->
      Map.put(language_mappings, term, term_def.language_mapping)
    end)
  end

  def coercions(%JSON.LD.Context{term_defs: term_defs}) do
    Enum.reduce(term_defs, %{}, fn {term, term_def}, type_mappings ->
      Map.put(type_mappings, term, term_def.type_mapping)
    end)
  end

  def containers(%JSON.LD.Context{term_defs: term_defs}) do
    Enum.reduce(term_defs, %{}, fn {term, term_def}, type_mappings ->
      Map.put(type_mappings, term, term_def.container_mapping)
    end)
  end
end
