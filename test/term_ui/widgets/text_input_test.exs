defmodule TermUI.Widgets.TextInputTest do
  use ExUnit.Case, async: true

  alias TermUI.Event
  alias TermUI.Widgets.TextInput

  @default_area %{width: 80, height: 24}

  describe "new/1 and init/1" do
    test "creates text input with defaults" do
      props = TextInput.new()
      {:ok, state} = TextInput.init(props)

      assert state.lines == [""]
      assert state.cursor_row == 0
      assert state.cursor_col == 0
      assert state.focused == false
      assert state.multiline == false
    end

    test "creates text input with initial value" do
      props = TextInput.new(value: "Hello")
      {:ok, state} = TextInput.init(props)

      assert state.lines == ["Hello"]
    end

    test "creates multiline text input" do
      props = TextInput.new(multiline: true)
      {:ok, state} = TextInput.init(props)

      assert state.multiline == true
    end

    test "parses multiline value into lines" do
      props = TextInput.new(value: "Line 1\nLine 2\nLine 3", multiline: true)
      {:ok, state} = TextInput.init(props)

      assert state.lines == ["Line 1", "Line 2", "Line 3"]
    end

    test "sets placeholder" do
      props = TextInput.new(placeholder: "Enter text...")
      {:ok, state} = TextInput.init(props)

      assert state.placeholder == "Enter text..."
    end

    test "sets max_visible_lines" do
      props = TextInput.new(max_visible_lines: 10)
      {:ok, state} = TextInput.init(props)

      assert state.max_visible_lines == 10
    end
  end

  describe "character input" do
    test "inserts single character" do
      props = TextInput.new()
      {:ok, state} = TextInput.init(props)

      {:ok, state} = TextInput.handle_event(Event.key(nil, char: "H"), state)
      {:ok, state} = TextInput.handle_event(Event.key(nil, char: "i"), state)

      assert TextInput.get_value(state) == "Hi"
      assert state.cursor_col == 2
    end

    test "inserts character at cursor position" do
      props = TextInput.new(value: "Hllo")
      {:ok, state} = TextInput.init(props)

      # Move cursor to position 1
      {:ok, state} = TextInput.handle_event(Event.key(:right), state)
      # Insert 'e'
      {:ok, state} = TextInput.handle_event(Event.key(nil, char: "e"), state)

      assert TextInput.get_value(state) == "Hello"
    end

    test "does nothing when disabled" do
      props = TextInput.new(disabled: true)
      {:ok, state} = TextInput.init(props)

      {:ok, state} = TextInput.handle_event(Event.key(nil, char: "a"), state)

      assert TextInput.get_value(state) == ""
    end
  end

  describe "backspace" do
    test "deletes character before cursor" do
      props = TextInput.new(value: "Hello")
      {:ok, state} = TextInput.init(props)

      # Move to end
      state = TextInput.set_value(state, "Hello")
      state = %{state | cursor_col: 5}

      {:ok, state} = TextInput.handle_event(Event.key(:backspace), state)

      assert TextInput.get_value(state) == "Hell"
      assert state.cursor_col == 4
    end

    test "does nothing at start of text" do
      props = TextInput.new(value: "Hello")
      {:ok, state} = TextInput.init(props)

      {:ok, state} = TextInput.handle_event(Event.key(:backspace), state)

      assert TextInput.get_value(state) == "Hello"
      assert state.cursor_col == 0
    end

    test "joins lines in multiline mode" do
      props = TextInput.new(value: "Line1\nLine2", multiline: true)
      {:ok, state} = TextInput.init(props)

      # Move to start of second line
      state = %{state | cursor_row: 1, cursor_col: 0}

      {:ok, state} = TextInput.handle_event(Event.key(:backspace), state)

      assert state.lines == ["Line1Line2"]
      assert state.cursor_row == 0
      assert state.cursor_col == 5
    end
  end

  describe "delete" do
    test "deletes character at cursor" do
      props = TextInput.new(value: "Hello")
      {:ok, state} = TextInput.init(props)

      {:ok, state} = TextInput.handle_event(Event.key(:delete), state)

      assert TextInput.get_value(state) == "ello"
    end

    test "does nothing at end of text in single-line" do
      props = TextInput.new(value: "Hi")
      {:ok, state} = TextInput.init(props)
      state = %{state | cursor_col: 2}

      {:ok, state} = TextInput.handle_event(Event.key(:delete), state)

      assert TextInput.get_value(state) == "Hi"
    end

    test "joins lines in multiline mode" do
      props = TextInput.new(value: "Line1\nLine2", multiline: true)
      {:ok, state} = TextInput.init(props)

      # Move to end of first line
      state = %{state | cursor_row: 0, cursor_col: 5}

      {:ok, state} = TextInput.handle_event(Event.key(:delete), state)

      assert state.lines == ["Line1Line2"]
    end
  end

  describe "cursor movement" do
    test "moves left" do
      props = TextInput.new(value: "Hello")
      {:ok, state} = TextInput.init(props)
      state = %{state | cursor_col: 3}

      {:ok, state} = TextInput.handle_event(Event.key(:left), state)

      assert state.cursor_col == 2
    end

    test "moves right" do
      props = TextInput.new(value: "Hello")
      {:ok, state} = TextInput.init(props)

      {:ok, state} = TextInput.handle_event(Event.key(:right), state)

      assert state.cursor_col == 1
    end

    test "does not move left past start" do
      props = TextInput.new(value: "Hello")
      {:ok, state} = TextInput.init(props)

      {:ok, state} = TextInput.handle_event(Event.key(:left), state)

      assert state.cursor_col == 0
    end

    test "does not move right past end in single-line" do
      props = TextInput.new(value: "Hi")
      {:ok, state} = TextInput.init(props)
      state = %{state | cursor_col: 2}

      {:ok, state} = TextInput.handle_event(Event.key(:right), state)

      assert state.cursor_col == 2
    end

    test "moves up in multiline" do
      props = TextInput.new(value: "Line1\nLine2", multiline: true)
      {:ok, state} = TextInput.init(props)
      state = %{state | cursor_row: 1, cursor_col: 2}

      {:ok, state} = TextInput.handle_event(Event.key(:up), state)

      assert state.cursor_row == 0
      assert state.cursor_col == 2
    end

    test "moves down in multiline" do
      props = TextInput.new(value: "Line1\nLine2", multiline: true)
      {:ok, state} = TextInput.init(props)
      state = %{state | cursor_col: 2}

      {:ok, state} = TextInput.handle_event(Event.key(:down), state)

      assert state.cursor_row == 1
      assert state.cursor_col == 2
    end

    test "clamps column when moving to shorter line" do
      props = TextInput.new(value: "Long line\nShort", multiline: true)
      {:ok, state} = TextInput.init(props)
      state = %{state | cursor_col: 9}

      {:ok, state} = TextInput.handle_event(Event.key(:down), state)

      assert state.cursor_row == 1
      assert state.cursor_col == 5
    end

    test "home moves to start of line" do
      props = TextInput.new(value: "Hello")
      {:ok, state} = TextInput.init(props)
      state = %{state | cursor_col: 3}

      {:ok, state} = TextInput.handle_event(Event.key(:home), state)

      assert state.cursor_col == 0
    end

    test "end moves to end of line" do
      props = TextInput.new(value: "Hello")
      {:ok, state} = TextInput.init(props)

      {:ok, state} = TextInput.handle_event(Event.key(:end), state)

      assert state.cursor_col == 5
    end

    test "ctrl+home moves to start of text" do
      props = TextInput.new(value: "Line1\nLine2\nLine3", multiline: true)
      {:ok, state} = TextInput.init(props)
      state = %{state | cursor_row: 2, cursor_col: 3}

      {:ok, state} = TextInput.handle_event(Event.key(:home, modifiers: [:ctrl]), state)

      assert state.cursor_row == 0
      assert state.cursor_col == 0
    end

    test "ctrl+end moves to end of text" do
      props = TextInput.new(value: "Line1\nLine2\nLine3", multiline: true)
      {:ok, state} = TextInput.init(props)

      {:ok, state} = TextInput.handle_event(Event.key(:end, modifiers: [:ctrl]), state)

      assert state.cursor_row == 2
      assert state.cursor_col == 5
    end

    test "left at line start moves to end of previous line in multiline" do
      props = TextInput.new(value: "Line1\nLine2", multiline: true)
      {:ok, state} = TextInput.init(props)
      state = %{state | cursor_row: 1, cursor_col: 0}

      {:ok, state} = TextInput.handle_event(Event.key(:left), state)

      assert state.cursor_row == 0
      assert state.cursor_col == 5
    end

    test "right at line end moves to start of next line in multiline" do
      props = TextInput.new(value: "Line1\nLine2", multiline: true)
      {:ok, state} = TextInput.init(props)
      state = %{state | cursor_col: 5}

      {:ok, state} = TextInput.handle_event(Event.key(:right), state)

      assert state.cursor_row == 1
      assert state.cursor_col == 0
    end
  end

  describe "newline insertion" do
    test "ctrl+enter inserts newline in multiline mode" do
      props = TextInput.new(value: "HelloWorld", multiline: true)
      {:ok, state} = TextInput.init(props)
      state = %{state | cursor_col: 5}

      {:ok, state} = TextInput.handle_event(Event.key(:enter, modifiers: [:ctrl]), state)

      assert state.lines == ["Hello", "World"]
      assert state.cursor_row == 1
      assert state.cursor_col == 0
    end

    test "enter without ctrl inserts newline when enter_submits is false" do
      props = TextInput.new(value: "HelloWorld", multiline: true, enter_submits: false)
      {:ok, state} = TextInput.init(props)
      state = %{state | cursor_col: 5}

      {:ok, state} = TextInput.handle_event(Event.key(:enter), state)

      assert state.lines == ["Hello", "World"]
    end

    test "respects max_lines constraint" do
      props = TextInput.new(value: "Line1\nLine2\nLine3", multiline: true, max_lines: 3)
      {:ok, state} = TextInput.init(props)
      state = %{state | cursor_row: 2, cursor_col: 5}

      {:ok, state} = TextInput.handle_event(Event.key(:enter, modifiers: [:ctrl]), state)

      # Should still have 3 lines, newline was not inserted
      assert length(state.lines) == 3
    end
  end

  describe "enter key behavior" do
    test "enter submits in single-line mode" do
      test_pid = self()

      props =
        TextInput.new(
          value: "test",
          on_submit: fn value -> send(test_pid, {:submitted, value}) end
        )

      {:ok, state} = TextInput.init(props)

      {:ok, _state} = TextInput.handle_event(Event.key(:enter), state)

      assert_receive {:submitted, "test"}
    end

    test "enter submits in multiline with enter_submits: true" do
      test_pid = self()

      props =
        TextInput.new(
          value: "test",
          multiline: true,
          enter_submits: true,
          on_submit: fn value -> send(test_pid, {:submitted, value}) end
        )

      {:ok, state} = TextInput.init(props)

      {:ok, _state} = TextInput.handle_event(Event.key(:enter), state)

      assert_receive {:submitted, "test"}
    end
  end

  describe "focus handling" do
    test "escape blurs the input" do
      props = TextInput.new()
      {:ok, state} = TextInput.init(props)
      state = %{state | focused: true}

      {:ok, state} = TextInput.handle_event(Event.key(:escape), state)

      assert state.focused == false
    end

    test "focus gained event sets focused" do
      props = TextInput.new()
      {:ok, state} = TextInput.init(props)

      {:ok, state} = TextInput.handle_event(Event.focus(:gained), state)

      assert state.focused == true
    end

    test "focus lost event clears focused" do
      props = TextInput.new()
      {:ok, state} = TextInput.init(props)
      state = %{state | focused: true}

      {:ok, state} = TextInput.handle_event(Event.focus(:lost), state)

      assert state.focused == false
    end
  end

  describe "callbacks" do
    test "on_change called when text changes" do
      test_pid = self()

      props =
        TextInput.new(on_change: fn value -> send(test_pid, {:changed, value}) end)

      {:ok, state} = TextInput.init(props)

      {:ok, _state} = TextInput.handle_event(Event.key(nil, char: "a"), state)

      assert_receive {:changed, "a"}
    end

    test "on_change called on backspace" do
      test_pid = self()

      props =
        TextInput.new(
          value: "ab",
          on_change: fn value -> send(test_pid, {:changed, value}) end
        )

      {:ok, state} = TextInput.init(props)
      state = %{state | cursor_col: 2}

      {:ok, _state} = TextInput.handle_event(Event.key(:backspace), state)

      assert_receive {:changed, "a"}
    end
  end

  describe "scrolling" do
    test "scroll_offset adjusts when cursor moves below visible area" do
      # Create 10 lines
      lines = Enum.map_join(0..9, "\n", fn i -> "Line #{i}" end)
      props = TextInput.new(value: lines, multiline: true, max_visible_lines: 5)
      {:ok, state} = TextInput.init(props)

      # Move cursor to line 7
      state = %{state | cursor_row: 7, scroll_offset: 0}

      # Trigger scroll adjustment by moving down
      {:ok, state} = TextInput.handle_event(Event.key(:down), state)

      # scroll_offset should adjust so cursor is visible
      assert state.scroll_offset > 0
      assert state.cursor_row >= state.scroll_offset
      assert state.cursor_row < state.scroll_offset + state.max_visible_lines
    end

    test "scroll_offset adjusts when cursor moves above visible area" do
      lines = Enum.map_join(0..9, "\n", fn i -> "Line #{i}" end)
      props = TextInput.new(value: lines, multiline: true, max_visible_lines: 5)
      {:ok, state} = TextInput.init(props)

      # Start with cursor and scroll at line 5
      state = %{state | cursor_row: 5, scroll_offset: 5}

      # Move cursor up
      {:ok, state} = TextInput.handle_event(Event.key(:up), state)

      # scroll_offset should adjust
      assert state.cursor_row >= state.scroll_offset
    end
  end

  describe "public API" do
    test "get_value returns current text" do
      props = TextInput.new(value: "Hello\nWorld", multiline: true)
      {:ok, state} = TextInput.init(props)

      assert TextInput.get_value(state) == "Hello\nWorld"
    end

    test "set_value updates text" do
      props = TextInput.new()
      {:ok, state} = TextInput.init(props)

      state = TextInput.set_value(state, "New text")

      assert TextInput.get_value(state) == "New text"
    end

    test "set_value resets cursor position" do
      props = TextInput.new(value: "Old text")
      {:ok, state} = TextInput.init(props)
      state = %{state | cursor_col: 4}

      state = TextInput.set_value(state, "New")

      assert state.cursor_row == 0
      assert state.cursor_col == 0
    end

    test "clear empties the text" do
      props = TextInput.new(value: "Hello")
      {:ok, state} = TextInput.init(props)

      state = TextInput.clear(state)

      assert TextInput.get_value(state) == ""
      assert state.lines == [""]
    end

    test "set_focused sets focus state" do
      props = TextInput.new()
      {:ok, state} = TextInput.init(props)

      state = TextInput.set_focused(state, true)
      assert state.focused == true

      state = TextInput.set_focused(state, false)
      assert state.focused == false
    end

    test "get_line_count returns number of lines" do
      props = TextInput.new(value: "Line1\nLine2\nLine3", multiline: true)
      {:ok, state} = TextInput.init(props)

      assert TextInput.get_line_count(state) == 3
    end

    test "get_cursor returns cursor position" do
      props = TextInput.new(value: "Hello\nWorld", multiline: true)
      {:ok, state} = TextInput.init(props)
      state = %{state | cursor_row: 1, cursor_col: 3}

      assert TextInput.get_cursor(state) == {1, 3}
    end
  end

  describe "update/2" do
    test "updates configuration from new props" do
      props = TextInput.new(width: 40)
      {:ok, state} = TextInput.init(props)

      new_props = TextInput.new(width: 60)
      {:ok, state} = TextInput.update(new_props, state)

      assert state.width == 60
    end

    test "updates value if changed externally" do
      props = TextInput.new(value: "Original")
      {:ok, state} = TextInput.init(props)

      new_props = TextInput.new(value: "Updated")
      {:ok, state} = TextInput.update(new_props, state)

      assert TextInput.get_value(state) == "Updated"
    end
  end

  describe "rendering" do
    test "renders text content" do
      props = TextInput.new(value: "Hello")
      {:ok, state} = TextInput.init(props)

      result = TextInput.render(state, @default_area)
      assert result != nil
    end

    test "renders placeholder when empty and unfocused" do
      props = TextInput.new(placeholder: "Enter text...")
      {:ok, state} = TextInput.init(props)

      result = TextInput.render(state, @default_area)
      assert result.type == :text
      assert result.content == "Enter text..."
    end

    test "renders content instead of placeholder when focused" do
      props = TextInput.new(placeholder: "Enter text...")
      {:ok, state} = TextInput.init(props)
      state = %{state | focused: true}

      result = TextInput.render(state, @default_area)
      # Should not show placeholder when focused
      refute result.content == "Enter text..."
    end

    test "renders multiple lines in multiline mode" do
      props = TextInput.new(value: "Line1\nLine2\nLine3", multiline: true)
      {:ok, state} = TextInput.init(props)

      result = TextInput.render(state, @default_area)
      assert result.type == :stack
    end
  end

  describe "edge cases" do
    test "handles empty string value" do
      props = TextInput.new(value: "")
      {:ok, state} = TextInput.init(props)

      assert state.lines == [""]
      assert TextInput.get_value(state) == ""
    end

    test "handles single character input" do
      props = TextInput.new()
      {:ok, state} = TextInput.init(props)

      {:ok, state} = TextInput.handle_event(Event.key(nil, char: "X"), state)

      assert TextInput.get_value(state) == "X"
    end

    test "handles empty char in event gracefully" do
      props = TextInput.new()
      {:ok, state} = TextInput.init(props)

      {:ok, state} = TextInput.handle_event(Event.key(nil, char: ""), state)

      assert TextInput.get_value(state) == ""
    end

    test "handles unknown events gracefully" do
      props = TextInput.new()
      {:ok, state} = TextInput.init(props)

      {:ok, new_state} = TextInput.handle_event(Event.mouse(:click, :left, 0, 0), state)

      assert new_state == state
    end

    test "multiline input preserves empty lines" do
      props = TextInput.new(value: "Line1\n\nLine3", multiline: true)
      {:ok, state} = TextInput.init(props)

      assert state.lines == ["Line1", "", "Line3"]
      assert TextInput.get_value(state) == "Line1\n\nLine3"
    end
  end
end
