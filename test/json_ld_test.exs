defmodule JSON.LDTest do
  use ExUnit.Case
  doctest JSON.LD

  describe "compact_iri_parts" do
    test "returns the prefix and suffix of a compact IRI" do
      assert JSON.LD.compact_iri_parts("foo:bar") == ["foo", "bar"]
    end

    test "returns nil on absolute IRIs" do
      assert JSON.LD.compact_iri_parts("http://example.com/") == nil
    end

    test "returns nil on blank nodes" do
      assert JSON.LD.compact_iri_parts("_:bar") == nil
    end
  end

end
