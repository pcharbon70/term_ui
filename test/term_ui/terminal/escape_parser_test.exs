defmodule TermUI.Terminal.EscapeParserTest do
  use ExUnit.Case, async: true

  alias TermUI.Event
  alias TermUI.Terminal.EscapeParser

  describe "parse/1 - single characters" do
    test "parses lowercase letters" do
      {events, remaining} = EscapeParser.parse("a")
      assert remaining == <<>>
      assert [%Event.Key{key: "a", modifiers: []}] = events
    end

    test "parses uppercase letters" do
      {events, remaining} = EscapeParser.parse("A")
      assert remaining == <<>>
      assert [%Event.Key{key: "A"}] = events
    end

    test "parses numbers" do
      {events, remaining} = EscapeParser.parse("5")
      assert remaining == <<>>
      assert [%Event.Key{key: "5"}] = events
    end

    test "parses special characters" do
      {events, remaining} = EscapeParser.parse("@")
      assert remaining == <<>>
      assert [%Event.Key{key: "@"}] = events
    end

    test "parses multiple characters" do
      {events, remaining} = EscapeParser.parse("abc")
      assert remaining == <<>>
      assert length(events) == 3
      assert [%Event.Key{key: "a"}, %Event.Key{key: "b"}, %Event.Key{key: "c"}] = events
    end
  end

  describe "parse/1 - control characters" do
    test "parses Ctrl+A" do
      {events, remaining} = EscapeParser.parse(<<1>>)
      assert remaining == <<>>
      assert [%Event.Key{key: "a", modifiers: modifiers}] = events
      assert :ctrl in modifiers
    end

    test "parses Ctrl+C" do
      {events, remaining} = EscapeParser.parse(<<3>>)
      assert remaining == <<>>
      assert [%Event.Key{key: "c", modifiers: modifiers}] = events
      assert :ctrl in modifiers
    end

    test "parses Ctrl+Z" do
      {events, remaining} = EscapeParser.parse(<<26>>)
      assert remaining == <<>>
      assert [%Event.Key{key: "z", modifiers: modifiers}] = events
      assert :ctrl in modifiers
    end

    test "parses backspace (Ctrl+H)" do
      {events, remaining} = EscapeParser.parse(<<8>>)
      assert remaining == <<>>
      assert [%Event.Key{key: :backspace}] = events
    end

    test "parses tab (Ctrl+I)" do
      {events, remaining} = EscapeParser.parse(<<9>>)
      assert remaining == <<>>
      assert [%Event.Key{key: :tab}] = events
    end

    test "parses enter (Ctrl+M)" do
      {events, remaining} = EscapeParser.parse(<<13>>)
      assert remaining == <<>>
      assert [%Event.Key{key: :enter}] = events
    end

    test "parses delete (0x7F)" do
      {events, remaining} = EscapeParser.parse(<<0x7F>>)
      assert remaining == <<>>
      assert [%Event.Key{key: :backspace}] = events
    end
  end

  describe "parse/1 - arrow keys" do
    test "parses up arrow" do
      {events, remaining} = EscapeParser.parse("\e[A")
      assert remaining == <<>>
      assert [%Event.Key{key: :up}] = events
    end

    test "parses down arrow" do
      {events, remaining} = EscapeParser.parse("\e[B")
      assert remaining == <<>>
      assert [%Event.Key{key: :down}] = events
    end

    test "parses right arrow" do
      {events, remaining} = EscapeParser.parse("\e[C")
      assert remaining == <<>>
      assert [%Event.Key{key: :right}] = events
    end

    test "parses left arrow" do
      {events, remaining} = EscapeParser.parse("\e[D")
      assert remaining == <<>>
      assert [%Event.Key{key: :left}] = events
    end
  end

  describe "parse/1 - navigation keys" do
    test "parses home (ESC[H)" do
      {events, remaining} = EscapeParser.parse("\e[H")
      assert remaining == <<>>
      assert [%Event.Key{key: :home}] = events
    end

    test "parses end (ESC[F)" do
      {events, remaining} = EscapeParser.parse("\e[F")
      assert remaining == <<>>
      assert [%Event.Key{key: :end}] = events
    end

    test "parses home (ESC[1~)" do
      {events, remaining} = EscapeParser.parse("\e[1~")
      assert remaining == <<>>
      assert [%Event.Key{key: :home}] = events
    end

    test "parses insert (ESC[2~)" do
      {events, remaining} = EscapeParser.parse("\e[2~")
      assert remaining == <<>>
      assert [%Event.Key{key: :insert}] = events
    end

    test "parses delete (ESC[3~)" do
      {events, remaining} = EscapeParser.parse("\e[3~")
      assert remaining == <<>>
      assert [%Event.Key{key: :delete}] = events
    end

    test "parses end (ESC[4~)" do
      {events, remaining} = EscapeParser.parse("\e[4~")
      assert remaining == <<>>
      assert [%Event.Key{key: :end}] = events
    end

    test "parses page up (ESC[5~)" do
      {events, remaining} = EscapeParser.parse("\e[5~")
      assert remaining == <<>>
      assert [%Event.Key{key: :page_up}] = events
    end

    test "parses page down (ESC[6~)" do
      {events, remaining} = EscapeParser.parse("\e[6~")
      assert remaining == <<>>
      assert [%Event.Key{key: :page_down}] = events
    end
  end

  describe "parse/1 - function keys (CSI)" do
    test "parses F1 (ESC[11~)" do
      {events, remaining} = EscapeParser.parse("\e[11~")
      assert remaining == <<>>
      assert [%Event.Key{key: :f1}] = events
    end

    test "parses F5 (ESC[15~)" do
      {events, remaining} = EscapeParser.parse("\e[15~")
      assert remaining == <<>>
      assert [%Event.Key{key: :f5}] = events
    end

    test "parses F12 (ESC[24~)" do
      {events, remaining} = EscapeParser.parse("\e[24~")
      assert remaining == <<>>
      assert [%Event.Key{key: :f12}] = events
    end
  end

  describe "parse/1 - function keys (SS3)" do
    test "parses F1 (ESCOP)" do
      {events, remaining} = EscapeParser.parse("\eOP")
      assert remaining == <<>>
      assert [%Event.Key{key: :f1}] = events
    end

    test "parses F2 (ESCOQ)" do
      {events, remaining} = EscapeParser.parse("\eOQ")
      assert remaining == <<>>
      assert [%Event.Key{key: :f2}] = events
    end

    test "parses F3 (ESCOR)" do
      {events, remaining} = EscapeParser.parse("\eOR")
      assert remaining == <<>>
      assert [%Event.Key{key: :f3}] = events
    end

    test "parses F4 (ESCOS)" do
      {events, remaining} = EscapeParser.parse("\eOS")
      assert remaining == <<>>
      assert [%Event.Key{key: :f4}] = events
    end
  end

  describe "parse/1 - Alt+key" do
    test "parses Alt+a" do
      {events, remaining} = EscapeParser.parse("\ea")
      assert remaining == <<>>
      assert [%Event.Key{key: "a", modifiers: modifiers}] = events
      assert :alt in modifiers
    end

    test "parses Alt+A" do
      {events, remaining} = EscapeParser.parse("\eA")
      assert remaining == <<>>
      assert [%Event.Key{key: "A", modifiers: modifiers}] = events
      assert :alt in modifiers
    end

    test "parses Alt+x" do
      {events, remaining} = EscapeParser.parse("\ex")
      assert remaining == <<>>
      assert [%Event.Key{key: "x", modifiers: modifiers}] = events
      assert :alt in modifiers
    end
  end

  describe "parse/1 - modified arrow keys" do
    test "parses Shift+Up (ESC[1;2A)" do
      {events, remaining} = EscapeParser.parse("\e[1;2A")
      assert remaining == <<>>
      assert [%Event.Key{key: :up, modifiers: modifiers}] = events
      assert :shift in modifiers
      refute :alt in modifiers
      refute :ctrl in modifiers
    end

    test "parses Alt+Down (ESC[1;3B)" do
      {events, remaining} = EscapeParser.parse("\e[1;3B")
      assert remaining == <<>>
      assert [%Event.Key{key: :down, modifiers: modifiers}] = events
      refute :shift in modifiers
      assert :alt in modifiers
      refute :ctrl in modifiers
    end

    test "parses Ctrl+Right (ESC[1;5C)" do
      {events, remaining} = EscapeParser.parse("\e[1;5C")
      assert remaining == <<>>
      assert [%Event.Key{key: :right, modifiers: modifiers}] = events
      refute :shift in modifiers
      refute :alt in modifiers
      assert :ctrl in modifiers
    end

    test "parses Shift+Alt+Left (ESC[1;4D)" do
      {events, remaining} = EscapeParser.parse("\e[1;4D")
      assert remaining == <<>>
      assert [%Event.Key{key: :left, modifiers: modifiers}] = events
      assert :shift in modifiers
      assert :alt in modifiers
      refute :ctrl in modifiers
    end
  end

  describe "parse/1 - UTF-8 characters" do
    test "parses 2-byte UTF-8 character" do
      # é is 0xC3 0xA9
      {events, remaining} = EscapeParser.parse("é")
      assert remaining == <<>>
      assert [%Event.Key{key: "é"}] = events
    end

    test "parses 3-byte UTF-8 character" do
      # € is 0xE2 0x82 0xAC
      {events, remaining} = EscapeParser.parse("€")
      assert remaining == <<>>
      assert [%Event.Key{key: "€"}] = events
    end

    test "parses 4-byte UTF-8 character" do
      # 😀 is 0xF0 0x9F 0x98 0x80
      {events, remaining} = EscapeParser.parse("😀")
      assert remaining == <<>>
      assert [%Event.Key{key: "😀"}] = events
    end
  end

  describe "parse/1 - incomplete sequences" do
    test "returns partial escape sequence" do
      {events, remaining} = EscapeParser.parse("\e")
      assert events == []
      assert remaining == "\e"
    end

    test "returns partial CSI sequence" do
      {events, remaining} = EscapeParser.parse("\e[")
      assert events == []
      assert remaining == "\e["
    end

    test "returns partial CSI with numbers" do
      {events, remaining} = EscapeParser.parse("\e[1;")
      assert events == []
      assert remaining == "\e[1;"
    end

    test "returns partial SS3 sequence" do
      {events, remaining} = EscapeParser.parse("\eO")
      assert events == []
      assert remaining == "\eO"
    end
  end

  describe "parse/1 - empty input" do
    test "returns empty list for empty input" do
      {events, remaining} = EscapeParser.parse("")
      assert events == []
      assert remaining == ""
    end
  end

  describe "partial_sequence?/1" do
    test "returns true for lone ESC" do
      assert EscapeParser.partial_sequence?("\e") == true
    end

    test "returns true for ESC[" do
      assert EscapeParser.partial_sequence?("\e[") == true
    end

    test "returns true for ESC[ with numbers" do
      assert EscapeParser.partial_sequence?("\e[1") == true
      assert EscapeParser.partial_sequence?("\e[1;") == true
      assert EscapeParser.partial_sequence?("\e[1;2") == true
    end

    test "returns true for ESCO" do
      assert EscapeParser.partial_sequence?("\eO") == true
    end

    test "returns false for complete sequences" do
      assert EscapeParser.partial_sequence?("a") == false
      assert EscapeParser.partial_sequence?("\e[A") == false
    end

    test "returns false for empty input" do
      assert EscapeParser.partial_sequence?("") == false
    end
  end
end
