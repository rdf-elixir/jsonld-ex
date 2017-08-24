defmodule JSON.LD.ValueCompactionTest do
  use ExUnit.Case, async: false

  import JSON.LD.Compaction, only: [compact_value: 4]

  alias RDF.NS.{XSD}

  setup do
    context = JSON.LD.context(%{
        "dc"         => "http://purl.org/dc/terms/",   # TODO: RDF::Vocab::DC.to_uri.to_s,
        "ex"         => "http://example.org/",
        "foaf"       => "http://xmlns.com/foaf/0.1/",  # TODO: RDF::Vocab::FOAF.to_uri.to_s,
        "xsd"        => to_string(XSD.__base_iri__),
        "langmap"    => %{"@id" => "http://example.com/langmap", "@container" => "@language"},
        "list"       => %{"@id" => "http://example.org/list", "@container" => "@list"},
        "nolang"     => %{"@id" => "http://example.org/nolang", "@language" => nil},
        "dc:created" => %{"@type" => to_string(XSD.date)},
        "foaf:age"   => %{"@type" => to_string(XSD.integer)},
        "foaf:knows" => %{"@type" => "@id"},
      })
    %{example_context: context, inverse_context: JSON.LD.Context.inverse(context)}
  end

  %{
    "absolute IRI" =>   ["foaf:knows",  "http://example.com/",  %{"@id" => "http://example.com/"}],
    "prefix:suffix" =>  ["foaf:knows",  "ex:suffix",            %{"@id" => "http://example.org/suffix"}],
    "integer" =>        ["foaf:age",    "54",                   %{"@value" => "54", "@type" => to_string(XSD.integer)}],
    "date " =>          ["dc:created",  "2011-12-27Z",          %{"@value" => "2011-12-27Z", "@type" => to_string(XSD.date)}],
    "no IRI" =>         ["foo", %{"@id" => "http://example.com/"}, %{"@id" => "http://example.com/"}],
    "no IRI (CURIE)" => ["foo", %{"@id" => "http://xmlns.com/foaf/0.1/Person"},       %{"@id" => "http://xmlns.com/foaf/0.1/Person"}],
    "no boolean" =>     ["foo", %{"@value" => "true", "@type" => to_string(XSD.boolean)},%{"@value" => "true", "@type" => to_string(XSD.boolean)}],
    "no integer" =>     ["foo", %{"@value" => "54", "@type" => to_string(XSD.integer)},%{"@value" => "54", "@type" => to_string(XSD.integer)}],
    "no date " =>       ["foo", %{"@value" => "2011-12-27Z", "@type" => to_string(XSD.date)}, %{"@value" => "2011-12-27Z", "@type" => to_string(XSD.date)}],
    "no string " =>     ["foo", "string",                       %{"@value" => "string"}],
    "no lang " =>       ["nolang", "string",                    %{"@value" => "string"}],
    "native boolean" => ["foo", true,                           %{"@value" => true}],
    "native integer" => ["foo", 1,                              %{"@value" => 1}],
    "native integer(list)"=>["list", 1,                         %{"@value" => 1}],
    "native double" =>  ["foo", 1.1e1,                          %{"@value" => 1.1E1}],
  }
  |> Enum.each(fn ({title, data}) ->
       @tag data: data
       test title, %{data: [key, compacted, expanded], example_context: context,
                                                       inverse_context: inverse_context} do
         assert compact_value(expanded, context, inverse_context, key) == compacted
       end
     end)

  describe "@language" do
    setup %{example_context: context} do
      context = %JSON.LD.Context{context | default_language: "en"}
      %{example_context: context, inverse_context: JSON.LD.Context.inverse(context)}
    end

    %{
      "@id"                            => ["foo", %{"@id" => "foo"},                                 %{"@id" => "foo"}],
      "integer"                        => ["foo", %{"@value" => "54", "@type" => to_string(XSD.integer)},     %{"@value" => "54", "@type" => to_string(XSD.integer)}],
      "date"                           => ["foo", %{"@value" => "2011-12-27Z","@type" => to_string(XSD.date)},%{"@value" => "2011-12-27Z", "@type" => to_string(XSD.date)}],
      "no lang"                        => ["foo", %{"@value" => "foo" },                             %{"@value" => "foo"}],
      "same lang"                      => ["foo", "foo",                                             %{"@value" => "foo", "@language" => "en"}],
      "other lang"                     => ["foo", %{"@value" => "foo", "@language" => "bar"},        %{"@value" => "foo", "@language" => "bar"}],
      "langmap"                        => ["langmap", "en",                                          %{"@value" => "en", "@language" => "en"}],
      "no lang with @type coercion"    => ["dc:created", %{"@value" => "foo"},                       %{"@value" => "foo"}],
      "no lang with @id coercion"      => ["foaf:knows", %{"@value" => "foo"},                       %{"@value" => "foo"}],
      "no lang with @language=null"    => ["nolang", "string",                                       %{"@value" => "string"}],
      "same lang with @type coercion"  => ["dc:created", %{"@value" => "foo"},                       %{"@value" => "foo"}],
      "same lang with @id coercion"    => ["foaf:knows", %{"@value" => "foo"},                       %{"@value" => "foo"}],
      "other lang with @type coercion" => ["dc:created", %{"@value" => "foo", "@language" => "bar"}, %{"@value" => "foo", "@language" => "bar"}],
      "other lang with @id coercion"   => ["foaf:knows", %{"@value" => "foo", "@language" => "bar"}, %{"@value" => "foo", "@language" => "bar"}],
      "native boolean"                 => ["foo", true,                                              %{"@value" => true}],
      "native integer"                 => ["foo", 1,                                                 %{"@value" => 1}],
      "native integer(list)"           => ["list", 1,                                                %{"@value" => 1}],
      "native double"                  => ["foo", 1.1e1,                                             %{"@value" => 1.1E1}],
    }
    |> Enum.each(fn ({title, data}) ->
         @tag data: data
         test title, %{data: [key, compacted, expanded], example_context: context,
                                                         inverse_context: inverse_context} do
           assert compact_value(expanded, context, inverse_context, key) == compacted
         end
       end)
  end

# TODO
#  describe "keywords" do
#    before(:each) do
#      subject.set_mapping("id", "@id")
#      subject.set_mapping("type", "@type")
#      subject.set_mapping("list", "@list")
#      subject.set_mapping("set", "@set")
#      subject.set_mapping("language", "@language")
#      subject.set_mapping("literal", "@value")
#    end
#
#    %{
#      "@id" =>      [%{"id" => "http://example.com/"},             %{"@id" => "http://example.com/"}],
#      "@type" =>    [%{"literal" => "foo", "type" => "http://example.com/"},
#                                                                  %{"@value" => "foo", "@type" => "http://example.com/"}],
#      "@value" =>   [%{"literal" => "foo", "language" => "bar"},   %{"@value" => "foo", "@language" => "bar"}],
#    }.each do |title, (compacted, expanded)|
#      test title do
#        expect(subject.compact_value("foo", expanded)).to produce(compacted, logger)
#      end
#    end
#  end

end
