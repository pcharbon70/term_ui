defmodule TermUI.EventTest do
  use ExUnit.Case, async: true

  alias TermUI.Event
  alias TermUI.Event.{Key, Mouse, Focus, Custom}

  describe "Key event" do
    test "creates key event with defaults" do
      event = Event.key(:enter)

      assert %Key{} = event
      assert event.key == :enter
      assert event.char == nil
      assert event.modifiers == []
      assert is_integer(event.timestamp)
    end

    test "creates key event with char" do
      event = Event.key(:a, char: "a")

      assert event.key == :a
      assert event.char == "a"
    end

    test "creates key event with modifiers" do
      event = Event.key(:c, modifiers: [:ctrl])

      assert event.key == :c
      assert event.modifiers == [:ctrl]
    end

    test "creates key event with multiple modifiers" do
      event = Event.key(:s, modifiers: [:ctrl, :shift])

      assert event.modifiers == [:ctrl, :shift]
    end

    test "creates key event with custom timestamp" do
      event = Event.key(:enter, timestamp: 12345)

      assert event.timestamp == 12345
    end

    test "key? returns true for key events" do
      event = Event.key(:enter)
      assert Event.key?(event)
    end

    test "key? returns false for non-key events" do
      refute Event.key?(%Mouse{})
      refute Event.key?(%Focus{})
      refute Event.key?("string")
      refute Event.key?(nil)
    end
  end

  describe "Mouse event" do
    test "creates mouse event with position" do
      event = Event.mouse(:click, :left, 10, 20)

      assert %Mouse{} = event
      assert event.action == :click
      assert event.button == :left
      assert event.x == 10
      assert event.y == 20
      assert event.modifiers == []
      assert is_integer(event.timestamp)
    end

    test "creates move event without button" do
      event = Event.mouse(:move, nil, 15, 25)

      assert event.action == :move
      assert event.button == nil
    end

    test "creates scroll event" do
      event = Event.mouse(:scroll_up, nil, 10, 10)

      assert event.action == :scroll_up
    end

    test "creates mouse event with modifiers" do
      event = Event.mouse(:click, :left, 5, 5, modifiers: [:shift])

      assert event.modifiers == [:shift]
    end

    test "mouse? returns true for mouse events" do
      event = Event.mouse(:click, :left, 0, 0)
      assert Event.mouse?(event)
    end

    test "mouse? returns false for non-mouse events" do
      refute Event.mouse?(%Key{})
      refute Event.mouse?(%Focus{})
    end
  end

  describe "Focus event" do
    test "creates focus gained event" do
      event = Event.focus(:gained)

      assert %Focus{} = event
      assert event.action == :gained
      assert is_integer(event.timestamp)
    end

    test "creates focus lost event" do
      event = Event.focus(:lost)

      assert event.action == :lost
    end

    test "focus? returns true for focus events" do
      event = Event.focus(:gained)
      assert Event.focus?(event)
    end

    test "focus? returns false for non-focus events" do
      refute Event.focus?(%Key{})
      refute Event.focus?(%Mouse{})
    end
  end

  describe "Custom event" do
    test "creates custom event with name" do
      event = Event.custom(:submit)

      assert %Custom{} = event
      assert event.name == :submit
      assert event.payload == nil
      assert is_integer(event.timestamp)
    end

    test "creates custom event with payload" do
      event = Event.custom(:submit, %{value: "hello"})

      assert event.name == :submit
      assert event.payload == %{value: "hello"}
    end

    test "custom? returns true for custom events" do
      event = Event.custom(:test)
      assert Event.custom?(event)
    end

    test "custom? returns false for non-custom events" do
      refute Event.custom?(%Key{})
      refute Event.custom?(%Mouse{})
    end
  end

  describe "type/1" do
    test "returns :key for key events" do
      assert Event.type(%Key{}) == :key
    end

    test "returns :mouse for mouse events" do
      assert Event.type(%Mouse{}) == :mouse
    end

    test "returns :focus for focus events" do
      assert Event.type(%Focus{}) == :focus
    end

    test "returns :custom for custom events" do
      assert Event.type(%Custom{}) == :custom
    end
  end

  describe "has_modifier?/2" do
    test "returns true when modifier present in key event" do
      event = Event.key(:c, modifiers: [:ctrl, :shift])

      assert Event.has_modifier?(event, :ctrl)
      assert Event.has_modifier?(event, :shift)
    end

    test "returns false when modifier not present" do
      event = Event.key(:c, modifiers: [:ctrl])

      refute Event.has_modifier?(event, :shift)
      refute Event.has_modifier?(event, :alt)
    end

    test "works with mouse events" do
      event = Event.mouse(:click, :left, 0, 0, modifiers: [:ctrl])

      assert Event.has_modifier?(event, :ctrl)
      refute Event.has_modifier?(event, :shift)
    end
  end
end
