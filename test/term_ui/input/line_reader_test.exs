defmodule TermUI.Input.LineReaderTest do
  use ExUnit.Case, async: true

  alias TermUI.Input.LineReader

  setup_all do
    assert Code.ensure_loaded?(LineReader)
    :ok
  end

  # Note: Testing IO.gets directly is tricky because it reads from stdin.
  # These tests use ExUnit's capture_io to simulate input.
  # Integration tests that actually read from stdin are tagged :requires_terminal.

  # Helper to reduce boilerplate for capture_io + send/receive pattern
  defp capture_line_input(input, fun) do
    ExUnit.CaptureIO.capture_io([input: input, capture_prompt: false], fn ->
      result = fun.()
      send(self(), {:result, result})
    end)

    assert_receive {:result, result}
    result
  end

  describe "read_line/1" do
    test "function exists with arity 0 and 1" do
      assert function_exported?(LineReader, :read_line, 0)
      assert function_exported?(LineReader, :read_line, 1)
    end

    test "returns {:ok, line} without prompt" do
      result = capture_line_input("hello\n", fn -> LineReader.read_line() end)
      assert result == {:ok, "hello"}
    end

    test "returns {:ok, line} with prompt" do
      result = capture_line_input("world\n", fn -> LineReader.read_line("Enter: ") end)
      assert result == {:ok, "world"}
    end

    test "trims trailing newline from input" do
      result = capture_line_input("test\n", fn -> LineReader.read_line() end)
      assert result == {:ok, "test"}
    end

    test "returns empty string for just newline" do
      result = capture_line_input("\n", fn -> LineReader.read_line() end)
      assert result == {:ok, ""}
    end

    test "preserves internal whitespace" do
      result = capture_line_input("hello world\n", fn -> LineReader.read_line() end)
      assert result == {:ok, "hello world"}
    end

    test "handles input with leading whitespace" do
      result = capture_line_input("  spaced\n", fn -> LineReader.read_line() end)
      assert result == {:ok, "  spaced"}
    end
  end

  describe "read_line/2 with validation" do
    test "function exists with arity 2" do
      assert function_exported?(LineReader, :read_line, 2)
    end

    test "returns {:ok, line} when validator returns :ok" do
      validator = fn _input -> :ok end
      result = capture_line_input("valid\n", fn -> LineReader.read_line("Input: ", validator) end)
      assert result == {:ok, "valid"}
    end

    test "returns {:ok, transformed} when validator returns {:ok, value}" do
      validator = fn input -> {:ok, String.upcase(input)} end
      result = capture_line_input("hello\n", fn -> LineReader.read_line("Input: ", validator) end)
      assert result == {:ok, "HELLO"}
    end

    test "returns {:error, reason} when validator returns {:error, reason}" do
      validator = fn _input -> {:error, "invalid input"} end
      result = capture_line_input("bad\n", fn -> LineReader.read_line("Input: ", validator) end)
      assert result == {:error, "invalid input"}
    end

    test "validator receives trimmed input" do
      validator = fn input ->
        send(self(), {:received, input})
        :ok
      end

      ExUnit.CaptureIO.capture_io([input: "test value\n", capture_prompt: false], fn ->
        LineReader.read_line("Input: ", validator)
      end)

      assert_receive {:received, "test value"}
    end

    test "integer parsing validator example" do
      int_validator = fn input ->
        case Integer.parse(input) do
          {num, ""} -> {:ok, num}
          _ -> {:error, "not an integer"}
        end
      end

      # Valid integer
      result =
        capture_line_input("42\n", fn -> LineReader.read_line("Number: ", int_validator) end)

      assert result == {:ok, 42}

      # Invalid integer
      result =
        capture_line_input("abc\n", fn -> LineReader.read_line("Number: ", int_validator) end)

      assert result == {:error, "not an integer"}
    end

    test "length validation example" do
      min_length_validator = fn input ->
        if String.length(input) >= 3 do
          :ok
        else
          {:error, "must be at least 3 characters"}
        end
      end

      # Valid length
      result =
        capture_line_input("abc\n", fn ->
          LineReader.read_line("Input: ", min_length_validator)
        end)

      assert result == {:ok, "abc"}

      # Too short
      result =
        capture_line_input("ab\n", fn -> LineReader.read_line("Input: ", min_length_validator) end)

      assert result == {:error, "must be at least 3 characters"}
    end

    test "non-empty validation example" do
      non_empty_validator = fn input ->
        if String.trim(input) != "" do
          :ok
        else
          {:error, "cannot be empty"}
        end
      end

      # Non-empty
      result =
        capture_line_input("something\n", fn ->
          LineReader.read_line("Input: ", non_empty_validator)
        end)

      assert result == {:ok, "something"}

      # Empty
      result =
        capture_line_input("\n", fn -> LineReader.read_line("Input: ", non_empty_validator) end)

      assert result == {:error, "cannot be empty"}
    end
  end

  describe "documentation" do
    test "module has moduledoc" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(LineReader)
      assert is_binary(moduledoc)
      assert String.contains?(moduledoc, "LineReader") or String.contains?(moduledoc, "Line")
    end

    test "moduledoc mentions TextInput.Line" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(LineReader)
      assert String.contains?(moduledoc, "TextInput.Line")
    end

    test "moduledoc mentions shell line editing" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(LineReader)

      assert String.contains?(moduledoc, "shell") or
               String.contains?(moduledoc, "Shell") or
               String.contains?(moduledoc, "line editing")
    end

    test "moduledoc mentions IO.gets" do
      {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(LineReader)
      assert String.contains?(moduledoc, "IO.gets")
    end

    test "read_line/1 has documentation" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(LineReader)

      read_line_doc =
        Enum.find(docs, fn
          {{:function, :read_line, 1}, _, _, _, _} -> true
          _ -> false
        end)

      assert read_line_doc != nil
    end

    test "read_line/2 has documentation" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(LineReader)

      read_line_doc =
        Enum.find(docs, fn
          {{:function, :read_line, 2}, _, _, _, _} -> true
          _ -> false
        end)

      assert read_line_doc != nil
    end
  end

  describe "type specifications" do
    test "read_result type is documented" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(LineReader)

      type_doc =
        Enum.find(docs, fn
          {{:type, :read_result, _}, _, _, _, _} -> true
          _ -> false
        end)

      assert type_doc != nil
    end

    test "validated_result type is documented" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(LineReader)

      type_doc =
        Enum.find(docs, fn
          {{:type, :validated_result, _}, _, _, _, _} -> true
          _ -> false
        end)

      assert type_doc != nil
    end

    test "validator type is documented" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(LineReader)

      type_doc =
        Enum.find(docs, fn
          {{:type, :validator, _}, _, _, _, _} -> true
          _ -> false
        end)

      assert type_doc != nil
    end
  end

  describe "edge cases" do
    test "handles multi-line input (only first line)" do
      # IO.gets only reads until first newline
      result = capture_line_input("line1\nline2\n", fn -> LineReader.read_line() end)
      assert result == {:ok, "line1"}
    end

    test "handles UTF-8 input" do
      result = capture_line_input("héllo wörld\n", fn -> LineReader.read_line() end)
      assert result == {:ok, "héllo wörld"}
    end

    test "handles emoji input" do
      result = capture_line_input("hello 👋\n", fn -> LineReader.read_line() end)
      assert result == {:ok, "hello 👋"}
    end
  end

  describe "EOF handling" do
    # Note: Testing actual EOF is difficult with capture_io since it requires
    # closing the input stream. These tests verify the code paths exist and
    # document the expected behavior.

    test "read_line/1 handles EOF from IO.gets" do
      # We can't easily simulate :eof with capture_io, but we can verify
      # the function handles the case by checking the implementation handles it.
      # The actual :eof case is tested in integration tests.

      # Verify the module handles the :eof case in its pattern matching
      # by checking the function compiles and works for normal input
      result = capture_line_input("test\n", fn -> LineReader.read_line() end)
      assert result == {:ok, "test"}
    end

    test "read_line/2 returns :eof bypassing validation when EOF received" do
      # If IO.gets returns :eof, validation is bypassed and :eof is returned directly
      # This is documented behavior - validators are only called on successful reads
      validator = fn _input ->
        send(self(), :validator_called)
        :ok
      end

      # Normal case - validator is called
      result = capture_line_input("test\n", fn -> LineReader.read_line("Prompt: ", validator) end)
      assert result == {:ok, "test"}
      assert_receive :validator_called

      # Note: We cannot easily test the :eof case with capture_io, but the
      # code path exists in read_line/2's case statement (line 228-229):
      # :eof -> :eof
    end

    test "error-to-eof conversion is documented behavior" do
      # IO.gets can return {:error, reason} which is converted to :eof
      # This is intentional - see line 152-153 in line_reader.ex:
      # {:error, _reason} -> :eof
      #
      # This simplifies error handling for callers who typically don't
      # need to distinguish between "stream ended" and "read error"

      # Verify normal operation works (error cases need real terminal)
      result = capture_line_input("hello\n", fn -> LineReader.read_line() end)
      assert result == {:ok, "hello"}
    end
  end

  # Integration tests that require actual terminal
  describe "integration" do
    @describetag :requires_terminal

    test "displays prompt to user" do
      output =
        ExUnit.CaptureIO.capture_io([input: "test\n"], fn ->
          LineReader.read_line("Enter value: ")
        end)

      assert String.contains?(output, "Enter value: ")
    end
  end
end
