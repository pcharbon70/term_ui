defmodule TermUI.Test.ComponentHarnessTest do
  use ExUnit.Case, async: true

  alias TermUI.Event
  alias TermUI.Test.ComponentHarness
  alias TermUI.Test.TestRenderer

  # Test component for harness testing
  defmodule Counter do
    import TermUI.Component.Helpers

    def init(props) do
      %{count: Keyword.get(props, :initial, 0)}
    end

    def render(state) do
      text("Count: #{state.count}")
    end

    def handle_event(%Event.Key{key: :up}, state) do
      {:noreply, %{state | count: state.count + 1}}
    end

    def handle_event(%Event.Key{key: :down}, state) do
      {:noreply, %{state | count: max(0, state.count - 1)}}
    end

    def handle_event(_event, state) do
      {:noreply, state}
    end
  end

  # Simple component without events
  defmodule StaticLabel do
    import TermUI.Component.Helpers

    def init(props) do
      %{text: Keyword.get(props, :text, "Label")}
    end

    def render(state) do
      text(state.text)
    end
  end

  describe "mount_test/2" do
    test "mounts component with default dimensions" do
      {:ok, harness} = ComponentHarness.mount_test(Counter)
      assert harness.module == Counter
      assert harness.state == %{count: 0}
      ComponentHarness.unmount(harness)
    end

    test "mounts component with initial props" do
      {:ok, harness} = ComponentHarness.mount_test(Counter, initial: 10)
      assert harness.state == %{count: 10}
      ComponentHarness.unmount(harness)
    end

    test "creates renderer with custom dimensions" do
      {:ok, harness} = ComponentHarness.mount_test(Counter, width: 40, height: 10)
      {rows, cols} = TestRenderer.dimensions(harness.renderer)
      assert rows == 10
      assert cols == 40
      ComponentHarness.unmount(harness)
    end
  end

  describe "unmount/1" do
    test "cleans up renderer" do
      {:ok, harness} = ComponentHarness.mount_test(Counter)
      assert :ok = ComponentHarness.unmount(harness)
    end
  end

  describe "render/1" do
    test "renders component to buffer" do
      {:ok, harness} = ComponentHarness.mount_test(Counter, initial: 5)
      harness = ComponentHarness.render(harness)

      renderer = ComponentHarness.get_renderer(harness)
      assert TestRenderer.text_at?(renderer, 1, 1, "Count: 5")
      ComponentHarness.unmount(harness)
    end

    test "stores render result" do
      {:ok, harness} = ComponentHarness.mount_test(Counter)
      harness = ComponentHarness.render(harness)

      render = ComponentHarness.get_render(harness)
      assert render != nil
      ComponentHarness.unmount(harness)
    end
  end

  describe "send_event/2" do
    test "updates component state" do
      {:ok, harness} = ComponentHarness.mount_test(Counter, initial: 5)

      harness = ComponentHarness.send_event(harness, Event.key(:up))
      assert ComponentHarness.get_state(harness) == %{count: 6}

      harness = ComponentHarness.send_event(harness, Event.key(:down))
      assert ComponentHarness.get_state(harness) == %{count: 5}

      ComponentHarness.unmount(harness)
    end

    test "stores sent events" do
      {:ok, harness} = ComponentHarness.mount_test(Counter)

      harness = ComponentHarness.send_event(harness, Event.key(:up))
      harness = ComponentHarness.send_event(harness, Event.key(:up))

      events = ComponentHarness.get_events(harness)
      assert length(events) == 2
      ComponentHarness.unmount(harness)
    end

    test "handles unhandled events gracefully" do
      {:ok, harness} = ComponentHarness.mount_test(StaticLabel, text: "Test")

      # StaticLabel doesn't have handle_event
      harness = ComponentHarness.send_event(harness, Event.key(:enter))
      assert harness.state == %{text: "Test"}
      ComponentHarness.unmount(harness)
    end
  end

  describe "send_events/2" do
    test "sends multiple events in sequence" do
      {:ok, harness} = ComponentHarness.mount_test(Counter, initial: 0)

      events = [
        Event.key(:up),
        Event.key(:up),
        Event.key(:up)
      ]

      harness = ComponentHarness.send_events(harness, events)
      assert ComponentHarness.get_state(harness) == %{count: 3}
      ComponentHarness.unmount(harness)
    end
  end

  describe "get_state/1" do
    test "returns current state" do
      {:ok, harness} = ComponentHarness.mount_test(Counter, initial: 42)
      assert ComponentHarness.get_state(harness) == %{count: 42}
      ComponentHarness.unmount(harness)
    end
  end

  describe "get_renderer/1" do
    test "returns test renderer" do
      {:ok, harness} = ComponentHarness.mount_test(Counter)
      renderer = ComponentHarness.get_renderer(harness)
      assert %TestRenderer{} = renderer
      ComponentHarness.unmount(harness)
    end
  end

  describe "get_render/1" do
    test "returns nil before first render" do
      {:ok, harness} = ComponentHarness.mount_test(Counter)
      assert ComponentHarness.get_render(harness) == nil
      ComponentHarness.unmount(harness)
    end

    test "returns most recent render" do
      {:ok, harness} = ComponentHarness.mount_test(Counter)
      harness = ComponentHarness.render(harness)
      assert ComponentHarness.get_render(harness) != nil
      ComponentHarness.unmount(harness)
    end
  end

  describe "get_renders/1" do
    test "returns all render results" do
      {:ok, harness} = ComponentHarness.mount_test(Counter)

      harness = ComponentHarness.render(harness)
      harness = ComponentHarness.send_event(harness, Event.key(:up))
      harness = ComponentHarness.render(harness)

      renders = ComponentHarness.get_renders(harness)
      assert length(renders) == 2
      ComponentHarness.unmount(harness)
    end
  end

  describe "get_area/1" do
    test "returns render area" do
      {:ok, harness} = ComponentHarness.mount_test(Counter, width: 100, height: 50)
      area = ComponentHarness.get_area(harness)
      assert area.width == 100
      assert area.height == 50
      ComponentHarness.unmount(harness)
    end
  end

  describe "update_state/2" do
    test "updates state with function" do
      {:ok, harness} = ComponentHarness.mount_test(Counter, initial: 5)

      harness =
        ComponentHarness.update_state(harness, fn state ->
          %{state | count: state.count * 2}
        end)

      assert ComponentHarness.get_state(harness) == %{count: 10}
      ComponentHarness.unmount(harness)
    end
  end

  describe "set_state/2" do
    test "sets state directly" do
      {:ok, harness} = ComponentHarness.mount_test(Counter)

      harness = ComponentHarness.set_state(harness, %{count: 100})
      assert ComponentHarness.get_state(harness) == %{count: 100}
      ComponentHarness.unmount(harness)
    end
  end

  describe "get_state_at/2" do
    test "returns state value at path" do
      {:ok, harness} = ComponentHarness.mount_test(Counter, initial: 42)
      assert ComponentHarness.get_state_at(harness, [:count]) == 42
      ComponentHarness.unmount(harness)
    end
  end

  describe "render_cycle/1" do
    test "renders component and returns harness" do
      {:ok, harness} = ComponentHarness.mount_test(Counter)
      harness = ComponentHarness.render_cycle(harness)
      assert length(ComponentHarness.get_renders(harness)) == 1
      ComponentHarness.unmount(harness)
    end
  end

  describe "event_cycle/2" do
    test "sends event and renders" do
      {:ok, harness} = ComponentHarness.mount_test(Counter, initial: 0)

      harness = ComponentHarness.event_cycle(harness, Event.key(:up))

      assert ComponentHarness.get_state(harness) == %{count: 1}
      assert length(ComponentHarness.get_renders(harness)) == 1
      ComponentHarness.unmount(harness)
    end
  end

  describe "reset/1" do
    test "resets to initial state" do
      {:ok, harness} = ComponentHarness.mount_test(Counter, initial: 5)

      harness = ComponentHarness.send_event(harness, Event.key(:up))
      harness = ComponentHarness.render(harness)
      assert ComponentHarness.get_state(harness) == %{count: 6}

      {:ok, harness} = ComponentHarness.reset(harness)
      assert ComponentHarness.get_state(harness) == %{count: 5}
      assert ComponentHarness.get_events(harness) == []
      assert ComponentHarness.get_renders(harness) == []
      ComponentHarness.unmount(harness)
    end
  end

  describe "integration test" do
    test "full component lifecycle" do
      # Mount
      {:ok, harness} = ComponentHarness.mount_test(Counter, initial: 0)

      # Initial render
      harness = ComponentHarness.render(harness)
      renderer = ComponentHarness.get_renderer(harness)
      assert TestRenderer.text_at?(renderer, 1, 1, "Count: 0")

      # Interact
      harness = ComponentHarness.send_event(harness, Event.key(:up))
      harness = ComponentHarness.send_event(harness, Event.key(:up))

      # Re-render
      harness = ComponentHarness.render(harness)
      assert TestRenderer.text_at?(renderer, 1, 1, "Count: 2")

      # Cleanup
      ComponentHarness.unmount(harness)
    end
  end
end
