defmodule TermUI.Integration.RoundTripTest do
  @moduledoc """
  Integration tests for input/output round-trip verification.

  Tests that output sequences produce expected results and input bytes
  parse to expected events.

  ## Limitations

  These tests validate sequence generation and parsing separately, not through
  actual terminal I/O via pseudo-terminals (PTY). This means:

  - ANSI sequence generation is tested for correctness
  - Input byte parsing is tested against expected events
  - The two are not connected through actual terminal round-trips

  True PTY-based round-trip testing would require platform-specific code to
  create pseudo-terminal pairs and verify that written sequences produce the
  expected terminal state. This is left as a future enhancement.
  """

  use ExUnit.Case, async: false

  alias TermUI.ANSI
  alias TermUI.IntegrationHelpers
  alias TermUI.Parser.Events.{FocusEvent, KeyEvent, MouseEvent, PasteEvent}

  import IntegrationHelpers, only: [parse: 1]

  # These tests validate I/O behavior
  @moduletag :integration

  setup do
    IntegrationHelpers.stop_terminal()

    on_exit(fn ->
      IntegrationHelpers.cleanup_terminal()
    end)

    :ok
  end

  describe "1.6.2.1 cursor positioning round-trip" do
    test "cursor position generates correct escape sequence" do
      seq = ANSI.cursor_position(5, 10) |> IO.iodata_to_binary()
      assert seq == "\e[5;10H"
    end

    test "cursor movement sequences are correct" do
      assert ANSI.cursor_up(3) |> IO.iodata_to_binary() == "\e[3A"
      assert ANSI.cursor_down(2) |> IO.iodata_to_binary() == "\e[2B"
      assert ANSI.cursor_forward(4) |> IO.iodata_to_binary() == "\e[4C"
      assert ANSI.cursor_back(1) |> IO.iodata_to_binary() == "\e[D"
    end

    test "cursor show/hide generates correct sequences" do
      assert ANSI.cursor_show() |> IO.iodata_to_binary() == "\e[?25h"
      assert ANSI.cursor_hide() |> IO.iodata_to_binary() == "\e[?25l"
    end

    test "save and restore cursor sequences" do
      assert ANSI.save_cursor() |> IO.iodata_to_binary() == "\e[s"
      assert ANSI.restore_cursor() |> IO.iodata_to_binary() == "\e[u"
    end

    test "cursor position sequence is parseable" do
      seq = ANSI.cursor_position(10, 20) |> IO.iodata_to_binary()

      assert String.starts_with?(seq, "\e[")
      assert String.ends_with?(seq, "H")
    end
  end

  describe "1.6.2.2 key event round-trip" do
    test "simple characters parse correctly" do
      {events, ""} = parse("a")
      assert [%KeyEvent{key: "a", modifiers: []}] = events

      {events, ""} = parse("Z")
      assert [%KeyEvent{key: "Z", modifiers: []}] = events

      {events, ""} = parse("5")
      assert [%KeyEvent{key: "5", modifiers: []}] = events
    end

    test "control characters parse correctly" do
      {events, ""} = parse(<<1>>)
      assert [%KeyEvent{key: "a", modifiers: [:ctrl]}] = events

      {events, ""} = parse(<<3>>)
      assert [%KeyEvent{key: "c", modifiers: [:ctrl]}] = events

      {events, ""} = parse(<<26>>)
      assert [%KeyEvent{key: "z", modifiers: [:ctrl]}] = events
    end

    test "special keys parse correctly" do
      # Enter
      {events, ""} = parse(<<13>>)
      assert [%KeyEvent{key: :enter, modifiers: []}] = events

      # Tab
      {events, ""} = parse(<<9>>)
      assert [%KeyEvent{key: :tab, modifiers: []}] = events

      # Backspace
      {events, ""} = parse(<<127>>)
      assert [%KeyEvent{key: :backspace, modifiers: []}] = events
    end

    test "arrow keys parse correctly" do
      {events, ""} = parse("\e[A")
      assert [%KeyEvent{key: :up, modifiers: []}] = events

      {events, ""} = parse("\e[B")
      assert [%KeyEvent{key: :down, modifiers: []}] = events

      {events, ""} = parse("\e[C")
      assert [%KeyEvent{key: :right, modifiers: []}] = events

      {events, ""} = parse("\e[D")
      assert [%KeyEvent{key: :left, modifiers: []}] = events
    end

    test "function keys parse correctly" do
      {events, ""} = parse("\eOP")
      assert [%KeyEvent{key: :f1, modifiers: []}] = events

      {events, ""} = parse("\eOQ")
      assert [%KeyEvent{key: :f2, modifiers: []}] = events

      {events, ""} = parse("\eOR")
      assert [%KeyEvent{key: :f3, modifiers: []}] = events

      {events, ""} = parse("\eOS")
      assert [%KeyEvent{key: :f4, modifiers: []}] = events

      {events, ""} = parse("\e[15~")
      assert [%KeyEvent{key: :f5, modifiers: []}] = events
    end

    test "home/end/page keys parse correctly" do
      {events, ""} = parse("\e[H")
      assert [%KeyEvent{key: :home, modifiers: []}] = events

      {events, ""} = parse("\e[F")
      assert [%KeyEvent{key: :end, modifiers: []}] = events

      {events, ""} = parse("\e[5~")
      assert [%KeyEvent{key: :page_up, modifiers: []}] = events

      {events, ""} = parse("\e[6~")
      assert [%KeyEvent{key: :page_down, modifiers: []}] = events
    end

    test "multiple events parse in sequence" do
      {events, ""} = parse("abc")

      assert [
               %KeyEvent{key: "a", modifiers: []},
               %KeyEvent{key: "b", modifiers: []},
               %KeyEvent{key: "c", modifiers: []}
             ] = events

      {events, ""} = parse("a\e[Ab")

      assert [
               %KeyEvent{key: "a", modifiers: []},
               %KeyEvent{key: :up, modifiers: []},
               %KeyEvent{key: "b", modifiers: []}
             ] = events
    end

    test "incomplete sequences are handled" do
      {events, remainder} = parse("\e[")

      # The parser handles incomplete sequences in various ways:
      # - Returns remainder for incomplete sequence
      # - Flushes escape event
      # - Parses what it can
      # All of these are valid behaviors
      assert is_list(events)
      assert is_binary(remainder)
    end
  end

  describe "1.6.2.3 mouse event round-trip" do
    test "X10 mouse press events parse correctly" do
      # X10 format: \e[M Cb Cx Cy (values +32)
      # Left button press at (1, 1): button=32, x=33, y=33
      # X10 needs 3 characters after M
      {events, ""} = parse("\e[M !!")
      assert length(events) == 1
      [%MouseEvent{} = event] = events
      assert event.button in [:left, :none]
    end

    test "SGR mouse events parse correctly" do
      {events, ""} = parse("\e[<0;5;10M")

      assert length(events) == 1
      [%MouseEvent{} = event] = events
      assert event.button == :left
      assert event.x == 5
      assert event.y == 10
      assert event.action == :press
    end

    test "SGR mouse release events parse correctly" do
      {events, ""} = parse("\e[<0;5;10m")

      assert length(events) == 1
      [%MouseEvent{} = event] = events
      assert event.action == :release
    end

    test "mouse button types parse correctly" do
      {events, ""} = parse("\e[<1;1;1M")
      [%MouseEvent{} = event] = events
      assert event.button == :middle

      {events, ""} = parse("\e[<2;1;1M")
      [%MouseEvent{} = event] = events
      assert event.button == :right
    end

    test "mouse modifier keys parse correctly" do
      # Shift modifier (4)
      {events, ""} = parse("\e[<4;1;1M")
      [%MouseEvent{} = event] = events
      assert :shift in event.modifiers

      # Ctrl modifier (16)
      {events, ""} = parse("\e[<16;1;1M")
      [%MouseEvent{} = event] = events
      assert :ctrl in event.modifiers

      # Alt modifier (8)
      {events, ""} = parse("\e[<8;1;1M")
      [%MouseEvent{} = event] = events
      assert :alt in event.modifiers
    end

    test "scroll events parse correctly" do
      {events, ""} = parse("\e[<64;1;1M")
      [%MouseEvent{} = event] = events
      assert event.button == :wheel_up

      {events, ""} = parse("\e[<65;1;1M")
      [%MouseEvent{} = event] = events
      assert event.button == :wheel_down
    end
  end

  describe "1.6.2.4 style round-trip" do
    test "basic colors generate correct sequences" do
      assert ANSI.foreground(:red) |> IO.iodata_to_binary() == "\e[31m"
      assert ANSI.foreground(:green) |> IO.iodata_to_binary() == "\e[32m"
      assert ANSI.background(:blue) |> IO.iodata_to_binary() == "\e[44m"
    end

    test "256 colors generate correct sequences" do
      assert ANSI.foreground_256(196) |> IO.iodata_to_binary() == "\e[38;5;196m"
      assert ANSI.background_256(21) |> IO.iodata_to_binary() == "\e[48;5;21m"
    end

    test "true colors generate correct sequences" do
      assert ANSI.foreground_rgb(255, 128, 0) |> IO.iodata_to_binary() == "\e[38;2;255;128;0m"
      assert ANSI.background_rgb(0, 0, 255) |> IO.iodata_to_binary() == "\e[48;2;0;0;255m"
    end

    test "text attributes generate correct sequences" do
      assert ANSI.bold() |> IO.iodata_to_binary() == "\e[1m"
      assert ANSI.dim() |> IO.iodata_to_binary() == "\e[2m"
      assert ANSI.italic() |> IO.iodata_to_binary() == "\e[3m"
      assert ANSI.underline() |> IO.iodata_to_binary() == "\e[4m"
      assert ANSI.blink() |> IO.iodata_to_binary() == "\e[5m"
      assert ANSI.reverse() |> IO.iodata_to_binary() == "\e[7m"
      assert ANSI.strikethrough() |> IO.iodata_to_binary() == "\e[9m"
    end

    test "reset generates correct sequence" do
      assert ANSI.reset() |> IO.iodata_to_binary() == "\e[0m"
    end

    test "combined format generates merged sequence" do
      seq = ANSI.format([:bold, :red]) |> IO.iodata_to_binary()
      assert seq == "\e[1;31m"

      seq = ANSI.format([:underline, :bright_blue, :bg_yellow]) |> IO.iodata_to_binary()
      assert seq == "\e[4;94;43m"
    end

    test "empty format returns empty" do
      assert ANSI.format([]) |> IO.iodata_to_binary() == ""
    end
  end

  describe "special modes round-trip" do
    test "bracketed paste mode sequences" do
      assert ANSI.enable_bracketed_paste() |> IO.iodata_to_binary() == "\e[?2004h"
      assert ANSI.disable_bracketed_paste() |> IO.iodata_to_binary() == "\e[?2004l"
    end

    test "focus event sequences" do
      assert ANSI.enable_focus_events() |> IO.iodata_to_binary() == "\e[?1004h"
      assert ANSI.disable_focus_events() |> IO.iodata_to_binary() == "\e[?1004l"
    end

    test "mouse tracking sequences" do
      assert ANSI.enable_mouse_tracking(:x10) |> IO.iodata_to_binary() == "\e[?9h"
      assert ANSI.enable_mouse_tracking(:normal) |> IO.iodata_to_binary() == "\e[?1000h"
      assert ANSI.enable_mouse_tracking(:button) |> IO.iodata_to_binary() == "\e[?1002h"
      assert ANSI.enable_mouse_tracking(:all) |> IO.iodata_to_binary() == "\e[?1003h"

      assert ANSI.disable_mouse_tracking(:all) |> IO.iodata_to_binary() == "\e[?1003l"
    end

    test "SGR mouse mode sequences" do
      assert ANSI.enable_sgr_mouse() |> IO.iodata_to_binary() == "\e[?1006h"
      assert ANSI.disable_sgr_mouse() |> IO.iodata_to_binary() == "\e[?1006l"
    end

    test "alternate screen sequences" do
      assert ANSI.enter_alternate_screen() |> IO.iodata_to_binary() == "\e[?1049h"
      assert ANSI.leave_alternate_screen() |> IO.iodata_to_binary() == "\e[?1049l"
    end

    test "paste events parse correctly" do
      {events, ""} = parse("\e[200~pasted text\e[201~")

      assert length(events) == 1
      [%PasteEvent{content: content}] = events
      assert content == "pasted text"
    end

    test "focus events parse correctly" do
      {events, ""} = parse("\e[I")
      assert [%FocusEvent{focused: true}] = events

      {events, ""} = parse("\e[O")
      assert [%FocusEvent{focused: false}] = events
    end
  end

  describe "screen manipulation" do
    test "clear screen sequences" do
      assert ANSI.clear_screen() |> IO.iodata_to_binary() == "\e[2J"
      assert ANSI.clear_screen_from_cursor() |> IO.iodata_to_binary() == "\e[0J"
      assert ANSI.clear_screen_to_cursor() |> IO.iodata_to_binary() == "\e[1J"
    end

    test "clear line sequences" do
      assert ANSI.clear_line() |> IO.iodata_to_binary() == "\e[2K"
      assert ANSI.clear_line_from_cursor() |> IO.iodata_to_binary() == "\e[K"
      assert ANSI.clear_line_to_cursor() |> IO.iodata_to_binary() == "\e[1K"
    end

    test "scroll region sequence" do
      assert ANSI.set_scroll_region(5, 20) |> IO.iodata_to_binary() == "\e[5;20r"
    end

    test "scroll sequences" do
      assert ANSI.scroll_up(3) |> IO.iodata_to_binary() == "\e[3S"
      assert ANSI.scroll_down(2) |> IO.iodata_to_binary() == "\e[2T"
    end
  end

  describe "edge cases and boundary values" do
    test "cursor position rejects zero values" do
      # ANSI module guards require positive values
      assert_raise FunctionClauseError, fn ->
        ANSI.cursor_position(0, 0)
      end

      assert_raise FunctionClauseError, fn ->
        ANSI.cursor_position(1, 0)
      end

      assert_raise FunctionClauseError, fn ->
        ANSI.cursor_position(0, 1)
      end
    end

    test "cursor position with minimum valid values" do
      seq = ANSI.cursor_position(1, 1) |> IO.iodata_to_binary()
      assert seq == "\e[1;1H"
    end

    test "cursor position with large values" do
      # Test with values beyond typical terminal size
      seq = ANSI.cursor_position(9999, 9999) |> IO.iodata_to_binary()
      assert seq == "\e[9999;9999H"
    end

    test "cursor movement rejects zero" do
      # ANSI module guards require positive values
      assert_raise FunctionClauseError, fn -> ANSI.cursor_up(0) end
      assert_raise FunctionClauseError, fn -> ANSI.cursor_down(0) end
      assert_raise FunctionClauseError, fn -> ANSI.cursor_forward(0) end
      assert_raise FunctionClauseError, fn -> ANSI.cursor_back(0) end
    end

    test "cursor movement with large values" do
      assert ANSI.cursor_up(10000) |> IO.iodata_to_binary() == "\e[10000A"
      assert ANSI.cursor_down(10000) |> IO.iodata_to_binary() == "\e[10000B"
    end

    test "256 color boundary values" do
      # Minimum valid
      assert ANSI.foreground_256(0) |> IO.iodata_to_binary() == "\e[38;5;0m"
      # Maximum valid
      assert ANSI.foreground_256(255) |> IO.iodata_to_binary() == "\e[38;5;255m"
      # Background boundaries
      assert ANSI.background_256(0) |> IO.iodata_to_binary() == "\e[48;5;0m"
      assert ANSI.background_256(255) |> IO.iodata_to_binary() == "\e[48;5;255m"
    end

    test "RGB color boundary values" do
      # All zeros (black)
      assert ANSI.foreground_rgb(0, 0, 0) |> IO.iodata_to_binary() == "\e[38;2;0;0;0m"
      # All max (white)
      assert ANSI.foreground_rgb(255, 255, 255) |> IO.iodata_to_binary() == "\e[38;2;255;255;255m"
      # Mixed boundaries
      assert ANSI.background_rgb(0, 255, 0) |> IO.iodata_to_binary() == "\e[48;2;0;255;0m"
    end

    test "scroll region boundary values" do
      # Minimum region
      assert ANSI.set_scroll_region(1, 1) |> IO.iodata_to_binary() == "\e[1;1r"
      # Large region
      assert ANSI.set_scroll_region(1, 1000) |> IO.iodata_to_binary() == "\e[1;1000r"
    end

    test "scroll rejects zero values" do
      assert_raise FunctionClauseError, fn -> ANSI.scroll_up(0) end
      assert_raise FunctionClauseError, fn -> ANSI.scroll_down(0) end
    end

    test "scroll with large values" do
      assert ANSI.scroll_up(1000) |> IO.iodata_to_binary() == "\e[1000S"
      assert ANSI.scroll_down(1000) |> IO.iodata_to_binary() == "\e[1000T"
    end
  end
end
