defmodule TermUI.ClipboardTest do
  use ExUnit.Case, async: true

  alias TermUI.Clipboard

  describe "bracketed_paste_on/0" do
    test "returns correct escape sequence" do
      assert Clipboard.bracketed_paste_on() == "\e[?2004h"
    end
  end

  describe "bracketed_paste_off/0" do
    test "returns correct escape sequence" do
      assert Clipboard.bracketed_paste_off() == "\e[?2004l"
    end
  end

  describe "paste_start_marker/0" do
    test "returns correct marker" do
      assert Clipboard.paste_start_marker() == "\e[200~"
    end
  end

  describe "paste_end_marker/0" do
    test "returns correct marker" do
      assert Clipboard.paste_end_marker() == "\e[201~"
    end
  end

  describe "write_sequence/2" do
    test "generates OSC 52 sequence for clipboard" do
      sequence = Clipboard.write_sequence("hello")

      # Base64 of "hello" is "aGVsbG8="
      assert sequence == "\e]52;c;aGVsbG8=\e\\"
    end

    test "generates OSC 52 sequence for primary selection" do
      sequence = Clipboard.write_sequence("test", target: :primary)

      # Base64 of "test" is "dGVzdA=="
      assert sequence == "\e]52;p;dGVzdA==\e\\"
    end

    test "handles empty content" do
      sequence = Clipboard.write_sequence("")
      assert sequence == "\e]52;c;\e\\"
    end

    test "handles unicode content" do
      sequence = Clipboard.write_sequence("héllo")
      encoded = Base.encode64("héllo")
      assert sequence == "\e]52;c;#{encoded}\e\\"
    end

    test "handles multiline content" do
      content = "line1\nline2\nline3"
      sequence = Clipboard.write_sequence(content)
      encoded = Base.encode64(content)
      assert sequence == "\e]52;c;#{encoded}\e\\"
    end
  end

  describe "clear_sequence/1" do
    test "generates OSC 52 clear sequence for clipboard" do
      sequence = Clipboard.clear_sequence()
      assert sequence == "\e]52;c;\e\\"
    end

    test "generates OSC 52 clear sequence for primary" do
      sequence = Clipboard.clear_sequence(target: :primary)
      assert sequence == "\e]52;p;\e\\"
    end
  end

  describe "osc52_supported?/0" do
    test "returns boolean" do
      result = Clipboard.osc52_supported?()
      assert is_boolean(result)
    end
  end
end

defmodule TermUI.Clipboard.PasteAccumulatorTest do
  use ExUnit.Case, async: true

  alias TermUI.Clipboard.PasteAccumulator

  describe "new/0" do
    test "creates empty accumulator" do
      acc = PasteAccumulator.new()
      refute PasteAccumulator.accumulating?(acc)
    end
  end

  describe "start/1" do
    test "begins accumulation" do
      acc = PasteAccumulator.new()
      acc = PasteAccumulator.start(acc)

      assert PasteAccumulator.accumulating?(acc)
    end
  end

  describe "add/2" do
    test "accumulates content when active" do
      acc = PasteAccumulator.new()
      acc = PasteAccumulator.start(acc)
      acc = PasteAccumulator.add(acc, "hello")
      acc = PasteAccumulator.add(acc, " world")

      {content, _} = PasteAccumulator.complete(acc)
      assert content == "hello world"
    end

    test "ignores content when not active" do
      acc = PasteAccumulator.new()
      acc = PasteAccumulator.add(acc, "ignored")

      {content, _} = PasteAccumulator.complete(acc)
      assert content == ""
    end
  end

  describe "complete/1" do
    test "returns accumulated content and resets" do
      acc = PasteAccumulator.new()
      acc = PasteAccumulator.start(acc)
      acc = PasteAccumulator.add(acc, "test content")

      {content, acc} = PasteAccumulator.complete(acc)

      assert content == "test content"
      refute PasteAccumulator.accumulating?(acc)
    end

    test "returns empty string when not accumulating" do
      acc = PasteAccumulator.new()
      {content, _} = PasteAccumulator.complete(acc)
      assert content == ""
    end
  end

  describe "timed_out?/2" do
    test "returns false when not accumulating" do
      acc = PasteAccumulator.new()
      refute PasteAccumulator.timed_out?(acc, 1000)
    end

    test "returns false before timeout" do
      acc = PasteAccumulator.new()
      acc = PasteAccumulator.start(acc)
      refute PasteAccumulator.timed_out?(acc, 5000)
    end

    test "returns true after timeout" do
      acc = PasteAccumulator.new()
      acc = PasteAccumulator.start(acc)
      # Use 0 timeout to immediately timeout
      assert PasteAccumulator.timed_out?(acc, 0)
    end
  end

  describe "reset/1" do
    test "clears accumulation state" do
      acc = PasteAccumulator.new()
      acc = PasteAccumulator.start(acc)
      acc = PasteAccumulator.add(acc, "content")
      acc = PasteAccumulator.reset(acc)

      refute PasteAccumulator.accumulating?(acc)
      {content, _} = PasteAccumulator.complete(acc)
      assert content == ""
    end
  end
end

defmodule TermUI.Clipboard.SelectionTest do
  use ExUnit.Case, async: true

  alias TermUI.Clipboard.Selection

  describe "new/0" do
    test "creates empty selection" do
      selection = Selection.new()
      refute Selection.active?(selection)
      assert Selection.empty?(selection)
    end
  end

  describe "start/2" do
    test "starts selection at position" do
      selection = Selection.new()
      selection = Selection.start(selection, 5)

      assert Selection.active?(selection)
      assert Selection.range(selection) == {5, 5}
    end
  end

  describe "extend/2" do
    test "extends selection forward" do
      selection = Selection.new()
      selection = Selection.start(selection, 5)
      selection = Selection.extend(selection, 10)

      assert Selection.range(selection) == {5, 10}
    end

    test "extends selection backward" do
      selection = Selection.new()
      selection = Selection.start(selection, 10)
      selection = Selection.extend(selection, 5)

      # Range is always start <= end
      assert Selection.range(selection) == {5, 10}
    end

    test "starts new selection when not active" do
      selection = Selection.new()
      selection = Selection.extend(selection, 5)

      assert Selection.active?(selection)
    end
  end

  describe "clear/1" do
    test "clears active selection" do
      selection = Selection.new()
      selection = Selection.start(selection, 5)
      selection = Selection.extend(selection, 10)
      selection = Selection.clear(selection)

      refute Selection.active?(selection)
    end
  end

  describe "empty?/1" do
    test "returns true for inactive selection" do
      selection = Selection.new()
      assert Selection.empty?(selection)
    end

    test "returns true for zero-length selection" do
      selection = Selection.new()
      selection = Selection.start(selection, 5)
      assert Selection.empty?(selection)
    end

    test "returns false for non-empty selection" do
      selection = Selection.new()
      selection = Selection.start(selection, 5)
      selection = Selection.extend(selection, 10)
      refute Selection.empty?(selection)
    end
  end

  describe "length/1" do
    test "returns 0 for inactive selection" do
      selection = Selection.new()
      assert Selection.length(selection) == 0
    end

    test "returns correct length" do
      selection = Selection.new()
      selection = Selection.start(selection, 5)
      selection = Selection.extend(selection, 15)
      assert Selection.length(selection) == 10
    end
  end

  describe "extract/2" do
    test "extracts selected text" do
      selection = Selection.new()
      selection = Selection.start(selection, 0)
      selection = Selection.extend(selection, 5)

      text = "Hello World"
      assert Selection.extract(selection, text) == "Hello"
    end

    test "returns empty string for inactive selection" do
      selection = Selection.new()
      assert Selection.extract(selection, "Hello") == ""
    end

    test "extracts middle portion" do
      selection = Selection.new()
      selection = Selection.start(selection, 6)
      selection = Selection.extend(selection, 11)

      text = "Hello World"
      assert Selection.extract(selection, text) == "World"
    end
  end

  describe "contains?/2" do
    test "returns false for inactive selection" do
      selection = Selection.new()
      refute Selection.contains?(selection, 5)
    end

    test "returns true for position in selection" do
      selection = Selection.new()
      selection = Selection.start(selection, 5)
      selection = Selection.extend(selection, 15)

      assert Selection.contains?(selection, 10)
    end

    test "returns false for position outside selection" do
      selection = Selection.new()
      selection = Selection.start(selection, 5)
      selection = Selection.extend(selection, 15)

      refute Selection.contains?(selection, 3)
      refute Selection.contains?(selection, 20)
    end

    test "includes start but excludes end" do
      selection = Selection.new()
      selection = Selection.start(selection, 5)
      selection = Selection.extend(selection, 10)

      assert Selection.contains?(selection, 5)
      refute Selection.contains?(selection, 10)
    end
  end

  describe "move/2" do
    test "moves selection by delta" do
      selection = Selection.new()
      selection = Selection.start(selection, 5)
      selection = Selection.extend(selection, 10)
      selection = Selection.move(selection, 3)

      assert Selection.range(selection) == {8, 13}
    end

    test "does nothing for inactive selection" do
      selection = Selection.new()
      selection = Selection.move(selection, 5)
      refute Selection.active?(selection)
    end
  end

  describe "expand/4" do
    test "expands left" do
      selection = Selection.new()
      text = "Hello World"
      selection = Selection.expand(selection, :left, text, 5)

      assert Selection.range(selection) == {4, 5}
    end

    test "expands right" do
      selection = Selection.new()
      text = "Hello World"
      selection = Selection.expand(selection, :right, text, 5)

      assert Selection.range(selection) == {5, 6}
    end

    test "expands to line start" do
      selection = Selection.new()
      text = "Hello World"
      selection = Selection.expand(selection, :line_start, text, 5)

      assert Selection.range(selection) == {0, 5}
    end

    test "expands to line end" do
      selection = Selection.new()
      text = "Hello World"
      selection = Selection.expand(selection, :line_end, text, 5)

      assert Selection.range(selection) == {5, 11}
    end
  end

  describe "select_all/2" do
    test "selects entire text" do
      selection = Selection.new()
      text = "Hello World"
      selection = Selection.select_all(selection, text)

      assert Selection.range(selection) == {0, 11}
      assert Selection.extract(selection, text) == "Hello World"
    end
  end

  describe "select_word/3" do
    test "selects word at position" do
      selection = Selection.new()
      text = "Hello World"
      selection = Selection.select_word(selection, text, 2)

      assert Selection.extract(selection, text) == "Hello"
    end

    test "selects word when cursor at start" do
      selection = Selection.new()
      text = "Hello World"
      selection = Selection.select_word(selection, text, 0)

      assert Selection.extract(selection, text) == "Hello"
    end

    test "selects word when cursor in middle of text" do
      selection = Selection.new()
      text = "Hello World"
      selection = Selection.select_word(selection, text, 8)

      assert Selection.extract(selection, text) == "World"
    end
  end

  describe "integration" do
    test "full selection workflow" do
      text = "The quick brown fox"

      # Start at position 4
      selection = Selection.new()
      selection = Selection.start(selection, 4)

      # Extend to position 9 ("quick")
      selection = Selection.extend(selection, 9)
      assert Selection.extract(selection, text) == "quick"

      # Continue extending to position 15
      selection = Selection.extend(selection, 15)
      assert Selection.extract(selection, text) == "quick brown"

      # Clear
      selection = Selection.clear(selection)
      refute Selection.active?(selection)
    end
  end
end
