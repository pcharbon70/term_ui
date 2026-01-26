#!/usr/bin/env elixir

"""
IEx Input Test Script

To run this inside IEx:
1. Start IEx: iex -S mix
2. Run: c "notes/features/test_iex_input.exs"
3. Run: IExInputTest.run()

This will test whether input goes to the application or to IEx.
"""

defmodule IExInputTest do
  @moduledoc """
  Test input handling inside IEx to determine if input is stolen by IEx.
  """

  @timeout 5000

  def run do
    IO.puts("\n=== IEx Input Test ===")
    IO.puts("This test will check if keyboard input is captured by IEx")
    IO.puts("or by the application.\n")

    test_io_getn()
    test_io_get_chars()
    test_with_separate_process()

    IO.puts("\n=== Test Complete ===")
    IO.puts("\nIf you saw characters echoed as you typed:")
    IO.puts("  - IO.getn likely works (input went to IEx)")
    IO.puts("\nIf characters appeared only after pressing Enter:")
    IO.puts("  - Input went to the application first, then IEx displayed it")
  end

  def test_io_getn do
    IO.puts("\n--- Test 1: IO.getn/2 ---")
    IO.puts("Press 'a' key (should be echoed immediately by IEx if it works)...")

    start_time = System.monotonic_time(:millisecond)

    # Try to read with timeout
    task = Task.async(fn -> IO.getn("", 1) end)

    case Task.yield(task, @timeout) do
      {:ok, result} ->
        elapsed = System.monotonic_time(:millisecond) - start_time
        IO.puts("IO.getn result: #{inspect(result)} (took #{elapsed}ms)")
        IO.puts("Type: #{get_type(result)}")

      nil ->
        Task.shutdown(task)
        elapsed = System.monotonic_time(:millisecond) - start_time
        IO.puts("IO.getn timed out after #{elapsed}ms (input likely went to IEx)")
    end
  end

  def test_io_get_chars do
    IO.puts("\n--- Test 2: :io.get_chars/2 ---")
    IO.puts("Press 'b' key...")

    start_time = System.monotonic_time(:millisecond)

    task = Task.async(fn -> :io.get_chars("", 1) end)

    case Task.yield(task, @timeout) do
      {:ok, result} ->
        elapsed = System.monotonic_time(:millisecond) - start_time
        IO.puts(":io.get_chars result: #{inspect(result)} (took #{elapsed}ms)")
        IO.puts("Type: #{get_type(result)}")

        # Try to convert charlist to binary
        if is_list(result) do
          converted = :unicode.characters_to_binary(result)
          IO.puts("Converted to binary: #{inspect(converted)}")
        end

      nil ->
        Task.shutdown(task)
        elapsed = System.monotonic_time(:millisecond) - start_time
        IO.puts(":io.get_chars timed out after #{elapsed}ms (input likely went to IEx)")
    end
  end

  def test_with_separate_process do
    IO.puts("\n--- Test 3: Separate Process (snake_test pattern) ---")
    IO.puts("This mimics the snake_test approach with a spawned process.")
    IO.puts("Press 'c' key...")

    parent = self()

    # Spawn a separate process like snake_test does
    pid = spawn(fn ->
      receive do
      after
        0 ->
          # Try to read input
          case :io.get_chars("", 1) do
            data when is_list(data) ->
              send(parent, {:input, :io_get_chars, data})

            :eof ->
              send(parent, {:input, :eof})

            other ->
              send(parent, {:input, :error, other})
          end
      end
    end)

    start_time = System.monotonic_time(:millisecond)

    receive do
      {:input, :io_get_chars, data} ->
        elapsed = System.monotonic_time(:millisecond) - start_time
        IO.puts("Received from separate process: #{inspect(data)} (took #{elapsed}ms)")
        IO.puts("Type: #{get_type(data)}")

      {:input, :eof} ->
        IO.puts("Got EOF from separate process")

      {:input, :error, reason} ->
        IO.puts("Error from separate process: #{inspect(reason)}")
    after
      @timeout ->
        Process.exit(pid, :kill)
        elapsed = System.monotonic_time(:millisecond) - start_time
        IO.puts("Separate process timed out after #{elapsed}ms (input likely went to IEx)")
    end
  end

  defp get_type(term) when is_binary(term), do: "binary"
  defp get_type(term) when is_list(term), do: "charlist"
  defp get_type(term) when is_integer(term), do: "integer"
  defp get_type(_term), do: "unknown: #{inspect(_term)}"
end

# Export for use in IEx
defmodule IExInputTestHelper do
  defdelegate run, to: IExInputTest
end
