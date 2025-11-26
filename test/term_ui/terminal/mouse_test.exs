defmodule TermUI.Terminal.MouseTest do
  use ExUnit.Case, async: true

  alias TermUI.Event
  alias TermUI.Terminal.EscapeParser

  describe "mouse event parsing - button press" do
    test "parses left button press" do
      # ESC [ < 0 ; 10 ; 20 M
      {events, remaining} = EscapeParser.parse("\e[<0;10;20M")
      assert remaining == <<>>
      assert [%Event.Mouse{action: :press, button: :left, x: 9, y: 19}] = events
    end

    test "parses middle button press" do
      {events, remaining} = EscapeParser.parse("\e[<1;5;5M")
      assert remaining == <<>>
      assert [%Event.Mouse{action: :press, button: :middle, x: 4, y: 4}] = events
    end

    test "parses right button press" do
      {events, remaining} = EscapeParser.parse("\e[<2;1;1M")
      assert remaining == <<>>
      assert [%Event.Mouse{action: :press, button: :right, x: 0, y: 0}] = events
    end
  end

  describe "mouse event parsing - button release" do
    test "parses button release" do
      # ESC [ < 0 ; 10 ; 20 m (lowercase m for release)
      {events, remaining} = EscapeParser.parse("\e[<0;10;20m")
      assert remaining == <<>>
      assert [%Event.Mouse{action: :release, x: 9, y: 19}] = events
    end
  end

  describe "mouse event parsing - scroll wheel" do
    test "parses scroll up" do
      # Button code 64 = scroll up
      {events, remaining} = EscapeParser.parse("\e[<64;15;10M")
      assert remaining == <<>>
      assert [%Event.Mouse{action: :scroll_up, button: nil, x: 14, y: 9}] = events
    end

    test "parses scroll down" do
      # Button code 65 = scroll down
      {events, remaining} = EscapeParser.parse("\e[<65;15;10M")
      assert remaining == <<>>
      assert [%Event.Mouse{action: :scroll_down, button: nil, x: 14, y: 9}] = events
    end
  end

  describe "mouse event parsing - drag" do
    test "parses left button drag" do
      # Button code 32 = motion flag + left button (0)
      {events, remaining} = EscapeParser.parse("\e[<32;20;30M")
      assert remaining == <<>>
      assert [%Event.Mouse{action: :drag, button: :left, x: 19, y: 29}] = events
    end

    test "parses right button drag" do
      # Button code 34 = motion flag (32) + right button (2)
      {events, remaining} = EscapeParser.parse("\e[<34;5;5M")
      assert remaining == <<>>
      assert [%Event.Mouse{action: :drag, button: :right, x: 4, y: 4}] = events
    end
  end

  describe "mouse event parsing - modifiers" do
    test "parses Shift+click" do
      # Button code 4 = shift modifier
      {events, remaining} = EscapeParser.parse("\e[<4;10;10M")
      assert remaining == <<>>
      assert [%Event.Mouse{modifiers: modifiers}] = events
      assert :shift in modifiers
    end

    test "parses Alt+click" do
      # Button code 8 = alt modifier
      {events, remaining} = EscapeParser.parse("\e[<8;10;10M")
      assert remaining == <<>>
      assert [%Event.Mouse{modifiers: modifiers}] = events
      assert :alt in modifiers
    end

    test "parses Ctrl+click" do
      # Button code 16 = ctrl modifier
      {events, remaining} = EscapeParser.parse("\e[<16;10;10M")
      assert remaining == <<>>
      assert [%Event.Mouse{modifiers: modifiers}] = events
      assert :ctrl in modifiers
    end

    test "parses multiple modifiers" do
      # Button code 28 = shift (4) + alt (8) + ctrl (16)
      {events, remaining} = EscapeParser.parse("\e[<28;10;10M")
      assert remaining == <<>>
      assert [%Event.Mouse{modifiers: modifiers}] = events
      assert :shift in modifiers
      assert :alt in modifiers
      assert :ctrl in modifiers
    end
  end

  describe "mouse event parsing - coordinate conversion" do
    test "converts 1-indexed to 0-indexed coordinates" do
      # Terminal sends 1,1 for top-left
      {events, remaining} = EscapeParser.parse("\e[<0;1;1M")
      assert remaining == <<>>
      assert [%Event.Mouse{x: 0, y: 0}] = events
    end

    test "handles large coordinates" do
      {events, remaining} = EscapeParser.parse("\e[<0;255;100M")
      assert remaining == <<>>
      assert [%Event.Mouse{x: 254, y: 99}] = events
    end
  end

  describe "mouse event parsing - incomplete sequences" do
    test "returns incomplete for partial mouse sequence" do
      {events, remaining} = EscapeParser.parse("\e[<0;10;")
      assert events == []
      assert remaining == "\e[<0;10;"
    end

    test "returns incomplete for mouse sequence without terminator" do
      {events, remaining} = EscapeParser.parse("\e[<0;10;20")
      assert events == []
      assert remaining == "\e[<0;10;20"
    end
  end

  describe "mouse events mixed with keyboard" do
    test "parses mouse followed by key" do
      {events, remaining} = EscapeParser.parse("\e[<0;5;5Ma")
      assert remaining == <<>>
      assert length(events) == 2
      assert [%Event.Mouse{}, %Event.Key{key: "a"}] = events
    end

    test "parses key followed by mouse" do
      {events, remaining} = EscapeParser.parse("x\e[<0;5;5M")
      assert remaining == <<>>
      assert length(events) == 2
      assert [%Event.Key{key: "x"}, %Event.Mouse{}] = events
    end
  end
end
