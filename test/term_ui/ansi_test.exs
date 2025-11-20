defmodule TermUI.ANSITest do
  use ExUnit.Case, async: true

  alias TermUI.ANSI

  describe "cursor control (1.2.1)" do
    test "cursor_position generates correct sequence" do
      assert IO.iodata_to_binary(ANSI.cursor_position(5, 10)) == "\e[5;10H"
      assert IO.iodata_to_binary(ANSI.cursor_position(1, 1)) == "\e[1;1H"
      assert IO.iodata_to_binary(ANSI.cursor_position(100, 200)) == "\e[100;200H"
    end

    test "cursor_up generates correct sequence with parameter omission" do
      assert IO.iodata_to_binary(ANSI.cursor_up(1)) == "\e[A"
      assert IO.iodata_to_binary(ANSI.cursor_up(3)) == "\e[3A"
      assert IO.iodata_to_binary(ANSI.cursor_up()) == "\e[A"
    end

    test "cursor_down generates correct sequence with parameter omission" do
      assert IO.iodata_to_binary(ANSI.cursor_down(1)) == "\e[B"
      assert IO.iodata_to_binary(ANSI.cursor_down(5)) == "\e[5B"
      assert IO.iodata_to_binary(ANSI.cursor_down()) == "\e[B"
    end

    test "cursor_forward generates correct sequence with parameter omission" do
      assert IO.iodata_to_binary(ANSI.cursor_forward(1)) == "\e[C"
      assert IO.iodata_to_binary(ANSI.cursor_forward(10)) == "\e[10C"
      assert IO.iodata_to_binary(ANSI.cursor_forward()) == "\e[C"
    end

    test "cursor_back generates correct sequence with parameter omission" do
      assert IO.iodata_to_binary(ANSI.cursor_back(1)) == "\e[D"
      assert IO.iodata_to_binary(ANSI.cursor_back(7)) == "\e[7D"
      assert IO.iodata_to_binary(ANSI.cursor_back()) == "\e[D"
    end

    test "cursor_show and cursor_hide generate correct sequences" do
      assert IO.iodata_to_binary(ANSI.cursor_show()) == "\e[?25h"
      assert IO.iodata_to_binary(ANSI.cursor_hide()) == "\e[?25l"
    end

    test "save_cursor and restore_cursor generate correct sequences" do
      assert IO.iodata_to_binary(ANSI.save_cursor()) == "\e[s"
      assert IO.iodata_to_binary(ANSI.restore_cursor()) == "\e[u"
    end
  end

  describe "screen manipulation (1.2.2)" do
    test "clear_screen functions generate correct sequences" do
      assert IO.iodata_to_binary(ANSI.clear_screen()) == "\e[2J"
      assert IO.iodata_to_binary(ANSI.clear_screen_from_cursor()) == "\e[0J"
      assert IO.iodata_to_binary(ANSI.clear_screen_to_cursor()) == "\e[1J"
    end

    test "clear_line functions generate correct sequences" do
      assert IO.iodata_to_binary(ANSI.clear_line()) == "\e[2K"
      assert IO.iodata_to_binary(ANSI.clear_line_from_cursor()) == "\e[K"
      assert IO.iodata_to_binary(ANSI.clear_line_to_cursor()) == "\e[1K"
    end

    test "set_scroll_region generates correct sequence" do
      assert IO.iodata_to_binary(ANSI.set_scroll_region(5, 20)) == "\e[5;20r"
      assert IO.iodata_to_binary(ANSI.set_scroll_region(1, 100)) == "\e[1;100r"
    end

    test "scroll_up and scroll_down generate correct sequences" do
      assert IO.iodata_to_binary(ANSI.scroll_up(1)) == "\e[S"
      assert IO.iodata_to_binary(ANSI.scroll_up(3)) == "\e[3S"
      assert IO.iodata_to_binary(ANSI.scroll_down(1)) == "\e[T"
      assert IO.iodata_to_binary(ANSI.scroll_down(5)) == "\e[5T"
    end
  end

  describe "colors - 16-color mode (1.2.3)" do
    test "foreground generates correct SGR codes for basic colors" do
      assert IO.iodata_to_binary(ANSI.foreground(:black)) == "\e[30m"
      assert IO.iodata_to_binary(ANSI.foreground(:red)) == "\e[31m"
      assert IO.iodata_to_binary(ANSI.foreground(:green)) == "\e[32m"
      assert IO.iodata_to_binary(ANSI.foreground(:yellow)) == "\e[33m"
      assert IO.iodata_to_binary(ANSI.foreground(:blue)) == "\e[34m"
      assert IO.iodata_to_binary(ANSI.foreground(:magenta)) == "\e[35m"
      assert IO.iodata_to_binary(ANSI.foreground(:cyan)) == "\e[36m"
      assert IO.iodata_to_binary(ANSI.foreground(:white)) == "\e[37m"
    end

    test "foreground generates correct SGR codes for bright colors" do
      assert IO.iodata_to_binary(ANSI.foreground(:bright_black)) == "\e[90m"
      assert IO.iodata_to_binary(ANSI.foreground(:bright_red)) == "\e[91m"
      assert IO.iodata_to_binary(ANSI.foreground(:bright_blue)) == "\e[94m"
      assert IO.iodata_to_binary(ANSI.foreground(:bright_white)) == "\e[97m"
    end

    test "background generates correct SGR codes for basic colors" do
      assert IO.iodata_to_binary(ANSI.background(:black)) == "\e[40m"
      assert IO.iodata_to_binary(ANSI.background(:red)) == "\e[41m"
      assert IO.iodata_to_binary(ANSI.background(:blue)) == "\e[44m"
      assert IO.iodata_to_binary(ANSI.background(:white)) == "\e[47m"
    end

    test "background generates correct SGR codes for bright colors" do
      assert IO.iodata_to_binary(ANSI.background(:bright_red)) == "\e[101m"
      assert IO.iodata_to_binary(ANSI.background(:bright_white)) == "\e[107m"
    end
  end

  describe "colors - 256-color mode (1.2.3)" do
    test "foreground_256 generates correct SGR codes" do
      assert IO.iodata_to_binary(ANSI.foreground_256(0)) == "\e[38;5;0m"
      assert IO.iodata_to_binary(ANSI.foreground_256(196)) == "\e[38;5;196m"
      assert IO.iodata_to_binary(ANSI.foreground_256(255)) == "\e[38;5;255m"
    end

    test "background_256 generates correct SGR codes" do
      assert IO.iodata_to_binary(ANSI.background_256(0)) == "\e[48;5;0m"
      assert IO.iodata_to_binary(ANSI.background_256(196)) == "\e[48;5;196m"
      assert IO.iodata_to_binary(ANSI.background_256(255)) == "\e[48;5;255m"
    end
  end

  describe "colors - true-color mode (1.2.3)" do
    test "foreground_rgb generates correct SGR codes" do
      assert IO.iodata_to_binary(ANSI.foreground_rgb(255, 128, 0)) == "\e[38;2;255;128;0m"
      assert IO.iodata_to_binary(ANSI.foreground_rgb(0, 0, 0)) == "\e[38;2;0;0;0m"
      assert IO.iodata_to_binary(ANSI.foreground_rgb(255, 255, 255)) == "\e[38;2;255;255;255m"
    end

    test "background_rgb generates correct SGR codes" do
      assert IO.iodata_to_binary(ANSI.background_rgb(255, 128, 0)) == "\e[48;2;255;128;0m"
      assert IO.iodata_to_binary(ANSI.background_rgb(0, 0, 0)) == "\e[48;2;0;0;0m"
    end
  end

  describe "text attributes (1.2.3)" do
    test "individual attributes generate correct SGR codes" do
      assert IO.iodata_to_binary(ANSI.bold()) == "\e[1m"
      assert IO.iodata_to_binary(ANSI.dim()) == "\e[2m"
      assert IO.iodata_to_binary(ANSI.italic()) == "\e[3m"
      assert IO.iodata_to_binary(ANSI.underline()) == "\e[4m"
      assert IO.iodata_to_binary(ANSI.blink()) == "\e[5m"
      assert IO.iodata_to_binary(ANSI.reverse()) == "\e[7m"
      assert IO.iodata_to_binary(ANSI.hidden()) == "\e[8m"
      assert IO.iodata_to_binary(ANSI.strikethrough()) == "\e[9m"
    end

    test "reset generates correct SGR code" do
      assert IO.iodata_to_binary(ANSI.reset()) == "\e[0m"
      assert IO.iodata_to_binary(ANSI.reset_style()) == "\e[0m"
    end
  end

  describe "combined styles (1.2.5)" do
    test "format combines multiple attributes into single SGR sequence" do
      assert IO.iodata_to_binary(ANSI.format([:bold, :red])) == "\e[1;31m"

      assert IO.iodata_to_binary(ANSI.format([:underline, :bright_blue, :bg_yellow])) ==
               "\e[4;94;43m"

      assert IO.iodata_to_binary(ANSI.format([:bold, :italic, :underline])) == "\e[1;3;4m"
    end

    test "format with single attribute" do
      assert IO.iodata_to_binary(ANSI.format([:bold])) == "\e[1m"
    end

    test "format with empty list returns empty iodata" do
      assert ANSI.format([]) == []
    end

    test "format with colors and background" do
      assert IO.iodata_to_binary(ANSI.format([:red, :bg_blue])) == "\e[31;44m"
    end
  end

  describe "special modes (1.2.4)" do
    test "bracketed paste mode sequences" do
      assert IO.iodata_to_binary(ANSI.enable_bracketed_paste()) == "\e[?2004h"
      assert IO.iodata_to_binary(ANSI.disable_bracketed_paste()) == "\e[?2004l"
    end

    test "focus event reporting sequences" do
      assert IO.iodata_to_binary(ANSI.enable_focus_events()) == "\e[?1004h"
      assert IO.iodata_to_binary(ANSI.disable_focus_events()) == "\e[?1004l"
    end

    test "application cursor keys mode sequences" do
      assert IO.iodata_to_binary(ANSI.enable_app_cursor()) == "\e[?1h"
      assert IO.iodata_to_binary(ANSI.disable_app_cursor()) == "\e[?1l"
    end

    test "mouse tracking mode sequences" do
      assert IO.iodata_to_binary(ANSI.enable_mouse_tracking(:x10)) == "\e[?9h"
      assert IO.iodata_to_binary(ANSI.enable_mouse_tracking(:normal)) == "\e[?1000h"
      assert IO.iodata_to_binary(ANSI.enable_mouse_tracking(:button)) == "\e[?1002h"
      assert IO.iodata_to_binary(ANSI.enable_mouse_tracking(:all)) == "\e[?1003h"

      assert IO.iodata_to_binary(ANSI.disable_mouse_tracking(:x10)) == "\e[?9l"
      assert IO.iodata_to_binary(ANSI.disable_mouse_tracking(:normal)) == "\e[?1000l"
      assert IO.iodata_to_binary(ANSI.disable_mouse_tracking(:button)) == "\e[?1002l"
      assert IO.iodata_to_binary(ANSI.disable_mouse_tracking(:all)) == "\e[?1003l"
    end

    test "SGR mouse mode sequences" do
      assert IO.iodata_to_binary(ANSI.enable_sgr_mouse()) == "\e[?1006h"
      assert IO.iodata_to_binary(ANSI.disable_sgr_mouse()) == "\e[?1006l"
    end

    test "alternate screen sequences" do
      assert IO.iodata_to_binary(ANSI.enter_alternate_screen()) == "\e[?1049h"
      assert IO.iodata_to_binary(ANSI.leave_alternate_screen()) == "\e[?1049l"
    end
  end

  describe "sequence optimization (1.2.5)" do
    test "parameter omission for n=1 reduces byte count" do
      # With omission: 3 bytes, without: 4 bytes
      assert byte_size(IO.iodata_to_binary(ANSI.cursor_up(1))) == 3
      assert byte_size(IO.iodata_to_binary(ANSI.cursor_up(2))) == 4
    end

    test "combined SGR is more efficient than separate sequences" do
      combined = IO.iodata_to_binary(ANSI.format([:bold, :red]))
      separate = IO.iodata_to_binary(ANSI.bold()) <> IO.iodata_to_binary(ANSI.foreground(:red))

      assert byte_size(combined) < byte_size(separate)
    end
  end
end
