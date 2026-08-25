defmodule TermUI.Terminal.EscapeParserTest do
  use ExUnit.Case, async: true

  alias TermUI.Event
  alias TermUI.Terminal.EscapeParser

  test "rejects zero SGR mouse coordinates without raising" do
    assert {[%TermUI.Event.Key{key: :unknown}], ""} =
             EscapeParser.parse("\e[<0;0;0M")
  end

  describe "parse/1 - single characters" do
    test "parses lowercase letters" do
      {events, remaining} = EscapeParser.parse("a")
      assert remaining == <<>>
      assert [%Event.Text{text: "a"}] = events
    end

    test "parses uppercase letters" do
      {events, remaining} = EscapeParser.parse("A")
      assert remaining == <<>>
      assert [%Event.Text{text: "A"}] = events
    end

    test "parses numbers" do
      {events, remaining} = EscapeParser.parse("5")
      assert remaining == <<>>
      assert [%Event.Text{text: "5"}] = events
    end

    test "parses special characters" do
      {events, remaining} = EscapeParser.parse("@")
      assert remaining == <<>>
      assert [%Event.Text{text: "@"}] = events
    end

    test "parses space as text" do
      {events, remaining} = EscapeParser.parse(" ")
      assert remaining == <<>>
      assert [%Event.Text{text: " "}] = events
    end

    test "parses multiple characters" do
      {events, remaining} = EscapeParser.parse("abc")
      assert remaining == <<>>
      assert length(events) == 3
      assert [%Event.Text{text: "a"}, %Event.Text{text: "b"}, %Event.Text{text: "c"}] = events
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
    test "parses Shift+Tab (ESC[Z)" do
      {events, remaining} = EscapeParser.parse("\e[Z")
      assert remaining == <<>>
      assert [%Event.Key{key: :tab, modifiers: modifiers}] = events
      assert :shift in modifiers
    end

    test "parses Shift+Tab variant (ESC[1;2Z)" do
      {events, remaining} = EscapeParser.parse("\e[1;2Z")
      assert remaining == <<>>
      assert [%Event.Key{key: :tab, modifiers: modifiers}] = events
      assert :shift in modifiers
      refute :alt in modifiers
      refute :ctrl in modifiers
    end

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
      assert [%Event.Text{text: "é"}] = events
    end

    test "parses 3-byte UTF-8 character" do
      # € is 0xE2 0x82 0xAC
      {events, remaining} = EscapeParser.parse("€")
      assert remaining == <<>>
      assert [%Event.Text{text: "€"}] = events
    end

    test "parses 4-byte UTF-8 character" do
      # 😀 is 0xF0 0x9F 0x98 0x80
      {events, remaining} = EscapeParser.parse("😀")
      assert remaining == <<>>
      assert [%Event.Text{text: "😀"}] = events
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

    test "returns a partial X10 mouse prefix until its payload is complete" do
      {events, remaining} = EscapeParser.parse("\e[M")

      assert events == []
      assert remaining == "\e[M"
      assert EscapeParser.partial_sequence?(remaining)

      assert {[%Event.Mouse{action: :release, button: nil}], ""} =
               EscapeParser.parse(remaining <> "#!!")
    end

    test "returns partial SS3 sequence" do
      {events, remaining} = EscapeParser.parse("\eO")
      assert events == []
      assert remaining == "\eO"
    end

    test "consumes an unsupported complete CSI sequence without emitting its parameters as text" do
      {events, remaining} = EscapeParser.parse("\e[1;2Hx")

      assert [%Event.Key{key: :unknown}, %Event.Text{text: "x"}] = events
      assert remaining == ""
    end

    test "consumes a private CSI sequence without emitting its parameters as text" do
      {events, remaining} = EscapeParser.parse("\e[?25h")

      assert [%Event.Key{key: :unknown}] = events
      assert remaining == ""
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

    test "returns true for in-flight bracketed paste" do
      assert EscapeParser.partial_sequence?("\e[200~partial content not yet ended") == true
    end
  end

  describe "parse/1 - bracketed paste" do
    test "parses a complete bracketed-paste sequence into a Paste event" do
      input = "\e[200~hello\nworld\e[201~"
      {events, remaining} = EscapeParser.parse(input)

      assert [%TermUI.Event.Paste{content: "hello\nworld"}] = events
      assert remaining == ""
    end

    test "preserves bytes after the paste end marker" do
      input = "\e[200~abc\e[201~xyz"
      {events, remaining} = EscapeParser.parse(input)

      assert [%TermUI.Event.Paste{content: "abc"}, %TermUI.Event.Text{text: "x"} | _] = events
      assert remaining == ""
    end

    test "incomplete paste (no end marker) is buffered" do
      input = "\e[200~not finished yet"
      {events, remaining} = EscapeParser.parse(input)

      assert events == []
      assert remaining == input
    end

    test "preserves embedded escape sequences inside paste body" do
      input = "\e[200~line1\nline2\nline3\e[201~"
      {events, _remaining} = EscapeParser.parse(input)

      assert [%TermUI.Event.Paste{content: "line1\nline2\nline3"}] = events
    end

    test "bails out with a Paste event when an unterminated paste exceeds the buffer cap" do
      # Just over 8 MiB of body, no \e[201~ end marker.
      oversized = :binary.copy("x", 8 * 1024 * 1024 + 1)
      input = "\e[200~" <> oversized
      {events, remaining} = EscapeParser.parse(input)

      assert [%TermUI.Event.Paste{content: ^oversized}] = events
      assert remaining == ""
    end
  end

  describe "parse/1 - focus tracking" do
    test "parses focus gain and focus loss" do
      {events, remaining} = EscapeParser.parse("\e[I\e[O")

      assert [
               %TermUI.Event.Focus{action: :gained},
               %TermUI.Event.Focus{action: :lost}
             ] = events

      assert remaining == ""
    end
  end

  describe "parse/1 - X10 mouse input" do
    test "parses an X10 left-button press with zero-based coordinates" do
      {events, remaining} = EscapeParser.parse("\e[M !!")

      assert [%TermUI.Event.Mouse{action: :press, button: :left, x: 0, y: 0}] = events
      assert remaining == ""
    end

    test "parses an X10 button release without inventing a button" do
      {events, remaining} = EscapeParser.parse("\e[M#!!")

      assert [%TermUI.Event.Mouse{action: :release, button: nil, x: 0, y: 0}] = events
      assert remaining == ""
    end
  end

  describe "parse/1 - SGR mouse input" do
    test "preserves the released mouse button" do
      {middle_events, ""} = EscapeParser.parse("\e[<1;5;6m")
      {right_events, ""} = EscapeParser.parse("\e[<2;7;8m")

      assert [%Event.Mouse{action: :release, button: :middle, x: 4, y: 5}] = middle_events
      assert [%Event.Mouse{action: :release, button: :right, x: 6, y: 7}] = right_events
    end
  end
end
