defmodule TermUI.TerminalOutputTest do
  use TermUI.TestCase, async: false

  alias TermUI.TerminalOutput

  describe "ONLCR translation" do
    test "enable_onlcr/0 and disable_onlcr/0 toggle state" do
      refute TerminalOutput.onlcr?()

      TerminalOutput.enable_onlcr()
      assert TerminalOutput.onlcr?()

      TerminalOutput.disable_onlcr()
      refute TerminalOutput.onlcr?()
    end

    test "onlcr?/0 defaults to false" do
      refute TerminalOutput.onlcr?()
    end

    test "ONLCR state is shared across processes" do
      on_exit(fn -> TerminalOutput.disable_onlcr() end)
      TerminalOutput.enable_onlcr()

      assert Task.async(fn -> TerminalOutput.onlcr?() end) |> Task.await()
    end

    test "spawned process write uses globally enabled ONLCR" do
      on_exit(fn -> TerminalOutput.disable_onlcr() end)
      TerminalOutput.enable_onlcr()

      output =
        Task.async(fn ->
          ExUnit.CaptureIO.capture_io(fn ->
            TerminalOutput.write("line1\nline2")
          end)
        end)
        |> Task.await()

      assert output == "line1\r\nline2"
    end
  end

  # Test the translation logic by calling the module's internal translate
  # behavior through the write path. We capture IO to verify output.
  describe "newline translation in write output" do
    setup do
      # Suppress actual terminal output during tests
      Application.put_env(:term_ui, :suppress_terminal_output, true)
      TerminalOutput.allow_current_process()

      on_exit(fn ->
        TerminalOutput.disable_onlcr()
        TerminalOutput.disallow_current_process()
        Application.delete_env(:term_ui, :suppress_terminal_output)
      end)

      :ok
    end

    test "write/1 passes data through unchanged when ONLCR is disabled" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          TerminalOutput.write("hello\nworld")
        end)

      assert output == "hello\nworld"
    end

    test "write/1 translates bare \\n to \\r\\n when ONLCR is enabled" do
      TerminalOutput.enable_onlcr()

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          TerminalOutput.write("hello\nworld")
        end)

      assert output == "hello\r\nworld"
    end

    test "write/1 does not double-translate existing \\r\\n" do
      TerminalOutput.enable_onlcr()

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          TerminalOutput.write("hello\r\nworld")
        end)

      assert output == "hello\r\nworld"
    end

    test "write/1 handles multiple newlines" do
      TerminalOutput.enable_onlcr()

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          TerminalOutput.write("a\nb\nc")
        end)

      assert output == "a\r\nb\r\nc"
    end

    test "write/1 handles iolist data with ONLCR" do
      TerminalOutput.enable_onlcr()

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          TerminalOutput.write(["hello", "\n", "world"])
        end)

      assert output == "hello\r\nworld"
    end

    test "write/1 preserves ANSI escape sequences with ONLCR" do
      TerminalOutput.enable_onlcr()

      # Cursor position sequence should pass through unchanged
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          TerminalOutput.write("\e[5;1H")
        end)

      assert output == "\e[5;1H"
    end

    test "write/1 preserves ANSI escape sequences mixed with newlines" do
      TerminalOutput.enable_onlcr()

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          TerminalOutput.write("\e[1;1Hhello\n\e[2;1Hworld")
        end)

      assert output == "\e[1;1Hhello\r\n\e[2;1Hworld"
    end

    test "write/1 handles empty data" do
      TerminalOutput.enable_onlcr()

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          TerminalOutput.write("")
        end)

      assert output == ""
    end

    test "write/1 handles data with no newlines" do
      TerminalOutput.enable_onlcr()

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          TerminalOutput.write("no newlines here")
        end)

      assert output == "no newlines here"
    end

    test "write/1 handles consecutive newlines" do
      TerminalOutput.enable_onlcr()

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          TerminalOutput.write("a\n\n\nb")
        end)

      assert output == "a\r\n\r\n\r\nb"
    end

    test "write/1 handles mixed \\r\\n and bare \\n" do
      TerminalOutput.enable_onlcr()

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          TerminalOutput.write("a\r\nb\nc")
        end)

      assert output == "a\r\nb\r\nc"
    end
  end

  describe "cleanup_sequence/0" do
    test "contains mouse tracking disable sequences for all modes" do
      seq = TerminalOutput.cleanup_sequence()
      assert String.contains?(seq, "\e[?1006l")
      assert String.contains?(seq, "\e[?1003l")
      assert String.contains?(seq, "\e[?1002l")
      assert String.contains?(seq, "\e[?1000l")
    end

    test "contains cursor show sequence" do
      seq = TerminalOutput.cleanup_sequence()
      assert String.contains?(seq, "\e[?25h")
    end

    test "contains SGR reset sequence" do
      seq = TerminalOutput.cleanup_sequence()
      assert String.contains?(seq, "\e[0m")
    end

    test "contains leave alternate screen sequence" do
      seq = TerminalOutput.cleanup_sequence()
      assert String.contains?(seq, "\e[?1049l")
    end

    test "returns a binary" do
      assert is_binary(TerminalOutput.cleanup_sequence())
    end

    test "contains no newlines that could be corrupted by ONLCR" do
      seq = TerminalOutput.cleanup_sequence()
      refute String.contains?(seq, "\n")
    end
  end

  describe "write_to_tty/1" do
    test "does not raise on any input" do
      assert :ok = TerminalOutput.write_to_tty("")
      assert :ok = TerminalOutput.write_to_tty("test data")
      assert :ok = TerminalOutput.write_to_tty(["io", "list"])
      assert :ok = TerminalOutput.write_to_tty(TerminalOutput.cleanup_sequence())
    end

    test "handles iodata input" do
      # Should convert iodata to binary without error
      assert :ok = TerminalOutput.write_to_tty(["\e[?1003l", "\e[?25h"])
    end

    @tag :dev_tty
    test "writes to /dev/tty when available" do
      if File.exists?("/dev/tty") do
        # This writes to the actual terminal but should not raise
        assert :ok = TerminalOutput.write_to_tty("")
      end
    end
  end
end
