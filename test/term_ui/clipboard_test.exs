defmodule TermUI.ClipboardTest do
  use TermUI.TestCase, async: false

  alias TermUI.Clipboard
  alias TermUI.IntegrationHelpers

  describe "bracketed paste sequences" do
    test "returns enable/disable sequences" do
      assert Clipboard.bracketed_paste_on() == "\e[?2004h"
      assert Clipboard.bracketed_paste_off() == "\e[?2004l"
    end

    test "returns paste markers" do
      assert Clipboard.paste_start_marker() == "\e[200~"
      assert Clipboard.paste_end_marker() == "\e[201~"
    end
  end

  describe "OSC 52 sequences" do
    test "builds clipboard sequence by default" do
      assert Clipboard.write_sequence("hello") == "\e]52;c;aGVsbG8=\e\\"
    end

    test "builds primary selection sequence" do
      assert Clipboard.write_sequence("test", target: :primary) == "\e]52;p;dGVzdA==\e\\"
    end

    test "builds sequence with explicit target string" do
      assert Clipboard.write_sequence("data", target: "s") == "\e]52;s;ZGF0YQ==\e\\"
    end

    test "clears clipboard sequence" do
      assert Clipboard.clear_sequence() == "\e]52;c;\e\\"
    end
  end

  describe "OSC 52 support detection" do
    test "detects iTerm, Alacritty, WezTerm, Kitty, xterm, foot" do
      IntegrationHelpers.with_env(
        %{"TERM_PROGRAM" => "iTerm.app", "TERM" => "xterm-256color"},
        fn ->
          assert Clipboard.osc52_supported?()
        end
      )

      IntegrationHelpers.with_env(
        %{"TERM_PROGRAM" => "Alacritty", "TERM" => "xterm-256color"},
        fn ->
          assert Clipboard.osc52_supported?()
        end
      )

      IntegrationHelpers.with_env(
        %{"TERM_PROGRAM" => "WezTerm", "TERM" => "xterm-256color"},
        fn ->
          assert Clipboard.osc52_supported?()
        end
      )

      IntegrationHelpers.with_env(%{"KITTY_WINDOW_ID" => "1", "TERM" => "xterm-256color"}, fn ->
        assert Clipboard.osc52_supported?()
      end)

      IntegrationHelpers.with_env(%{"TERM" => "xterm-256color", "TERM_PROGRAM" => nil}, fn ->
        assert Clipboard.osc52_supported?()
      end)

      IntegrationHelpers.with_env(%{"TERM" => "foot", "TERM_PROGRAM" => nil}, fn ->
        assert Clipboard.osc52_supported?()
      end)
    end

    test "returns false for unknown terminals" do
      IntegrationHelpers.with_env(
        %{"TERM" => "dumb", "TERM_PROGRAM" => nil, "KITTY_WINDOW_ID" => nil},
        fn ->
          refute Clipboard.osc52_supported?()
        end
      )
    end
  end
end
