[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: [{:assert_raise_json_ld_error, 2}, {:assert_raise_json_ld_error, 3}],
  import_deps: [:rdf]
]
