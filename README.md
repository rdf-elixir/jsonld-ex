# JSON-LD.ex

An implementation of the [JSON-LD] standard for Elixir and [RDF.ex].


## Features

- fully conforming JSON-LD API processor
- JSON-LD reader/writer for [RDF.ex]
- tests of the [JSON-LD test suite][] (see [here](https://github.com/marcelotto/jsonld-ex/wiki/JSON-LD-status-report) for a detailed status report)


## TODO

- remote contexts
- [JSON-LD Framing]
- [JSON-LD 1.1] support


## Installation

[JSON-LD.ex](https://hex.pm/packages/json_ld) can be installed as usual:

1. Add `json_ld` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:json_ld, "~> 0.1.0"}]
end
```

2. Ensure `rdf` is started before your application:

```elixir
def application do
  [applications: [:json_ld]]
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
|> Poison.Parser.parse!
|> JSON.LD.expand
```

produces

```elixir
[%{"http://xmlns.com/foaf/0.1/homepage" => [%{"@id" => "http://manu.sporny.org/"}],
   "http://xmlns.com/foaf/0.1/name" => [%{"@value" => "Manu Sporny"}]}]
```

### Compact a document

```elixir
context = Poison.Parser.parse! """
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
|> Poison.Parser.parse!
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


## Getting help

- [Documentation](http://hexdocs.pm/json_ld)
- [Google Group](https://groups.google.com/d/forum/rdfex)


## Contributing

see [CONTRIBUTING](CONTRIBUTING.md) for details.


## License and Copyright

(c) 2017 Marcel Otto. MIT Licensed, see [LICENSE](LICENSE.md) for details.


[RDF.ex]:             https://hex.pm/packages/rdf
[JSON-LD]:            http://www.w3.org/TR/json-ld/ "JSON-LD 1.0"
[JSON-LD 1.1]:        https://json-ld.org/spec/latest/json-ld/ "JSON-LD 1.1"
[JSON-LD API]:        http://www.w3.org/TR/json-ld-api/ "JSON-LD 1.0 Processing Algorithms and API"
[JSON-LD Framing]:    http://json-ld.org/spec/latest/json-ld-framing/
[JSON-LD test suite]: http://json-ld.org/test-suite/



