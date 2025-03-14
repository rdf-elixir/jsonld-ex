defmodule JSON.LD.ValueCompactionTest do
  use JSON.LD.Case, async: false

  import JSON.LD.Compaction, only: [compact_value: 4]

  setup do
    context =
      context_with_inverse(%{
        "dc" => "http://purl.org/dc/terms/",
        "ex" => "http://example.org/",
        "foaf" => "http://xmlns.com/foaf/0.1/",
        "xsd" => to_string(XSD.__base_iri__()),
        "langmap" => %{"@id" => "http://example.com/langmap", "@container" => "@language"},
        "list" => %{"@id" => "http://example.org/list", "@container" => "@list"},
        "nolang" => %{"@id" => "http://example.org/nolang", "@language" => nil},
        "dir" => %{"@id" => "http://example.org/dir", "@direction" => "rtl"},
        "langdir" => %{
          "@id" => "http://example.org/langdir",
          "@language" => "en",
          "@direction" => "ltr"
        },
        "dc:created" => %{"@type" => to_string(XSD.date())},
        "foaf:age" => %{"@type" => to_string(XSD.integer())},
        "foaf:knows" => %{"@type" => "@id"},
        "ex:none" => %{"@type" => "@none"},
        "ex:json" => %{"@type" => "@json"}
      })

    %{example_context: context, options: JSON.LD.Options.new([])}
  end

  %{
    "absolute IRI" => ["foaf:knows", "http://example.com/", %{"@id" => "http://example.com/"}],
    "prefix:suffix" => ["foaf:knows", "ex:suffix", %{"@id" => "http://example.org/suffix"}],
    "integer" => ["foaf:age", "54", %{"@value" => "54", "@type" => to_string(XSD.integer())}],
    "date " => [
      "dc:created",
      "2011-12-27Z",
      %{"@value" => "2011-12-27Z", "@type" => to_string(XSD.date())}
    ],
    "no IRI" => ["foo", %{"@id" => "http://example.com/"}, %{"@id" => "http://example.com/"}],
    "no IRI (CURIE)" => [
      "foo",
      %{"@id" => "http://xmlns.com/foaf/0.1/Person"},
      %{"@id" => "http://xmlns.com/foaf/0.1/Person"}
    ],
    "no boolean" => [
      "foo",
      %{"@value" => "true", "@type" => "xsd:boolean"},
      %{"@value" => "true", "@type" => to_string(XSD.boolean())}
    ],
    "no integer" => [
      "foo",
      %{"@value" => "54", "@type" => "xsd:integer"},
      %{"@value" => "54", "@type" => to_string(XSD.integer())}
    ],
    "no date " => [
      "foo",
      %{"@value" => "2011-12-27Z", "@type" => "xsd:date"},
      %{"@value" => "2011-12-27Z", "@type" => to_string(XSD.date())}
    ],
    "no string " => ["foo", "string", %{"@value" => "string"}],
    "no lang " => ["nolang", "string", %{"@value" => "string"}],
    "direction" => ["dir", "string", %{"@value" => "string", "@direction" => "rtl"}],
    "language and direction" => [
      "langdir",
      "string",
      %{"@value" => "string", "@language" => "en", "@direction" => "ltr"}
    ],
    "native boolean" => ["foo", true, %{"@value" => true}],
    "native integer" => ["foo", 1, %{"@value" => 1}],
    "native integer(list)" => ["list", 1, %{"@value" => 1}],
    "native double" => ["foo", 1.1e1, %{"@value" => 1.1e1}],
    "ex:none IRI" => [
      "ex:none",
      %{"@id" => "http://example.com/"},
      %{"@id" => "http://example.com/"}
    ],
    "ex:none string" => ["ex:none", %{"@value" => "string"}, %{"@value" => "string"}],
    "ex:none integer" => [
      "ex:none",
      %{"@value" => "54", "@type" => "xsd:integer"},
      %{"@value" => "54", "@type" => to_string(XSD.integer())}
    ],
    "ex:json object" => [
      "ex:json",
      %{"foo" => "bar"},
      %{"@value" => %{"foo" => "bar"}, "@type" => "@json"}
    ],
    "ex:json array" => [
      "ex:json",
      [%{"foo" => "bar"}],
      %{"@value" => [%{"foo" => "bar"}], "@type" => "@json"}
    ]
  }
  |> Enum.each(fn {title, data} ->
    @tag data: data
    test title, %{data: [key, compacted, expanded], example_context: context, options: options} do
      assert compact_value(expanded, context, key, options) == compacted
    end
  end)

  describe "@language" do
    setup %{example_context: ld_context} = context do
      ld_context =
        %JSON.LD.Context{ld_context | default_language: "en"}
        |> JSON.LD.Context.set_inverse()

      %{context | example_context: ld_context}
    end

    %{
      "@id" => ["foo", %{"@id" => "foo"}, %{"@id" => "foo"}],
      "integer" => [
        "foo",
        %{"@value" => "54", "@type" => "xsd:integer"},
        %{"@value" => "54", "@type" => to_string(XSD.integer())}
      ],
      "date" => [
        "foo",
        %{"@value" => "2011-12-27Z", "@type" => "xsd:date"},
        %{"@value" => "2011-12-27Z", "@type" => to_string(XSD.date())}
      ],
      "no lang" => ["foo", %{"@value" => "foo"}, %{"@value" => "foo"}],
      "same lang" => ["foo", "foo", %{"@value" => "foo", "@language" => "en"}],
      "other lang" => [
        "foo",
        %{"@value" => "foo", "@language" => "bar"},
        %{"@value" => "foo", "@language" => "bar"}
      ],
      "langmap" => ["langmap", "en", %{"@value" => "en", "@language" => "en"}],
      "no lang with @type coercion" => ["dc:created", %{"@value" => "foo"}, %{"@value" => "foo"}],
      "no lang with @id coercion" => ["foaf:knows", %{"@value" => "foo"}, %{"@value" => "foo"}],
      "no lang with @language=null" => ["nolang", "string", %{"@value" => "string"}],
      "same lang with @type coercion" => [
        "dc:created",
        %{"@value" => "foo"},
        %{"@value" => "foo"}
      ],
      "same lang with @id coercion" => ["foaf:knows", %{"@value" => "foo"}, %{"@value" => "foo"}],
      "other lang with @type coercion" => [
        "dc:created",
        %{"@value" => "foo", "@language" => "bar"},
        %{"@value" => "foo", "@language" => "bar"}
      ],
      "other lang with @id coercion" => [
        "foaf:knows",
        %{"@value" => "foo", "@language" => "bar"},
        %{"@value" => "foo", "@language" => "bar"}
      ],
      "native boolean" => ["foo", true, %{"@value" => true}],
      "native integer" => ["foo", 1, %{"@value" => 1}],
      "native integer(list)" => ["list", 1, %{"@value" => 1}],
      "native double" => ["foo", 1.1e1, %{"@value" => 1.1e1}]
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: [key, compacted, expanded], example_context: context, options: options} do
        assert compact_value(expanded, context, key, options) == compacted
      end
    end)
  end

  describe "@direction" do
    setup %{example_context: ld_context} = context do
      ld_context =
        %JSON.LD.Context{ld_context | base_direction: :rtl}
        |> JSON.LD.Context.set_inverse()

      %{context | example_context: ld_context}
    end

    %{
      "value with direction" => [
        "foo",
        "foo",
        %{"@value" => "foo", "@direction" => "rtl"}
      ],
      "value with different direction" => [
        "foo",
        %{"@value" => "foo", "@direction" => "ltr"},
        %{"@value" => "foo", "@direction" => "ltr"}
      ],
      "value with language and direction" => [
        "foo",
        %{"@value" => "foo", "@language" => "en", "@direction" => "rtl"},
        %{"@value" => "foo", "@language" => "en", "@direction" => "rtl"}
      ],
      "term with specific direction" => [
        "dir",
        "string",
        %{"@value" => "string", "@direction" => "rtl"}
      ],
      "term with language and direction" => [
        "langdir",
        "string",
        %{"@value" => "string", "@language" => "en", "@direction" => "ltr"}
      ]
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: [key, compacted, expanded], example_context: context, options: options} do
        assert compact_value(expanded, context, key, options) == compacted
      end
    end)
  end

  describe "keywords" do
    setup do
      context =
        context_with_inverse(%{
          "id" => "@id",
          "type" => "@type",
          "list" => "@list",
          "set" => "@set",
          "language" => "@language",
          "literal" => "@value",
          "direction" => "@direction"
        })

      %{example_context: context, options: JSON.LD.Options.new([])}
    end

    %{
      "@id" => [
        "foo",
        %{"id" => "http://example.com/"},
        %{"@id" => "http://example.com/"}
      ],
      "@type" => [
        "foo",
        %{"literal" => "foo", "type" => "http://example.com/"},
        %{"@value" => "foo", "@type" => "http://example.com/"}
      ],
      "@value" => [
        "foo",
        %{"literal" => "foo", "language" => "bar"},
        %{"@value" => "foo", "@language" => "bar"}
      ],
      "@value with @direction" => [
        "foo",
        %{"literal" => "foo", "direction" => "rtl"},
        %{"@value" => "foo", "@direction" => "rtl"}
      ],
      "@value with @language and @direction" => [
        "foo",
        %{"literal" => "foo", "language" => "en", "direction" => "ltr"},
        %{"@value" => "foo", "@language" => "en", "@direction" => "ltr"}
      ]
    }
    |> Enum.each(fn {title, data} ->
      @tag data: data
      test title, %{data: [key, compacted, expanded], example_context: context, options: options} do
        assert compact_value(expanded, context, key, options) == compacted
      end
    end)
  end
end
