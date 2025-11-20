defmodule TermUI.ParserTest do
  use ExUnit.Case, async: true

  alias TermUI.Parser
  alias TermUI.Parser.Events.{FocusEvent, KeyEvent, MouseEvent, PasteEvent}

  describe "new/0" do
    test "returns initial parser state" do
      state = Parser.new()

      assert state.mode == :ground
      assert state.buffer == <<>>
      assert state.params == []
      assert state.paste_buffer == <<>>
    end
  end

  describe "reset/1" do
    test "resets parser state to initial" do
      state = %{mode: :csi, buffer: "123", params: [1, 2], paste_buffer: "text"}
      reset_state = Parser.reset(state)

      assert reset_state.mode == :ground
      assert reset_state.buffer == <<>>
      assert reset_state.params == []
      assert reset_state.paste_buffer == <<>>
    end
  end

  describe "parse/2 - single characters" do
    test "parses printable ASCII characters" do
      state = Parser.new()

      {[event], "", _state} = Parser.parse("a", state)
      assert %KeyEvent{key: "a", modifiers: []} = event

      {[event], "", _state} = Parser.parse("Z", state)
      assert %KeyEvent{key: "Z", modifiers: []} = event

      {[event], "", _state} = Parser.parse("5", state)
      assert %KeyEvent{key: "5", modifiers: []} = event

      {[event], "", _state} = Parser.parse(" ", state)
      assert %KeyEvent{key: " ", modifiers: []} = event
    end

    test "parses multiple characters" do
      state = Parser.new()
      {events, "", _state} = Parser.parse("abc", state)

      assert length(events) == 3
      assert [%KeyEvent{key: "a"}, %KeyEvent{key: "b"}, %KeyEvent{key: "c"}] = events
    end

    test "parses backspace (DEL)" do
      state = Parser.new()
      {[event], "", _state} = Parser.parse(<<0x7F>>, state)

      assert %KeyEvent{key: :backspace, modifiers: []} = event
    end

    test "parses UTF-8 characters" do
      state = Parser.new()

      {[event], "", _state} = Parser.parse("é", state)
      assert %KeyEvent{key: "é", modifiers: []} = event

      {[event], "", _state} = Parser.parse("日", state)
      assert %KeyEvent{key: "日", modifiers: []} = event
    end
  end

  describe "parse/2 - control characters" do
    test "parses Ctrl+letter combinations" do
      state = Parser.new()

      # Ctrl+A (0x01)
      {[event], "", _state} = Parser.parse(<<0x01>>, state)
      assert %KeyEvent{key: "a", modifiers: [:ctrl]} = event

      # Ctrl+C (0x03)
      {[event], "", _state} = Parser.parse(<<0x03>>, state)
      assert %KeyEvent{key: "c", modifiers: [:ctrl]} = event

      # Ctrl+Z (0x1A)
      {[event], "", _state} = Parser.parse(<<0x1A>>, state)
      assert %KeyEvent{key: "z", modifiers: [:ctrl]} = event
    end

    test "parses Enter key" do
      state = Parser.new()

      # Carriage return (0x0D)
      {[event], "", _state} = Parser.parse(<<0x0D>>, state)
      assert %KeyEvent{key: :enter, modifiers: []} = event

      # Line feed (0x0A)
      {[event], "", _state} = Parser.parse(<<0x0A>>, state)
      assert %KeyEvent{key: :enter, modifiers: []} = event
    end

    test "parses Tab key" do
      state = Parser.new()
      {[event], "", _state} = Parser.parse(<<0x09>>, state)

      assert %KeyEvent{key: :tab, modifiers: []} = event
    end

    test "parses Backspace (0x08)" do
      state = Parser.new()
      {[event], "", _state} = Parser.parse(<<0x08>>, state)

      assert %KeyEvent{key: :backspace, modifiers: []} = event
    end

    test "parses Ctrl+Space" do
      state = Parser.new()
      {[event], "", _state} = Parser.parse(<<0x00>>, state)

      assert %KeyEvent{key: " ", modifiers: [:ctrl]} = event
    end
  end

  describe "parse/2 - escape sequences" do
    test "parses standalone ESC with flush" do
      state = Parser.new()
      {[], _remaining, new_state} = Parser.parse(<<0x1B>>, state)

      assert new_state.mode == :escape

      {[event], reset_state} = Parser.flush_escape(new_state)
      assert %KeyEvent{key: :escape, modifiers: []} = event
      assert reset_state.mode == :ground
    end

    test "parses Alt+letter combinations" do
      state = Parser.new()

      # Alt+a (ESC a)
      {[event], "", _state} = Parser.parse(<<0x1B, ?a>>, state)
      assert %KeyEvent{key: "a", modifiers: [:alt]} = event

      # Alt+Z (ESC Z)
      {[event], "", _state} = Parser.parse(<<0x1B, ?Z>>, state)
      assert %KeyEvent{key: "Z", modifiers: [:alt]} = event
    end
  end

  describe "parse/2 - CSI arrow keys" do
    test "parses basic arrow keys" do
      state = Parser.new()

      # Up arrow: ESC[A
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?A>>, state)
      assert %KeyEvent{key: :up, modifiers: []} = event

      # Down arrow: ESC[B
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?B>>, state)
      assert %KeyEvent{key: :down, modifiers: []} = event

      # Right arrow: ESC[C
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?C>>, state)
      assert %KeyEvent{key: :right, modifiers: []} = event

      # Left arrow: ESC[D
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?D>>, state)
      assert %KeyEvent{key: :left, modifiers: []} = event
    end

    test "parses arrow keys with modifiers" do
      state = Parser.new()

      # Shift+Up: ESC[1;2A
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?1, ?;, ?2, ?A>>, state)
      assert %KeyEvent{key: :up, modifiers: [:shift]} = event

      # Alt+Down: ESC[1;3B
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?1, ?;, ?3, ?B>>, state)
      assert %KeyEvent{key: :down, modifiers: [:alt]} = event

      # Ctrl+Right: ESC[1;5C
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?1, ?;, ?5, ?C>>, state)
      assert %KeyEvent{key: :right, modifiers: [:ctrl]} = event

      # Ctrl+Alt+Left: ESC[1;7D
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?1, ?;, ?7, ?D>>, state)
      assert %KeyEvent{key: :left} = event
      assert Enum.sort(event.modifiers) == [:alt, :ctrl]
    end
  end

  describe "parse/2 - CSI special keys" do
    test "parses Home and End" do
      state = Parser.new()

      # Home: ESC[H
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?H>>, state)
      assert %KeyEvent{key: :home, modifiers: []} = event

      # End: ESC[F
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?F>>, state)
      assert %KeyEvent{key: :end, modifiers: []} = event
    end

    test "parses special keys with tilde terminator" do
      state = Parser.new()

      # Home: ESC[1~
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?1, ?~>>, state)
      assert %KeyEvent{key: :home, modifiers: []} = event

      # Insert: ESC[2~
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?2, ?~>>, state)
      assert %KeyEvent{key: :insert, modifiers: []} = event

      # Delete: ESC[3~
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?3, ?~>>, state)
      assert %KeyEvent{key: :delete, modifiers: []} = event

      # End: ESC[4~
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?4, ?~>>, state)
      assert %KeyEvent{key: :end, modifiers: []} = event

      # Page Up: ESC[5~
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?5, ?~>>, state)
      assert %KeyEvent{key: :page_up, modifiers: []} = event

      # Page Down: ESC[6~
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?6, ?~>>, state)
      assert %KeyEvent{key: :page_down, modifiers: []} = event
    end

    test "parses special keys with modifiers" do
      state = Parser.new()

      # Ctrl+Delete: ESC[3;5~
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?3, ?;, ?5, ?~>>, state)
      assert %KeyEvent{key: :delete, modifiers: [:ctrl]} = event

      # Shift+Page Up: ESC[5;2~
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?5, ?;, ?2, ?~>>, state)
      assert %KeyEvent{key: :page_up, modifiers: [:shift]} = event
    end
  end

  describe "parse/2 - function keys" do
    test "parses F1-F4 (SS3 format)" do
      state = Parser.new()

      # F1: ESC O P
      {[event], "", _state} = Parser.parse(<<0x1B, ?O, ?P>>, state)
      assert %KeyEvent{key: :f1, modifiers: []} = event

      # F2: ESC O Q
      {[event], "", _state} = Parser.parse(<<0x1B, ?O, ?Q>>, state)
      assert %KeyEvent{key: :f2, modifiers: []} = event

      # F3: ESC O R
      {[event], "", _state} = Parser.parse(<<0x1B, ?O, ?R>>, state)
      assert %KeyEvent{key: :f3, modifiers: []} = event

      # F4: ESC O S
      {[event], "", _state} = Parser.parse(<<0x1B, ?O, ?S>>, state)
      assert %KeyEvent{key: :f4, modifiers: []} = event
    end

    test "parses F5-F12 (CSI format)" do
      state = Parser.new()

      # F5: ESC[15~
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?1, ?5, ?~>>, state)
      assert %KeyEvent{key: :f5, modifiers: []} = event

      # F6: ESC[17~
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?1, ?7, ?~>>, state)
      assert %KeyEvent{key: :f6, modifiers: []} = event

      # F7: ESC[18~
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?1, ?8, ?~>>, state)
      assert %KeyEvent{key: :f7, modifiers: []} = event

      # F8: ESC[19~
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?1, ?9, ?~>>, state)
      assert %KeyEvent{key: :f8, modifiers: []} = event

      # F9: ESC[20~
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?2, ?0, ?~>>, state)
      assert %KeyEvent{key: :f9, modifiers: []} = event

      # F10: ESC[21~
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?2, ?1, ?~>>, state)
      assert %KeyEvent{key: :f10, modifiers: []} = event

      # F11: ESC[23~
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?2, ?3, ?~>>, state)
      assert %KeyEvent{key: :f11, modifiers: []} = event

      # F12: ESC[24~
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?2, ?4, ?~>>, state)
      assert %KeyEvent{key: :f12, modifiers: []} = event
    end

    test "parses SS3 arrow keys (application mode)" do
      state = Parser.new()

      # Up: ESC O A
      {[event], "", _state} = Parser.parse(<<0x1B, ?O, ?A>>, state)
      assert %KeyEvent{key: :up, modifiers: []} = event

      # Down: ESC O B
      {[event], "", _state} = Parser.parse(<<0x1B, ?O, ?B>>, state)
      assert %KeyEvent{key: :down, modifiers: []} = event

      # Right: ESC O C
      {[event], "", _state} = Parser.parse(<<0x1B, ?O, ?C>>, state)
      assert %KeyEvent{key: :right, modifiers: []} = event

      # Left: ESC O D
      {[event], "", _state} = Parser.parse(<<0x1B, ?O, ?D>>, state)
      assert %KeyEvent{key: :left, modifiers: []} = event
    end
  end

  describe "parse/2 - mouse events (X10)" do
    test "parses left button press" do
      state = Parser.new()
      # ESC[M + button(0+32) + col(10+32) + row(5+32)
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?M, 32, 42, 37>>, state)

      assert %MouseEvent{action: :press, button: :left, x: 10, y: 5, modifiers: []} = event
    end

    test "parses middle button press" do
      state = Parser.new()
      # ESC[M + button(1+32) + col(20+32) + row(10+32)
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?M, 33, 52, 42>>, state)

      assert %MouseEvent{action: :press, button: :middle, x: 20, y: 10, modifiers: []} = event
    end

    test "parses right button press" do
      state = Parser.new()
      # ESC[M + button(2+32) + col(1+32) + row(1+32)
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?M, 34, 33, 33>>, state)

      assert %MouseEvent{action: :press, button: :right, x: 1, y: 1, modifiers: []} = event
    end

    test "parses button release" do
      state = Parser.new()
      # ESC[M + button(3+32) + col(5+32) + row(5+32)
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?M, 35, 37, 37>>, state)

      assert %MouseEvent{action: :release, button: :none, x: 5, y: 5, modifiers: []} = event
    end

    test "parses wheel up" do
      state = Parser.new()
      # ESC[M + button(64+32) + col(10+32) + row(10+32)
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?M, 96, 42, 42>>, state)

      assert %MouseEvent{action: :press, button: :wheel_up, x: 10, y: 10, modifiers: []} = event
    end

    test "parses wheel down" do
      state = Parser.new()
      # ESC[M + button(65+32) + col(10+32) + row(10+32)
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?M, 97, 42, 42>>, state)

      assert %MouseEvent{action: :press, button: :wheel_down, x: 10, y: 10, modifiers: []} = event
    end

    test "parses motion event" do
      state = Parser.new()
      # ESC[M + button(32+32) + col(15+32) + row(20+32)
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?M, 64, 47, 52>>, state)

      assert %MouseEvent{action: :motion, button: :left, x: 15, y: 20, modifiers: []} = event
    end

    test "parses mouse with modifiers" do
      state = Parser.new()
      # Shift+click: button(0+4+32) + col(10+32) + row(10+32)
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?M, 36, 42, 42>>, state)

      assert %MouseEvent{action: :press, button: :left, modifiers: [:shift]} = event

      # Alt+click: button(0+8+32) + col(10+32) + row(10+32)
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?M, 40, 42, 42>>, state)

      assert %MouseEvent{action: :press, button: :left, modifiers: [:alt]} = event

      # Ctrl+click: button(0+16+32) + col(10+32) + row(10+32)
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?M, 48, 42, 42>>, state)

      assert %MouseEvent{action: :press, button: :left, modifiers: [:ctrl]} = event
    end
  end

  describe "parse/2 - mouse events (SGR)" do
    test "parses left button press" do
      state = Parser.new()
      # ESC[<0;10;5M
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?<, ?0, ?;, ?1, ?0, ?;, ?5, ?M>>, state)

      assert %MouseEvent{action: :press, button: :left, x: 10, y: 5, modifiers: []} = event
    end

    test "parses left button release" do
      state = Parser.new()
      # ESC[<0;10;5m
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?<, ?0, ?;, ?1, ?0, ?;, ?5, ?m>>, state)

      assert %MouseEvent{action: :release, button: :left, x: 10, y: 5, modifiers: []} = event
    end

    test "parses middle button" do
      state = Parser.new()
      # ESC[<1;20;10M
      {[event], "", _state} =
        Parser.parse(<<0x1B, ?[, ?<, ?1, ?;, ?2, ?0, ?;, ?1, ?0, ?M>>, state)

      assert %MouseEvent{action: :press, button: :middle, x: 20, y: 10, modifiers: []} = event
    end

    test "parses right button" do
      state = Parser.new()
      # ESC[<2;1;1M
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?<, ?2, ?;, ?1, ?;, ?1, ?M>>, state)

      assert %MouseEvent{action: :press, button: :right, x: 1, y: 1, modifiers: []} = event
    end

    test "parses wheel events" do
      state = Parser.new()

      # Wheel up: ESC[<64;10;10M
      {[event], "", _state} =
        Parser.parse(<<0x1B, ?[, ?<, ?6, ?4, ?;, ?1, ?0, ?;, ?1, ?0, ?M>>, state)

      assert %MouseEvent{action: :press, button: :wheel_up, x: 10, y: 10, modifiers: []} = event

      # Wheel down: ESC[<65;10;10M
      {[event], "", _state} =
        Parser.parse(<<0x1B, ?[, ?<, ?6, ?5, ?;, ?1, ?0, ?;, ?1, ?0, ?M>>, state)

      assert %MouseEvent{action: :press, button: :wheel_down, x: 10, y: 10, modifiers: []} = event
    end

    test "parses motion event" do
      state = Parser.new()
      # ESC[<32;15;20M
      {[event], "", _state} =
        Parser.parse(<<0x1B, ?[, ?<, ?3, ?2, ?;, ?1, ?5, ?;, ?2, ?0, ?M>>, state)

      assert %MouseEvent{action: :motion, button: :left, x: 15, y: 20, modifiers: []} = event
    end

    test "parses large coordinates" do
      state = Parser.new()
      # ESC[<0;200;150M
      {[event], "", _state} =
        Parser.parse(<<0x1B, ?[, ?<, ?0, ?;, ?2, ?0, ?0, ?;, ?1, ?5, ?0, ?M>>, state)

      assert %MouseEvent{action: :press, button: :left, x: 200, y: 150, modifiers: []} = event
    end
  end

  describe "parse/2 - focus events" do
    test "parses focus gained" do
      state = Parser.new()
      # ESC[I
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?I>>, state)

      assert %FocusEvent{focused: true} = event
    end

    test "parses focus lost" do
      state = Parser.new()
      # ESC[O
      {[event], "", _state} = Parser.parse(<<0x1B, ?[, ?O>>, state)

      assert %FocusEvent{focused: false} = event
    end
  end

  describe "parse/2 - bracketed paste" do
    test "parses simple paste content" do
      state = Parser.new()
      # ESC[200~ + content + ESC[201~
      input = <<0x1B, ?[, ?2, ?0, ?0, ?~, "hello", 0x1B, ?[, ?2, ?0, ?1, ?~>>
      {[event], "", _state} = Parser.parse(input, state)

      assert %PasteEvent{content: "hello"} = event
    end

    test "parses paste with special characters" do
      state = Parser.new()
      input = <<0x1B, ?[, ?2, ?0, ?0, ?~, "test\n\twith\nspecial", 0x1B, ?[, ?2, ?0, ?1, ?~>>
      {[event], "", _state} = Parser.parse(input, state)

      assert %PasteEvent{content: "test\n\twith\nspecial"} = event
    end

    test "parses empty paste" do
      state = Parser.new()
      input = <<0x1B, ?[, ?2, ?0, ?0, ?~, 0x1B, ?[, ?2, ?0, ?1, ?~>>
      {[event], "", _state} = Parser.parse(input, state)

      assert %PasteEvent{content: ""} = event
    end

    test "accumulates paste across multiple parse calls" do
      state = Parser.new()

      # First call: paste start + partial content
      {[], "", state} = Parser.parse(<<0x1B, ?[, ?2, ?0, ?0, ?~, "part1">>, state)
      assert state.mode == :paste

      # Second call: more content + paste end
      {[event], "", _state} = Parser.parse(<<"part2", 0x1B, ?[, ?2, ?0, ?1, ?~>>, state)
      assert %PasteEvent{content: "part1part2"} = event
    end
  end

  describe "parse/2 - incremental parsing" do
    test "handles split escape sequence" do
      state = Parser.new()

      # Send ESC alone
      {[], _remaining, state} = Parser.parse(<<0x1B>>, state)
      assert state.mode == :escape

      # Send rest of sequence
      {[event], "", _state} = Parser.parse(<<?[, ?A>>, state)
      assert %KeyEvent{key: :up, modifiers: []} = event
    end

    test "handles split CSI sequence" do
      state = Parser.new()

      # Send ESC[
      {[], _remaining, state} = Parser.parse(<<0x1B, ?[>>, state)
      assert state.mode == :csi

      # Send parameter and terminator
      {[event], "", _state} = Parser.parse(<<"1;5A">>, state)
      assert %KeyEvent{key: :up, modifiers: [:ctrl]} = event
    end

    test "handles split SGR mouse sequence" do
      state = Parser.new()

      # Send partial sequence
      {[], _remaining, state} = Parser.parse(<<0x1B, ?[, ?<, ?0, ?;>>, state)
      assert state.mode == :sgr_mouse

      # Send rest
      {[event], "", _state} = Parser.parse(<<"10;5M">>, state)
      assert %MouseEvent{action: :press, button: :left, x: 10, y: 5} = event
    end
  end

  describe "flush_escape/1" do
    test "flushes pending escape as key event" do
      state = %{mode: :escape, buffer: <<0x1B>>, params: [], paste_buffer: <<>>}
      {[event], new_state} = Parser.flush_escape(state)

      assert %KeyEvent{key: :escape, modifiers: []} = event
      assert new_state.mode == :ground
    end

    test "returns empty list for non-escape state" do
      state = Parser.new()
      {events, new_state} = Parser.flush_escape(state)

      assert events == []
      assert new_state == state
    end
  end

  describe "parse/2 - mixed input" do
    test "parses multiple events in sequence" do
      state = Parser.new()

      # "a" + Up arrow + "b"
      input = <<"a", 0x1B, ?[, ?A, "b">>
      {events, "", _state} = Parser.parse(input, state)

      assert length(events) == 3

      assert [
               %KeyEvent{key: "a"},
               %KeyEvent{key: :up},
               %KeyEvent{key: "b"}
             ] = events
    end

    test "parses Ctrl+C followed by other input" do
      state = Parser.new()

      input = <<0x03, "abc">>
      {events, "", _state} = Parser.parse(input, state)

      assert length(events) == 4

      assert [
               %KeyEvent{key: "c", modifiers: [:ctrl]},
               %KeyEvent{key: "a"},
               %KeyEvent{key: "b"},
               %KeyEvent{key: "c"}
             ] = events
    end
  end
end
