#!/usr/bin/env elixir

# Test script to compare IO.getn/2 vs :io.get_chars/2
# Run with: elixir test_io_comparison.exs

defmodule IOComparison do
  @moduledoc """
  Comparison of Elixir's IO module vs Erlang's :io module for character input.
  """

  def test_io_getn do
    IO.puts("\n=== Testing IO.getn/2 ===")
    IO.puts("Current process: #{inspect(self())}")
    IO.puts("Group leader: #{inspect(Process.group_leader())}")
    IO.puts("IO server options: #{inspect(:io.getopts())}")

    IO.puts("\nCalling IO.getn(\"\", 1) - press a key...")
    result = IO.getn("", 1)
    IO.puts("Result: #{inspect(result)} (type: #{typeof(result)})")
    IO.puts("Result as binary: #{is_binary(result)}")
  end

  def test_io_get_chars do
    IO.puts("\n=== Testing :io.get_chars/2 ===")
    IO.puts("Current process: #{inspect(self())}")
    IO.puts("Group leader: #{inspect(Process.group_leader())}")
    IO.puts("IO server options: #{inspect(:io.getopts())}")

    IO.puts("\nCalling :io.get_chars(\"\", 1) - press a key...")
    result = :io.get_chars("", 1)
    IO.puts("Result: #{inspect(result)} (type: #{typeof(result)})")
    IO.puts("Result is list: #{is_list(result)}")

    # Convert charlist to binary if needed
    if is_list(result) do
      converted = :unicode.characters_to_binary(result)
      IO.puts("Converted to binary: #{inspect(converted)}")
    end
  end

  def test_io_setopts do
    IO.puts("\n=== Testing :io.setopts/2 ===")
    original = :io.getopts()
    IO.puts("Original options: #{inspect(original)}")

    IO.puts("\nSetting echo: false, binary: false")
    :io.setopts(echo: false, binary: false)

    new_opts = :io.getopts()
    IO.puts("New options: #{inspect(new_opts)}")

    # Restore
    :io.setopts(original)
    IO.puts("Restored options: #{inspect(:io.getopts())}")
  end

  defp typeof(term) when is_binary(term), do: "binary"
  defp typeof(term) when is_list(term), do: "list/charlist"
  defp typeof(term) when is_integer(term), do: "integer"
  defp typeof(_term), do: "unknown"
end

# Run tests if executed directly
IO.puts("IO Comparison Test")
IO.puts("==================")

# Test 1: IO.getn
IOComparison.test_io_getn()

# Test 2: :io.get_chars
IOComparison.test_io_get_chars()

# Test 3: :io.setopts
IOComparison.test_io_setopts()
