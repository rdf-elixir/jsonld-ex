defmodule JSON.LD.ContextTest do
  use ExUnit.Case

  alias RDF.NS.{XSD}

  doctest JSON.LD.Context

  describe "create from Hash" do
    test "extracts @base" do
      assert JSON.LD.context(%{"@base" => "http://base/"}).base_iri == "http://base/"
    end

    test "extracts @language" do
      assert JSON.LD.context(%{"@language" => "en"}).default_language == "en"
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

    test "associates @list container mapping with predicate" do
      c = JSON.LD.context(%{"foo" => %{"@id" => "http://example.com/", "@container" => "@list"}})
      assert c.term_defs["foo"]
      assert c.term_defs["foo"].iri_mapping == "http://example.com/"
      assert c.term_defs["foo"].container_mapping == "@list"
    end

    test "associates @set container mapping with predicate" do
      c = JSON.LD.context(%{"foo" => %{"@id" => "http://example.com/", "@container" => "@set"}})
      assert c.term_defs["foo"]
      assert c.term_defs["foo"].iri_mapping == "http://example.com/"
      assert c.term_defs["foo"].container_mapping == "@set"
    end

    test "associates @id container mapping with predicate" do
      c = JSON.LD.context(%{"foo" => %{"@id" => "http://example.com/", "@type" => "@id"}})
      assert c.term_defs["foo"]
      assert c.term_defs["foo"].iri_mapping == "http://example.com/"
      assert c.term_defs["foo"].type_mapping == "@id"
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
  end

  describe "term definitions with null values" do
    test "removes @language if set to null" do
      assert JSON.LD.context([
               %{"@language" => "en"},
               %{"@language" => nil}
             ]).default_language == nil
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

    test "removes a term definition" do
      assert JSON.LD.context(%{"name" => nil}).term_defs["name"] == nil
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
      "@container as array" => %{
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
      "@vocab as @id" => %{
        input: %{"@vocab" => %{"@id" => "http://example.com/"}},
        exception: JSON.LD.InvalidVocabMappingError
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

    (JSON.LD.keywords() -- ~w[@base @language @vocab])
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
    end)
  end

  # TODO: "Furthermore, the term must not be an empty string ("") as not all programming languages are able to handle empty JSON keys." -- https://www.w3.org/TR/json-ld/#terms
  @tag :skip
  test "an empty string is not a valid term"

  # TODO: "To avoid forward-compatibility issues, a term should not start with an @ character as future versions of JSON-LD may introduce additional keywords." -- https://www.w3.org/TR/json-ld/#terms
  @tag :skip
  test "warn on terms starting with a @"

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
