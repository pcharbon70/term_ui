defmodule TermUI.Event.TransformationTest do
  use ExUnit.Case, async: true

  alias TermUI.Event
  alias TermUI.Event.Transformation

  describe "to_local/2" do
    test "transforms mouse coordinates to component-local" do
      event = Event.mouse(:click, :left, 15, 10)
      bounds = %{x: 10, y: 5, width: 20, height: 10}

      result = Transformation.to_local(event, bounds)

      assert result.x == 5
      assert result.y == 5
    end

    test "handles coordinates at origin" do
      event = Event.mouse(:click, :left, 10, 5)
      bounds = %{x: 10, y: 5, width: 20, height: 10}

      result = Transformation.to_local(event, bounds)

      assert result.x == 0
      assert result.y == 0
    end

    test "preserves other event properties" do
      event = Event.mouse(:click, :left, 15, 10, modifiers: [:ctrl])
      bounds = %{x: 10, y: 5, width: 20, height: 10}

      result = Transformation.to_local(event, bounds)

      assert result.action == :click
      assert result.button == :left
      assert result.modifiers == [:ctrl]
    end

    test "returns non-mouse events unchanged" do
      event = Event.key(:enter)
      bounds = %{x: 10, y: 5, width: 20, height: 10}

      result = Transformation.to_local(event, bounds)

      assert result == event
    end
  end

  describe "to_screen/2" do
    test "transforms local coordinates to screen" do
      event = Event.mouse(:click, :left, 5, 5)
      bounds = %{x: 10, y: 5, width: 20, height: 10}

      result = Transformation.to_screen(event, bounds)

      assert result.x == 15
      assert result.y == 10
    end

    test "inverse of to_local" do
      original = Event.mouse(:click, :left, 15, 10)
      bounds = %{x: 10, y: 5, width: 20, height: 10}

      local = Transformation.to_local(original, bounds)
      screen = Transformation.to_screen(local, bounds)

      assert screen.x == original.x
      assert screen.y == original.y
    end
  end

  describe "with_metadata/2" do
    test "adds metadata to event" do
      event = Event.key(:enter)
      result = Transformation.with_metadata(event, %{target: :button})

      assert result.metadata == %{target: :button}
    end

    test "merges with existing metadata" do
      event = Event.key(:enter) |> Map.put(:metadata, %{existing: true})
      result = Transformation.with_metadata(event, %{new: :value})

      assert result.metadata == %{existing: true, new: :value}
    end

    test "overwrites conflicting keys" do
      event = Event.key(:enter) |> Map.put(:metadata, %{key: :old})
      result = Transformation.with_metadata(event, %{key: :new})

      assert result.metadata == %{key: :new}
    end
  end

  describe "get_metadata/3" do
    test "retrieves metadata value" do
      event = %{metadata: %{target: :button}}

      assert Transformation.get_metadata(event, :target) == :button
    end

    test "returns default when key not found" do
      event = %{metadata: %{}}

      assert Transformation.get_metadata(event, :missing, :default) == :default
    end

    test "returns nil default when key not found" do
      event = %{metadata: %{}}

      assert Transformation.get_metadata(event, :missing) == nil
    end

    test "returns default when no metadata" do
      event = %{}

      assert Transformation.get_metadata(event, :key, :default) == :default
    end
  end

  describe "matches?/2" do
    test "matches event type" do
      key_event = Event.key(:enter)
      mouse_event = Event.mouse(:click, :left, 0, 0)

      assert Transformation.matches?(key_event, type: :key)
      assert Transformation.matches?(mouse_event, type: :mouse)
      refute Transformation.matches?(key_event, type: :mouse)
    end

    test "matches specific key" do
      event = Event.key(:enter)

      assert Transformation.matches?(event, key: :enter)
      refute Transformation.matches?(event, key: :escape)
    end

    test "matches action" do
      click = Event.mouse(:click, :left, 0, 0)
      move = Event.mouse(:move, nil, 0, 0)

      assert Transformation.matches?(click, action: :click)
      assert Transformation.matches?(move, action: :move)
      refute Transformation.matches?(click, action: :move)
    end

    test "matches button" do
      left = Event.mouse(:click, :left, 0, 0)
      right = Event.mouse(:click, :right, 0, 0)

      assert Transformation.matches?(left, button: :left)
      assert Transformation.matches?(right, button: :right)
      refute Transformation.matches?(left, button: :right)
    end

    test "matches all modifiers with modifiers_all" do
      event = Event.key(:c, modifiers: [:ctrl, :shift])

      assert Transformation.matches?(event, modifiers_all: [:ctrl])
      assert Transformation.matches?(event, modifiers_all: [:ctrl, :shift])
      refute Transformation.matches?(event, modifiers_all: [:ctrl, :alt])
    end

    test "matches any modifier with modifiers_any" do
      event = Event.key(:c, modifiers: [:ctrl])

      assert Transformation.matches?(event, modifiers_any: [:ctrl, :alt])
      refute Transformation.matches?(event, modifiers_any: [:shift, :alt])
    end

    test "matches multiple filters" do
      event = Event.key(:c, modifiers: [:ctrl])

      assert Transformation.matches?(event, type: :key, key: :c, modifiers_all: [:ctrl])
      refute Transformation.matches?(event, type: :key, key: :c, modifiers_all: [:shift])
    end

    test "empty filters match any event" do
      event = Event.key(:enter)

      assert Transformation.matches?(event, [])
    end
  end

  describe "filter/2" do
    test "filters list of events" do
      events = [
        Event.key(:a),
        Event.key(:b),
        Event.mouse(:click, :left, 0, 0)
      ]

      result = Transformation.filter(events, type: :key)

      assert length(result) == 2
      assert Enum.all?(result, &Event.key?/1)
    end

    test "returns empty list when no matches" do
      events = [Event.key(:a), Event.key(:b)]

      result = Transformation.filter(events, type: :mouse)

      assert result == []
    end

    test "filters by multiple criteria" do
      events = [
        Event.key(:c, modifiers: [:ctrl]),
        Event.key(:c),
        Event.key(:v, modifiers: [:ctrl])
      ]

      result = Transformation.filter(events, key: :c, modifiers_all: [:ctrl])

      assert length(result) == 1
      assert hd(result).key == :c
    end
  end

  describe "envelope/2" do
    test "creates envelope with routing metadata" do
      event = Event.key(:enter)
      result = Transformation.envelope(event, source: :terminal, target: :input)

      assert Transformation.get_metadata(result, :source) == :terminal
      assert Transformation.get_metadata(result, :target) == :input
      assert is_integer(Transformation.get_metadata(result, :routed_at))
    end

    test "allows custom timestamp" do
      event = Event.key(:enter)
      result = Transformation.envelope(event, timestamp: 12345)

      assert Transformation.get_metadata(result, :routed_at) == 12345
    end
  end
end
