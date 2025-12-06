defmodule TermUI.Input.LineReaderTest do
  use ExUnit.Case, async: true

  alias TermUI.Input.LineReader

  # Note: Testing IO.gets directly is tricky because it reads from stdin.
  # These tests use ExUnit's capture_io to simulate input.
  # Integration tests that actually read from stdin are tagged :requires_terminal.

  describe "read_line/1" do
    test "function exists with arity 0 and 1" do
      assert function_exported?(LineReader, :read_line, 0)
      assert function_exported?(LineReader, :read_line, 1)
    end

    test "returns {:ok, line} without prompt" do
      # Use capture_io to simulate input
      ExUnit.CaptureIO.capture_io([input: "hello\n", capture_prompt: false], fn ->
        result = LineReader.read_line()
        send(self(), {:result, result})
      end)

      assert_receive {:result, {:ok, "hello"}}
    end

    test "returns {:ok, line} with prompt" do
      ExUnit.CaptureIO.capture_io([input: "world\n"], fn ->
        result = LineReader.read_line("Enter: ")
        send(self(), {:result, result})
      end)

      assert_receive {:result, {:ok, "world"}}
    end

    test "trims trailing newline from input" do
      ExUnit.CaptureIO.capture_io([input: "test\n"], fn ->
        result = LineReader.read_line()
        send(self(), {:result, result})
      end)

      assert_receive {:result, {:ok, "test"}}
    end

    test "returns empty string for just newline" do
      ExUnit.CaptureIO.capture_io([input: "\n"], fn ->
        result = LineReader.read_line()
        send(self(), {:result, result})
      end)

      assert_receive {:result, {:ok, ""}}
    end

    test "preserves internal whitespace" do
      ExUnit.CaptureIO.capture_io([input: "hello world\n"], fn ->
        result = LineReader.read_line()
        send(self(), {:result, result})
      end)

      assert_receive {:result, {:ok, "hello world"}}
    end

    test "handles input with leading whitespace" do
      ExUnit.CaptureIO.capture_io([input: "  spaced\n"], fn ->
        result = LineReader.read_line()
        send(self(), {:result, result})
      end)

      assert_receive {:result, {:ok, "  spaced"}}
    end
  end

  describe "read_line/2 with validation" do
    test "function exists with arity 2" do
      assert function_exported?(LineReader, :read_line, 2)
    end

    test "returns {:ok, line} when validator returns :ok" do
      validator = fn _input -> :ok end

      ExUnit.CaptureIO.capture_io([input: "valid\n"], fn ->
        result = LineReader.read_line("Input: ", validator)
        send(self(), {:result, result})
      end)

      assert_receive {:result, {:ok, "valid"}}
    end

    test "returns {:ok, transformed} when validator returns {:ok, value}" do
      validator = fn input -> {:ok, String.upcase(input)} end

      ExUnit.CaptureIO.capture_io([input: "hello\n"], fn ->
        result = LineReader.read_line("Input: ", validator)
        send(self(), {:result, result})
      end)

      assert_receive {:result, {:ok, "HELLO"}}
    end

    test "returns {:error, reason} when validator returns {:error, reason}" do
      validator = fn _input -> {:error, "invalid input"} end

      ExUnit.CaptureIO.capture_io([input: "bad\n"], fn ->
        result = LineReader.read_line("Input: ", validator)
        send(self(), {:result, result})
      end)

      assert_receive {:result, {:error, "invalid input"}}
    end

    test "validator receives trimmed input" do
      validator = fn input ->
        send(self(), {:received, input})
        :ok
      end

      ExUnit.CaptureIO.capture_io([input: "test value\n"], fn ->
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
      ExUnit.CaptureIO.capture_io([input: "42\n"], fn ->
        result = LineReader.read_line("Number: ", int_validator)
        send(self(), {:result, result})
      end)

      assert_receive {:result, {:ok, 42}}

      # Invalid integer
      ExUnit.CaptureIO.capture_io([input: "abc\n"], fn ->
        result = LineReader.read_line("Number: ", int_validator)
        send(self(), {:result, result})
      end)

      assert_receive {:result, {:error, "not an integer"}}
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
      ExUnit.CaptureIO.capture_io([input: "abc\n"], fn ->
        result = LineReader.read_line("Input: ", min_length_validator)
        send(self(), {:result, result})
      end)

      assert_receive {:result, {:ok, "abc"}}

      # Too short
      ExUnit.CaptureIO.capture_io([input: "ab\n"], fn ->
        result = LineReader.read_line("Input: ", min_length_validator)
        send(self(), {:result, result})
      end)

      assert_receive {:result, {:error, "must be at least 3 characters"}}
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
      ExUnit.CaptureIO.capture_io([input: "something\n"], fn ->
        result = LineReader.read_line("Input: ", non_empty_validator)
        send(self(), {:result, result})
      end)

      assert_receive {:result, {:ok, "something"}}

      # Empty
      ExUnit.CaptureIO.capture_io([input: "\n"], fn ->
        result = LineReader.read_line("Input: ", non_empty_validator)
        send(self(), {:result, result})
      end)

      assert_receive {:result, {:error, "cannot be empty"}}
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
      ExUnit.CaptureIO.capture_io([input: "line1\nline2\n"], fn ->
        result = LineReader.read_line()
        send(self(), {:result, result})
      end)

      assert_receive {:result, {:ok, "line1"}}
    end

    test "handles UTF-8 input" do
      ExUnit.CaptureIO.capture_io([input: "héllo wörld\n"], fn ->
        result = LineReader.read_line()
        send(self(), {:result, result})
      end)

      assert_receive {:result, {:ok, "héllo wörld"}}
    end

    test "handles emoji input" do
      ExUnit.CaptureIO.capture_io([input: "hello 👋\n"], fn ->
        result = LineReader.read_line()
        send(self(), {:result, result})
      end)

      assert_receive {:result, {:ok, "hello 👋"}}
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
