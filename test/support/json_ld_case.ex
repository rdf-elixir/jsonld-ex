defmodule JSON.LD.Case do
  @moduledoc """
  Common `ExUnit.CaseTemplate` for JSON-LD tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias RDF.{
        Dataset,
        Graph,
        Description,
        IRI,
        BlankNode,
        Literal,
        XSD,
        PrefixMap,
        PropertyMap,
        NS
      }

      alias RDF.NS.{RDFS, XSD}
      alias JSON.LD.TestVocabularyNamespaces.{EX, S, FOAF}

      @compile {:no_warn_undefined, JSON.LD.TestVocabularyNamespaces.EX}
      @compile {:no_warn_undefined, JSON.LD.TestVocabularyNamespaces.S}
      @compile {:no_warn_undefined, JSON.LD.TestVocabularyNamespaces.FOAF}

      import RDF.Namespace.IRI
      import RDF.Sigils
      import RDF.Test.Assertions

      import unquote(__MODULE__)
    end
  end

  def context_with_inverse(context) do
    context
    |> JSON.LD.context()
    |> JSON.LD.Context.set_inverse()
  end
end
