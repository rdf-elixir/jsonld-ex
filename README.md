<img style="border:0px;" width="64" src="https://json-ld.org/images/json-ld-logo-64.png" alt="JSON-LD-logo-64" align="right"/>

# JSON-LD.ex

[![Hex.pm](https://img.shields.io/hexpm/v/json_ld.svg?style=flat-square)](https://hex.pm/packages/json_ld)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/json_ld/)
[![Coverage Status](https://coveralls.io/repos/github/rdf-elixir/jsonld-ex/badge.svg?branch=master)](https://coveralls.io/github/rdf-elixir/jsonld-ex?branch=master)
[![Total Download](https://img.shields.io/hexpm/dt/json_ld.svg)](https://hex.pm/packages/json_ld)
[![License](https://img.shields.io/hexpm/l/json_ld.svg)](https://github.com/rdf-elixir/jsonld-ex/blob/master/LICENSE.md)

[![ExUnit Tests](https://github.com/rdf-elixir/jsonld-ex/actions/workflows/elixir-build-and-test.yml/badge.svg)](https://github.com/rdf-elixir/jsonld-ex/actions/workflows/elixir-build-and-test.yml)
[![Dialyzer](https://github.com/rdf-elixir/jsonld-ex/actions/workflows/elixir-dialyzer.yml/badge.svg)](https://github.com/rdf-elixir/jsonld-ex/actions/workflows/elixir-dialyzer.yml)
[![Quality Checks](https://github.com/rdf-elixir/jsonld-ex/actions/workflows/elixir-quality-checks.yml/badge.svg)](https://github.com/rdf-elixir/jsonld-ex/actions/workflows/elixir-quality-checks.yml)


An implementation of the [JSON-LD 1.1] standard for Elixir and [RDF.ex].

The API documentation can be found [here](https://hexdocs.pm/json_ld/). For a guide and more information about RDF.ex and it's related projects, go to <https://rdf-elixir.dev>.


## Features

- fully conforming JSON-LD 1.1 API processor
- JSON-LD reader/writer for [RDF.ex]
- customizable HTTP client for remote document loading
- tests of the [JSON-LD test suite] (see [here](https://github.com/rdf-elixir/jsonld-ex/tree/master/earl_reports) for the EARL reports)


## TODO

- [JSON-LD Framing]
- [JSON-LD HTML Content Algorithms]


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


## Acknowledgements

<table style="border: 0;">
<tr>
<td><a href="https://nlnet.nl/"><img src="https://nlnet.nl/logo/banner.svg" alt="NLnet Foundation Logo" width="150"></a></td>
<td><a href="https://nlnet.nl/commonsfund/" ><img src="https://nlnet.nl/logo/NGI/NGIZero-green.hex.svg" alt="NGI0 Logo" height="150"></a></td>  
<td><a href="https://www.jetbrains.com/?from=RDF.ex"><img src="https://resources.jetbrains.com/storage/products/company/brand/logos/jb_beam.svg" alt="JetBrains Logo" height="150"></a></td>
</tr>
</table>

This project is partly funded through [NGI0 Commons Fund](https://nlnet.nl/commonsfund/), a fund established by [NLnet](https://nlnet.nl/) with financial support from the European Commission's [Next Generation Internet](https://ngi.eu/) program.

[JetBrains](https://www.jetbrains.com/?from=RDF.ex) supports the project with complimentary access to its development environments.


## License and Copyright

(c) 2017-present Marcel Otto. MIT Licensed, see [LICENSE](LICENSE.md) for details.


[RDF.ex]:             https://hex.pm/packages/rdf
[JSON-LD 1.1]:        https://www.w3.org/TR/json-ld11/ "JSON-LD 1.1"
[JSON-LD API]:        https://www.w3.org/TR/json-ld11-api/ "JSON-LD 1.1 Processing Algorithms and API"
[JSON-LD Framing]:    http://json-ld.org/spec/latest/json-ld-framing/
[JSON-LD test suite]: http://json-ld.org/test-suite/
[JSON-LD HTML Content Algorithms]:    https://www.w3.org/TR/json-ld11-api/#html-content-algorithms



