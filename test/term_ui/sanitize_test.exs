defmodule TermUI.SanitizeTest do
  use TermUI.TestCase, async: true

  alias TermUI.Sanitize

  describe "sanitize/2" do
    test "leaves normal text unchanged" do
      assert Sanitize.sanitize("Hello, World!") == "Hello, World!"
    end

    test "bracket mode replaces ESC with [ESC]" do
      assert Sanitize.sanitize("\e[31mRed\e[0m") == "[ESC][31mRed[ESC][0m"
    end

    test "remove mode strips ANSI codes" do
      assert Sanitize.sanitize("\e[31mRed\e[0m", escape: :remove) == "Red"
    end

    test "keep mode preserves escapes" do
      input = "\e[31mRed\e[0m"
      assert Sanitize.sanitize(input, escape: :keep) == input
    end

    test "truncates long strings" do
      long = String.duplicate("a", 20_000)
      result = Sanitize.sanitize(long)
      assert String.length(result) == 10_000
    end

    test "respects custom max_length" do
      long = String.duplicate("a", 5000)
      result = Sanitize.sanitize(long, max_length: 100)
      assert String.length(result) == 100
    end

    test "handles cursor positioning sequences" do
      assert Sanitize.sanitize("\e[2J\e[H") == "[ESC][2J[ESC][H"
    end

    test "handles OSC sequences" do
      # OSC 0 ; title ST
      input = "\e]0;Title\a"
      result = Sanitize.sanitize(input, escape: :bracket)
      assert result == "[ESC]]0;Title[BEL]"
    end

    test "handles DCS sequences" do
      input = "\eP@mlx-term"
      result = Sanitize.sanitize(input)
      assert String.starts_with?(result, "[ESC]")
    end
  end

  describe "has_ansi?/1" do
    test "detects CSI sequences" do
      assert Sanitize.has_ansi?("\e[31m")
    end

    test "detects OSC sequences" do
      assert Sanitize.has_ansi?("\e]0;Title\a")
    end

    test "returns false for plain text" do
      refute Sanitize.has_ansi?("Hello, World!")
    end

    test "returns false for empty string" do
      refute Sanitize.has_ansi?("")
    end

    test "detects simple ESC sequences" do
      assert Sanitize.has_ansi?("\eM")
    end
  end

  describe "strip_ansi/1" do
    test "removes CSI color codes" do
      assert Sanitize.strip_ansi("\e[31mRed\e[0m") == "Red"
    end

    test "removes cursor positioning" do
      assert Sanitize.strip_ansi("\e[2J\e[HHello") == "Hello"
    end

    test "removes multiple escape sequences" do
      input = "\e[31m\e[1mBold Red\e[0m"
      assert Sanitize.strip_ansi(input) == "Bold Red"
    end

    test "handles text without escapes" do
      assert Sanitize.strip_ansi("Normal text") == "Normal text"
    end

    test "handles empty string" do
      assert Sanitize.strip_ansi("") == ""
    end

    test "removes OSC title sequences" do
      input = "\e]0;My Title\aHello"
      assert Sanitize.strip_ansi(input) == "Hello"
    end
  end

  describe "validate/1" do
    test "returns :ok for safe text" do
      assert Sanitize.validate("Safe text 123") == :ok
    end

    test "returns :ok for text with newlines" do
      assert Sanitize.validate("Line 1\nLine 2") == :ok
    end

    test "returns :ok for text with tabs" do
      assert Sanitize.validate("Column 1\tColumn 2") == :ok
    end

    test "returns error for ANSI escapes" do
      assert {:error, :contains_ansi} = Sanitize.validate("\e[31mRed")
    end

    test "returns error for null bytes" do
      assert {:error, :contains_null_byte} = Sanitize.validate("Null\x00byte")
    end

    test "returns error for control characters" do
      assert {:error, :contains_control_chars} = Sanitize.validate("Beep\a")
      assert {:error, :contains_control_chars} = Sanitize.validate("BS\b")
    end

    test "returns error for vertical tab" do
      assert {:error, :contains_control_chars} = Sanitize.validate("VT\v")
    end

    test "validates empty string" do
      assert Sanitize.validate("") == :ok
    end
  end

  describe "escape_bracket/1" do
    test "replaces ESC with [ESC]" do
      assert Sanitize.escape_bracket("\e[31m") == "[ESC][31m"
    end

    test "replaces BEL with [BEL]" do
      assert Sanitize.escape_bracket("\a") == "[BEL]"
    end

    test "replaces backspace with [BS]" do
      assert Sanitize.escape_bracket("\b") == "[BS]"
    end

    test "replaces VT with [VT]" do
      assert Sanitize.escape_bracket("\v") == "[VT]"
    end

    test "replaces FF with [FF]" do
      assert Sanitize.escape_bracket("\f") == "[FF]"
    end

    test "leaves normal text unchanged" do
      assert Sanitize.escape_bracket("Hello") == "Hello"
    end
  end

  describe "security - injection prevention" do
    test "neutralizes screen clear attacks" do
      attack = "\e[2JThis was cleared"
      result = Sanitize.sanitize(attack)
      refute String.contains?(result, "\e")
    end

    test "neutralizes cursor movement attacks" do
      attack = "\e[10;20HOverwritten text"
      result = Sanitize.sanitize(attack)
      refute String.contains?(result, "\e")
    end

    test "neutralizes color manipulation" do
      attack = "\e[31m\e[47mInvisible text"
      result = Sanitize.sanitize(attack)
      refute String.contains?(result, "\e")
    end

    test "handles mixed attack patterns" do
      attack = "\e[2J\e[10;10H\e[31mAttack\e[0m"
      result = Sanitize.sanitize(attack, escape: :remove)
      assert result == "Attack"
    end
  end

  describe "edge cases" do
    test "handles UTF-8 text" do
      assert Sanitize.validate("Hello 世界 🌍") == :ok
    end

    test "handles very long escape sequences" do
      long_escape = "\e[" <> String.duplicate("1;", 1000) <> "m"
      result = Sanitize.sanitize(long_escape, escape: :remove)
      assert result == ""
    end

    test "handles malformed escape sequences" do
      # Incomplete CSI
      assert Sanitize.sanitize("\e[31") == "[ESC][31"
      # Just ESC
      assert Sanitize.sanitize("\e") == "[ESC]"
    end

    test "handles mixed valid and invalid sequences" do
      # \e[I is a valid CSI sequence with 'I' as terminator (0x49 is in 0x40-0x7E)
      input = "Normal\e[31mRed\e[IncompleteMore"
      result = Sanitize.sanitize(input, escape: :remove)
      # \e[31m and \e[I are both valid CSI sequences, so both get removed
      assert result == "NormalRedncompleteMore"
    end
  end

  describe "integration - realistic scenarios" do
    test "sanitizes user input with embedded escapes" do
      user_input = "Name: \e[31mHacked\e[0m"
      result = Sanitize.sanitize(user_input, escape: :remove)
      assert result == "Name: Hacked"
    end

    test "preserves legitimate whitespace" do
      text = "  Indented  \n  Text  "
      result = Sanitize.sanitize(text, escape: :remove)
      assert result == text
    end

    test "truncates and sanitizes" do
      long_attack = String.duplicate("\e[31m", 1000) <> "Real text"
      result = Sanitize.sanitize(long_attack, max_length: 100, escape: :remove)
      assert String.length(result) <= 100
      refute String.contains?(result, "\e")
    end
  end
end
