defmodule TermUI.Test.EventSimulatorTest do
  use ExUnit.Case, async: true

  alias TermUI.Test.EventSimulator
  alias TermUI.Event
  alias TermUI.Event.{Key, Mouse, Focus, Resize, Paste}

  describe "simulate_key/2" do
    test "creates key event" do
      event = EventSimulator.simulate_key(:enter)
      assert %Key{} = event
      assert event.key == :enter
    end

    test "includes character" do
      event = EventSimulator.simulate_key(:a, char: "a")
      assert event.char == "a"
    end

    test "includes modifiers" do
      event = EventSimulator.simulate_key(:c, modifiers: [:ctrl])
      assert :ctrl in event.modifiers
    end
  end

  describe "simulate_click/4" do
    test "creates click event at position" do
      event = EventSimulator.simulate_click(10, 20)
      assert %Mouse{} = event
      assert event.action == :click
      assert event.button == :left
      assert event.x == 10
      assert event.y == 20
    end

    test "supports different buttons" do
      event = EventSimulator.simulate_click(10, 20, :right)
      assert event.button == :right
    end

    test "includes modifiers" do
      event = EventSimulator.simulate_click(10, 20, :left, modifiers: [:ctrl])
      assert :ctrl in event.modifiers
    end
  end

  describe "simulate_double_click/4" do
    test "creates double click event" do
      event = EventSimulator.simulate_double_click(5, 10)
      assert event.action == :double_click
    end
  end

  describe "simulate_move/3" do
    test "creates move event" do
      event = EventSimulator.simulate_move(15, 25)
      assert event.action == :move
      assert event.x == 15
      assert event.y == 25
    end
  end

  describe "simulate_drag/4" do
    test "creates drag event" do
      event = EventSimulator.simulate_drag(10, 20)
      assert event.action == :drag
    end
  end

  describe "simulate_scroll_up/3" do
    test "creates scroll up event" do
      event = EventSimulator.simulate_scroll_up(10, 20)
      assert event.action == :scroll_up
    end
  end

  describe "simulate_scroll_down/3" do
    test "creates scroll down event" do
      event = EventSimulator.simulate_scroll_down(10, 20)
      assert event.action == :scroll_down
    end
  end

  describe "simulate_type/2" do
    test "creates events for each character" do
      events = EventSimulator.simulate_type("Hello")
      assert length(events) == 5
      assert Enum.all?(events, &match?(%Key{}, &1))
    end

    test "sets character on each event" do
      events = EventSimulator.simulate_type("Hi")
      assert hd(events).char == "H"
      assert List.last(events).char == "i"
    end

    test "adds shift for uppercase" do
      events = EventSimulator.simulate_type("A")
      assert :shift in hd(events).modifiers
    end

    test "handles special characters" do
      events = EventSimulator.simulate_type(" ")
      assert hd(events).key == :space
    end
  end

  describe "simulate_sequence/1" do
    test "creates events from key atoms" do
      events = EventSimulator.simulate_sequence([:tab, :enter])
      assert length(events) == 2
      assert hd(events).key == :tab
      assert List.last(events).key == :enter
    end

    test "handles key-options tuples" do
      events = EventSimulator.simulate_sequence([{:a, char: "a"}, :enter])
      assert hd(events).char == "a"
    end
  end

  describe "simulate_focus_gained/1" do
    test "creates focus gained event" do
      event = EventSimulator.simulate_focus_gained()
      assert %Focus{} = event
      assert event.action == :gained
    end
  end

  describe "simulate_focus_lost/1" do
    test "creates focus lost event" do
      event = EventSimulator.simulate_focus_lost()
      assert event.action == :lost
    end
  end

  describe "simulate_resize/3" do
    test "creates resize event" do
      event = EventSimulator.simulate_resize(120, 40)
      assert %Resize{} = event
      assert event.width == 120
      assert event.height == 40
    end
  end

  describe "simulate_paste/2" do
    test "creates paste event" do
      event = EventSimulator.simulate_paste("Hello, World!")
      assert %Paste{} = event
      assert event.content == "Hello, World!"
    end
  end

  describe "simulate_shortcut/1" do
    test "creates copy shortcut" do
      event = EventSimulator.simulate_shortcut(:copy)
      assert event.key == :c
      assert :ctrl in event.modifiers
    end

    test "creates paste shortcut" do
      event = EventSimulator.simulate_shortcut(:paste)
      assert event.key == :v
      assert :ctrl in event.modifiers
    end

    test "creates save shortcut" do
      event = EventSimulator.simulate_shortcut(:save)
      assert event.key == :s
      assert :ctrl in event.modifiers
    end

    test "creates quit shortcut" do
      event = EventSimulator.simulate_shortcut(:quit)
      assert event.key == :q
      assert :ctrl in event.modifiers
    end

    test "creates undo shortcut" do
      event = EventSimulator.simulate_shortcut(:undo)
      assert event.key == :z
      assert :ctrl in event.modifiers
    end

    test "creates redo shortcut" do
      event = EventSimulator.simulate_shortcut(:redo)
      assert event.key == :z
      assert :ctrl in event.modifiers
      assert :shift in event.modifiers
    end
  end

  describe "simulate_function_key/1" do
    test "creates function key events" do
      event = EventSimulator.simulate_function_key(1)
      assert event.key == :f1

      event = EventSimulator.simulate_function_key(12)
      assert event.key == :f12
    end
  end

  describe "simulate_navigation/2" do
    test "creates navigation key events" do
      event = EventSimulator.simulate_navigation(:up)
      assert event.key == :up

      event = EventSimulator.simulate_navigation(:page_down)
      assert event.key == :page_down
    end

    test "includes modifiers" do
      event = EventSimulator.simulate_navigation(:up, modifiers: [:shift])
      assert :shift in event.modifiers
    end
  end
end
