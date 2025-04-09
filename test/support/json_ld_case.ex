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

  def assert_raise_json_ld_error(code, fun) do
    try do
      fun.()
    rescue
      error ->
        case error do
          %JSON.LD.Error{code: ^code} ->
            error

          %JSON.LD.Error{code: unexpected_code} ->
            message =
              "Expected JSON.LD.Error exception with code #{inspect(code)} " <>
                "but got JSON.LD.Error with code #{inspect(unexpected_code)} (#{Exception.message(error)})"

            reraise ExUnit.AssertionError, [message: message], __STACKTRACE__

          %ExUnit.AssertionError{} ->
            reraise(error, __STACKTRACE__)

          _ ->
            message =
              "Expected JSON.LD.Error exception with code #{inspect(code)} " <>
                "but got #{inspect(error.__struct__)} (#{Exception.message(error)})"

            reraise ExUnit.AssertionError, [message: message], __STACKTRACE__
        end
    else
      _ -> flunk("Expected exception JSON.LD.Error with code #{code} but nothing was raised")
    end
  end

  def assert_raise_json_ld_error(code, message, fun) do
    error = assert_raise_json_ld_error(code, fun)

    match? =
      cond do
        is_binary(message) -> error.message == message
        is_struct(message, Regex) -> error.message =~ message
      end

    message =
      "Wrong message for JSON.LD.Error exception with code #{inspect(code)}:\n" <>
        "expected:\n  #{inspect(message)}\n" <>
        "actual:\n" <> "  #{inspect(error.message)}"

    if not match?, do: flunk(message)

    error
  end
end
