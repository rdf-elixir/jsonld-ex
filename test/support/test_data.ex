defmodule JSON.LD.TestData do
  @moduledoc """
  Helpers to access test data.
  """

  @dir Path.join(File.cwd!(), "test/data/")
  def dir, do: @dir

  def file(name) do
    if File.exists?(path = Path.join(@dir, name)) do
      path
    else
      raise "Test data file '#{name}' not found"
    end
  end
end
