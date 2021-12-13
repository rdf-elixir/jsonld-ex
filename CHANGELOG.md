# Change Log

All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/) and
[Keep a CHANGELOG](http://keepachangelog.com).


## 0.3.4 - 2021-12-13

Elixir versions < 1.10 are no longer supported

### Fixed

- remote contexts with a list couldn't be processed correctly (but failed with a `JSON.LD.InvalidLocalContextError`)

[Compare v0.3.3...v0.3.4](https://github.com/rdf-elixir/jsonld-ex/compare/v0.3.3...v0.3.4)



## 0.3.3 - 2020-10-13

This version mainly upgrades to RDF.ex 0.9.
 
### Added

- proper typespecs so that Dialyzer passes without warnings ([@rustra](https://github.com/rustra))

[Compare v0.3.2...v0.3.3](https://github.com/rdf-elixir/jsonld-ex/compare/v0.3.2...v0.3.3)



## 0.3.2 - 2020-06-19

### Added

Support for remote contexts ([@KokaKiwi](https://github.com/KokaKiwi) and [@rustra](https://github.com/rustra))

[Compare v0.3.1...v0.3.2](https://github.com/rdf-elixir/jsonld-ex/compare/v0.3.1...v0.3.2)



## 0.3.1 - 2020-06-01

This version just upgrades to RDF.ex 0.8. With that Elixir version < 1.8 are no longer supported.

[Compare v0.3.0...v0.3.1](https://github.com/rdf-elixir/jsonld-ex/compare/v0.3.0...v0.3.1)



## 0.3.0 - 2018-09-17

No significant changes. Just some adoptions to work with RDF.ex 0.5. 
But together with RDF.ex 0.5, Elixir versions < 1.6 are no longer supported.

[Compare v0.2.3...v0.3.0](https://github.com/rdf-elixir/jsonld-ex/compare/v0.2.3...v0.3.0)



## 0.2.3 - 2018-07-11

- Upgrade to Jason 1.1
- Pass options to `JSON.LD.Encoder.encode/2` and `JSON.LD.Encoder.encode!/2` 
  through to Jason; this allows to use the new Jason pretty printing options  

[Compare v0.2.2...v0.2.3](https://github.com/rdf-elixir/jsonld-ex/compare/v0.2.2...v0.2.3)



## 0.2.2 - 2018-03-17

### Added

- JSON-LD encoder can handle `RDF.Graph`s and `RDF.Description`s 

### Changed

- Use Jason instead of Poison for JSON encoding and decoding, since it's faster and more standard conform


[Compare v0.2.1...v0.2.2](https://github.com/rdf-elixir/jsonld-ex/compare/v0.2.1...v0.2.2)



## 0.2.1 - 2018-03-10

### Changed

- Upgrade to RDF.ex 0.4.0
- Fixed all warnings ([@talklittle](https://github.com/talklittle)) 


[Compare v0.2.0...v0.2.1](https://github.com/rdf-elixir/jsonld-ex/compare/v0.2.0...v0.2.1)



## 0.2.0 - 2017-08-24

### Changed

- Upgrade to RDF.ex 0.3.0


[Compare v0.1.1...v0.2.0](https://github.com/rdf-elixir/jsonld-ex/compare/v0.1.1...v0.2.0)



## 0.1.1 - 2017-08-06

### Changed

- Don't support Elixir versions < 1.5, since `URI.merge` is broken in earlier versions  


[Compare v0.1.0...v0.1.1](https://github.com/rdf-elixir/jsonld-ex/compare/v0.1.0...v0.1.1)



## 0.1.0 - 2017-06-25

Initial release
