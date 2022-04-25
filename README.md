<img style="border:0px;" width="64" src="https://json-ld.org/images/json-ld-logo-64.png" alt="JSON-LD-logo-64" align="right"/>

# JSON-LD.ex

[![CI](https://github.com/rdf-elixir/jsonld-ex/workflows/CI/badge.svg?branch=master)](https://github.com/rdf-elixir/jsonld-ex/actions?query=branch%3Amaster+workflow%3ACI)
[![Hex.pm](https://img.shields.io/hexpm/v/json_ld.svg?style=flat-square)](https://hex.pm/packages/json_ld)
[![Coverage Status](https://coveralls.io/repos/github/rdf-elixir/jsonld-ex/badge.svg?branch=master)](https://coveralls.io/github/rdf-elixir/jsonld-ex?branch=master)


An implementation of the [JSON-LD] standard for Elixir and [RDF.ex].

The API documentation can be found [here](https://hexdocs.pm/json_ld/). For a guide and more information about RDF.ex and it's related projects, go to <https://rdf-elixir.dev>.


## Features

- fully conforming JSON-LD API processor
- JSON-LD reader/writer for [RDF.ex]
- tests of the [JSON-LD test suite][] (see [here](https://github.com/rdf-elixir/jsonld-ex/wiki/JSON-LD.ex-implementation-report) for a detailed status report)


## TODO

- [JSON-LD Framing]
- [JSON-LD 1.1] support


## Installation

The [JSON-LD.ex](https://hex.pm/packages/json_ld) Hex package can be installed as usual, by adding `json_ld` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:json_ld, "~> 0.3"}]
end
```


## Usage


### Expand a document

```elixir
"""
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
|> Jason.decode!
|> JSON.LD.expand
```

produces

```elixir
[%{"http://xmlns.com/foaf/0.1/homepage" => [%{"@id" => "http://manu.sporny.org/"}],
   "http://xmlns.com/foaf/0.1/name" => [%{"@value" => "Manu Sporny"}]}]
```

### Compact a document

```elixir
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

"""
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
|> Jason.decode!
|> JSON.LD.compact(context)
```

produces 

```elixir
%{"@context" => %{
    "homepage" => %{
        "@id" => "http://xmlns.com/foaf/0.1/homepage", 
        "@type" => "@id"},
    "name" => "http://xmlns.com/foaf/0.1/name"
    },
  "homepage" => "http://manu.sporny.org/", 
  "name" => "Manu Sporny"}
```


## RDF Reader and Writer

JSON-LD.ex can be used to serialize or deserialize RDF graphs by using it as a RDF.ex reader and writer.

```elixir
dataset = JSON.LD.read_file!("file.jsonld")
JSON.LD.write_file!(dataset, "file.jsonld")
```

When a context is provided via the `:context` option (as a map, a `RDF.PropertyMap` or a string with a URL to a remote context), the document gets automatically compacted on serialization.

```elixir
JSON.LD.write_file!(dataset, "file.jsonld", context: %{ex: "https://example.com/"})
JSON.LD.write_file!(dataset, "file.jsonld", context: "https://schema.org/")
```

## Pretty printing

Pretty printing is possible on all writer functions with all the formatter options of [Jason](https://hexdocs.pm/jason/Jason.Formatter.html#pretty_print/2), the underlying JSON encoder, to which the given options are passed through.

```elixir
JSON.LD.write_file!(dataset, "file.jsonld", pretty: true)
JSON.LD.write_string(dataset, "file.jsonld", pretty: [indent: "\t"])
```


## Contributing

see [CONTRIBUTING](CONTRIBUTING.md) for details.


## Consulting

If you need help with your Elixir and Linked Data projects, just contact [NinjaConcept](https://www.ninjaconcept.com/) via <contact@ninjaconcept.com>.


## License and Copyright

(c) 2017-present Marcel Otto. MIT Licensed, see [LICENSE](LICENSE.md) for details.


[RDF.ex]:             https://hex.pm/packages/rdf
[JSON-LD]:            http://www.w3.org/TR/json-ld/ "JSON-LD 1.0"
[JSON-LD 1.1]:        https://json-ld.org/spec/latest/json-ld/ "JSON-LD 1.1"
[JSON-LD API]:        http://www.w3.org/TR/json-ld-api/ "JSON-LD 1.0 Processing Algorithms and API"
[JSON-LD Framing]:    http://json-ld.org/spec/latest/json-ld-framing/
[JSON-LD test suite]: http://json-ld.org/test-suite/



