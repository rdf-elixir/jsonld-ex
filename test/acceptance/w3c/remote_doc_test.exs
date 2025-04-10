# The remote document tests are skipped when running the test suite in remote mode, because
# the hosted test files don't behave as specified in the manifest.
if JSON.LD.TestSuite.run_mode() == :remote do
  IO.puts("Skipping remote document tests")
else
  defmodule JSON.LD.W3C.RemoteDocTest do
    @moduledoc """
    The official W3C JSON.LD 1.1 Test Suite for the _Remote Document and Context Retrieval_.

    See <https://w3c.github.io/json-ld-api/tests/remote-doc-manifest.html>.
    """

    use ExUnit.Case, async: false
    use RDF.Test.EarlFormatter, test_suite: :"json-ld-api"

    import JSON.LD.TestSuite
    import JSON.LD.Case
    import Tesla.Test

    @test_suite_name "remote-doc"
    @manifest manifest(@test_suite_name)
    @base expanded_base_iri(@manifest)

    setup do
      Mox.verify_on_exit!()

      original_adapter = Application.get_env(:tesla, :adapter)
      Application.put_env(:tesla, :adapter, JSON.LD.MockAdapter)

      on_exit(fn ->
        Application.put_env(:tesla, :adapter, original_adapter)
      end)

      :ok
    end

    @manifest
    |> test_cases()
    |> test_cases_by_type()
    |> Enum.each(fn
      {:positive_evaluation_test, test_cases} ->
        for %{"@id" => id, "name" => name} = test_case <- test_cases do
          if id in ["#t0013"] do
            @tag skip: "missing HTML support"
          end

          skip_json_ld_1_0_test(test_case)
          @tag :test_suite
          @tag :remote_doc_test_suite
          @tag test_case: RDF.iri(@base <> @test_suite_name <> "-manifest" <> id)
          @tag data: test_case
          test "remote-doc#{id}: #{name}", %{
            data: %{"input" => input, "expect" => expected} = test_case
          } do
            setup_tesla_expectations(test_case)

            input = absolute_url(input)
            assert JSON.LD.expand(input, test_case_options(test_case)) == j(expected)
          end
        end

      {:negative_evaluation_test, test_cases} ->
        for %{"@id" => id, "name" => name} = test_case <- test_cases do
          skip_json_ld_1_0_test(test_case)
          @tag :test_suite
          @tag :remote_doc_test_suite
          @tag test_case: RDF.iri(@base <> @test_suite_name <> "-manifest" <> id)
          @tag data: test_case
          test "remote-doc#{id}: #{name}", %{
            data: %{"input" => input, "expectErrorCode" => error} = test_case
          } do
            setup_tesla_expectations(test_case)

            input = absolute_url(input)

            assert_raise_json_ld_error error, fn ->
              JSON.LD.expand(input, test_case_options(test_case, @base))
            end
          end
        end
    end)

    defp setup_tesla_expectations(test_case) do
      options = Map.get(test_case, "option", %{})
      input = test_case["input"]
      abs_input = absolute_url(input)

      cond do
        String.contains?(input, "missing") ->
          expect_tesla_call(
            times: 1,
            returns: %Tesla.Env{status: 404, body: "Not found", url: input, method: :get}
          )

        redirect_to = options["redirectTo"] ->
          redirect_url = absolute_url(redirect_to)
          status = options["httpStatus"]

          expect_tesla_call(
            times: 1,
            returns: fn _env, _opts ->
              {:ok,
               %Tesla.Env{
                 url: abs_input,
                 method: :get,
                 status: status,
                 headers: [{"location", redirect_url}],
                 body: ""
               }}
            end
          )

          expect_tesla_call(
            times: 1,
            returns: fn _env, _opts ->
              {:ok,
               %Tesla.Env{
                 url: redirect_url,
                 method: :get,
                 status: 200,
                 headers: [{"content-type", content_type_for_file(redirect_to, %{})}],
                 body: test_file_content(redirect_to)
               }}
            end
          )

        is_binary(options["httpLink"]) &&
          String.contains?(options["httpLink"], "rel=\"http://www.w3.org/ns/json-ld#context\"") &&
            content_type_for_file(input, options) != "application/ld+json" ->
          expect_tesla_call(
            times: 1,
            returns: fn _env, _opts ->
              {:ok,
               %Tesla.Env{
                 url: abs_input,
                 method: :get,
                 status: 200,
                 headers: [
                   {"content-type", content_type_for_file(input, options)},
                   {"link", options["httpLink"]}
                 ],
                 body: test_file_content(input)
               }}
            end
          )

          context_file = Regex.run(~r/<([^>]*)>/, options["httpLink"]) |> List.last()

          expect_tesla_call(
            times: 1,
            returns: fn _env, _opts ->
              {:ok,
               %Tesla.Env{
                 url: URI.merge(abs_input, context_file) |> to_string(),
                 method: :get,
                 status: 200,
                 headers: [{"content-type", "application/ld+json"}],
                 body: input |> Path.dirname() |> Path.join(context_file) |> test_file_content()
               }}
            end
          )

        is_binary(options["httpLink"]) &&
          String.contains?(options["httpLink"], "alternate") &&
            content_type_for_file(input, options) == "text/html" ->
          expect_tesla_call(
            times: 1,
            returns: fn _env, _opts ->
              {:ok,
               %Tesla.Env{
                 url: abs_input,
                 method: :get,
                 status: 200,
                 headers: [
                   {"content-type", "text/html"},
                   {"link", options["httpLink"]}
                 ],
                 body: test_file_content(input)
               }}
            end
          )

          alternate_link = Regex.run(~r/<([^>]*)>/, options["httpLink"]) |> List.last()

          expect_tesla_call(
            times: 1,
            returns: fn _env, _opts ->
              {:ok,
               %Tesla.Env{
                 url: URI.merge(abs_input, alternate_link) |> to_string(),
                 method: :get,
                 status: 200,
                 headers: [{"content-type", "application/ld+json"}],
                 body: input |> Path.dirname() |> Path.join(alternate_link) |> test_file_content()
               }}
            end
          )

        true ->
          headers = [{"content-type", content_type_for_file(input, options)}]

          headers =
            case options["httpLink"] do
              links when is_list(links) ->
                Enum.reduce(links, headers, fn link, acc ->
                  [{"link", link} | acc]
                end)

              link when is_binary(link) ->
                [{"link", link} | headers]

              _ ->
                headers
            end

          expect_tesla_call(
            times: 1,
            returns: fn _env, _opts ->
              {:ok,
               %Tesla.Env{
                 url: abs_input,
                 method: :get,
                 status: 200,
                 headers: headers,
                 body: test_file_content(input)
               }}
            end
          )
      end
    end

    defp test_file_content(filename) do
      filename
      |> file()
      |> File.read!()
    end

    defp content_type_for_file(filename, options) do
      options["contentType"] ||
        case Path.extname(filename) do
          ".jsonld" -> "application/ld+json"
          ".json" -> "application/json"
          ".jldt" -> "application/jldTest+json"
          ".jldte" -> "application/jldTest"
          ".html" -> "text/html"
          _ -> "application/octet-stream"
        end
    end

    defp absolute_url(url) do
      if URI.parse(url).scheme do
        url
      else
        @base |> URI.parse() |> URI.merge(url) |> URI.to_string()
      end
    end
  end
end
