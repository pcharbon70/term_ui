defmodule TermUI.Widgets.StreamWidgetTest do
  use ExUnit.Case, async: true

  alias TermUI.Event
  alias TermUI.Widgets.StreamWidget

  @area %{x: 0, y: 0, width: 80, height: 24}

  describe "new/1" do
    test "creates props with defaults" do
      props = StreamWidget.new([])

      assert props.buffer_size == 1000
      assert props.overflow_strategy == :drop_oldest
      assert props.demand == 10
      assert props.show_stats == true
      assert props.render_rate_ms == 100
      assert is_function(props.item_renderer, 1)
    end

    test "creates props with custom values" do
      props =
        StreamWidget.new(
          buffer_size: 500,
          overflow_strategy: :block,
          demand: 20,
          show_stats: false
        )

      assert props.buffer_size == 500
      assert props.overflow_strategy == :block
      assert props.demand == 20
      assert props.show_stats == false
    end
  end

  describe "init/1" do
    test "initializes with empty buffer" do
      props = StreamWidget.new([])
      {:ok, state} = StreamWidget.init(props)

      assert state.buffer_count == 0
      assert state.scroll_offset == 0
      assert state.cursor == 0
      assert state.paused == false
      assert state.stream_state == :idle
    end

    test "initializes stats" do
      props = StreamWidget.new([])
      {:ok, state} = StreamWidget.init(props)

      assert state.stats.items_received == 0
      assert state.stats.items_dropped == 0
      assert state.stats.items_per_second == 0.0
      assert state.stats.buffer_size == 0
      assert state.stats.buffer_capacity == 1000
    end
  end

  describe "add_item/2 and add_items/2" do
    test "adds single item to buffer" do
      props = StreamWidget.new([])
      {:ok, state} = StreamWidget.init(props)

      {:ok, state} = StreamWidget.add_item(state, "test item")

      assert StreamWidget.buffer_count(state) == 1
      [item] = StreamWidget.get_items(state)
      assert item.data == "test item"
    end

    test "adds multiple items to buffer" do
      props = StreamWidget.new([])
      {:ok, state} = StreamWidget.init(props)

      {:ok, state} = StreamWidget.add_items(state, ["item1", "item2", "item3"])

      assert StreamWidget.buffer_count(state) == 3
      items = StreamWidget.get_items(state)
      assert Enum.map(items, & &1.data) == ["item1", "item2", "item3"]
    end

    test "updates stats when adding items" do
      props = StreamWidget.new([])
      {:ok, state} = StreamWidget.init(props)

      {:ok, state} = StreamWidget.add_items(state, ["a", "b", "c"])

      stats = StreamWidget.get_stats(state)
      assert stats.items_received == 3
      assert stats.buffer_size == 3
    end

    test "calls on_item callback" do
      test_pid = self()

      props =
        StreamWidget.new(on_item: fn item -> send(test_pid, {:item_received, item}) end)

      {:ok, state} = StreamWidget.init(props)

      {:ok, _state} = StreamWidget.add_item(state, "callback test")

      assert_receive {:item_received, "callback test"}
    end
  end

  describe "buffer overflow strategies" do
    test "drop_oldest removes oldest items" do
      props = StreamWidget.new(buffer_size: 3, overflow_strategy: :drop_oldest)
      {:ok, state} = StreamWidget.init(props)

      {:ok, state} = StreamWidget.add_items(state, ["a", "b", "c"])
      assert StreamWidget.buffer_count(state) == 3

      {:ok, state} = StreamWidget.add_item(state, "d")
      assert StreamWidget.buffer_count(state) == 3

      items = StreamWidget.get_items(state)
      assert Enum.map(items, & &1.data) == ["b", "c", "d"]
    end

    test "drop_newest rejects new items when full" do
      props = StreamWidget.new(buffer_size: 3, overflow_strategy: :drop_newest)
      {:ok, state} = StreamWidget.init(props)

      {:ok, state} = StreamWidget.add_items(state, ["a", "b", "c"])
      {:ok, state} = StreamWidget.add_item(state, "d")

      assert StreamWidget.buffer_count(state) == 3
      items = StreamWidget.get_items(state)
      assert Enum.map(items, & &1.data) == ["a", "b", "c"]

      stats = StreamWidget.get_stats(state)
      assert stats.items_dropped == 1
    end

    test "block strategy rejects items when full" do
      props = StreamWidget.new(buffer_size: 3, overflow_strategy: :block)
      {:ok, state} = StreamWidget.init(props)

      {:ok, state} = StreamWidget.add_items(state, ["a", "b", "c"])
      {:ok, state} = StreamWidget.add_item(state, "d")

      assert StreamWidget.buffer_count(state) == 3

      stats = StreamWidget.get_stats(state)
      assert stats.items_dropped == 1
    end

    test "sliding strategy acts like drop_oldest" do
      props = StreamWidget.new(buffer_size: 3, overflow_strategy: :sliding)
      {:ok, state} = StreamWidget.init(props)

      {:ok, state} = StreamWidget.add_items(state, ["a", "b", "c", "d", "e"])

      items = StreamWidget.get_items(state)
      assert Enum.map(items, & &1.data) == ["c", "d", "e"]
    end
  end

  describe "pause/resume" do
    test "pause sets paused state" do
      props = StreamWidget.new([])
      {:ok, state} = StreamWidget.init(props)

      {:ok, state} = StreamWidget.pause(state)

      assert StreamWidget.paused?(state) == true
    end

    test "resume clears paused state" do
      props = StreamWidget.new([])
      {:ok, state} = StreamWidget.init(props)
      {:ok, state} = StreamWidget.pause(state)

      {:ok, state} = StreamWidget.resume(state)

      assert StreamWidget.paused?(state) == false
    end

    test "space key toggles pause" do
      props = StreamWidget.new([])
      {:ok, state} = StreamWidget.init(props)

      {:ok, state} = StreamWidget.handle_event(%Event.Key{char: " "}, state)
      assert StreamWidget.paused?(state) == true

      {:ok, state} = StreamWidget.handle_event(%Event.Key{char: " "}, state)
      assert StreamWidget.paused?(state) == false
    end
  end

  describe "clear/1" do
    test "clears all items from buffer" do
      props = StreamWidget.new([])
      {:ok, state} = StreamWidget.init(props)

      {:ok, state} = StreamWidget.add_items(state, ["a", "b", "c"])
      assert StreamWidget.buffer_count(state) == 3

      {:ok, state} = StreamWidget.clear(state)

      assert StreamWidget.buffer_count(state) == 0
      assert StreamWidget.get_items(state) == []
    end

    test "resets cursor and scroll" do
      props = StreamWidget.new([])
      {:ok, state} = StreamWidget.init(props)

      {:ok, state} = StreamWidget.add_items(state, Enum.map(1..50, &"item #{&1}"))
      {:ok, state} = StreamWidget.handle_event(%Event.Key{key: :end}, state)

      {:ok, state} = StreamWidget.clear(state)

      assert state.cursor == 0
      assert state.scroll_offset == 0
    end

    test "c key clears buffer" do
      props = StreamWidget.new([])
      {:ok, state} = StreamWidget.init(props)

      {:ok, state} = StreamWidget.add_items(state, ["a", "b", "c"])
      {:ok, state} = StreamWidget.handle_event(%Event.Key{char: "c"}, state)

      assert StreamWidget.buffer_count(state) == 0
    end
  end

  describe "navigation" do
    setup do
      props = StreamWidget.new([])
      {:ok, state} = StreamWidget.init(props)
      items = Enum.map(1..50, &"item #{&1}")
      {:ok, state} = StreamWidget.add_items(state, items)
      {:ok, state: state}
    end

    test "up key moves cursor up", %{state: state} do
      {:ok, state} = StreamWidget.handle_event(%Event.Key{key: :down}, state)
      {:ok, state} = StreamWidget.handle_event(%Event.Key{key: :down}, state)
      assert state.cursor == 2

      {:ok, state} = StreamWidget.handle_event(%Event.Key{key: :up}, state)
      assert state.cursor == 1
    end

    test "down key moves cursor down", %{state: state} do
      {:ok, state} = StreamWidget.handle_event(%Event.Key{key: :down}, state)
      assert state.cursor == 1
    end

    test "home key goes to first item", %{state: state} do
      {:ok, state} = StreamWidget.handle_event(%Event.Key{key: :end}, state)
      {:ok, state} = StreamWidget.handle_event(%Event.Key{key: :home}, state)

      assert state.cursor == 0
      assert state.scroll_offset == 0
    end

    test "end key goes to last item", %{state: state} do
      {:ok, state} = StreamWidget.handle_event(%Event.Key{key: :end}, state)

      assert state.cursor == 49
    end

    test "page_up moves by page size", %{state: state} do
      {:ok, state} = StreamWidget.handle_event(%Event.Key{key: :end}, state)
      {:ok, state} = StreamWidget.handle_event(%Event.Key{key: :page_up}, state)

      assert state.cursor == 29
    end

    test "page_down moves by page size", %{state: state} do
      {:ok, state} = StreamWidget.handle_event(%Event.Key{key: :page_down}, state)

      assert state.cursor == 20
    end

    test "cursor stays in bounds" do
      props = StreamWidget.new([])
      {:ok, state} = StreamWidget.init(props)
      {:ok, state} = StreamWidget.add_items(state, ["a", "b"])

      {:ok, state} = StreamWidget.handle_event(%Event.Key{key: :up}, state)
      assert state.cursor == 0

      {:ok, state} = StreamWidget.handle_event(%Event.Key{key: :end}, state)
      {:ok, state} = StreamWidget.handle_event(%Event.Key{key: :down}, state)
      assert state.cursor == 1
    end
  end

  describe "set_buffer_size/2" do
    test "increases buffer capacity" do
      props = StreamWidget.new(buffer_size: 10)
      {:ok, state} = StreamWidget.init(props)

      {:ok, state} = StreamWidget.set_buffer_size(state, 20)

      stats = StreamWidget.get_stats(state)
      assert stats.buffer_capacity == 20
    end

    test "decreases buffer capacity and drops items" do
      props = StreamWidget.new(buffer_size: 10)
      {:ok, state} = StreamWidget.init(props)
      {:ok, state} = StreamWidget.add_items(state, Enum.map(1..10, &"item #{&1}"))

      {:ok, state} = StreamWidget.set_buffer_size(state, 5)

      assert StreamWidget.buffer_count(state) == 5
      items = StreamWidget.get_items(state)
      # Oldest items should be dropped
      assert Enum.map(items, & &1.data) == ["item 6", "item 7", "item 8", "item 9", "item 10"]
    end
  end

  describe "set_overflow_strategy/2" do
    test "changes overflow strategy" do
      props = StreamWidget.new(overflow_strategy: :drop_oldest)
      {:ok, state} = StreamWidget.init(props)

      {:ok, state} = StreamWidget.set_overflow_strategy(state, :block)

      assert state.overflow_strategy == :block
    end
  end

  describe "stats display toggle" do
    test "s key toggles stats visibility" do
      props = StreamWidget.new(show_stats: true)
      {:ok, state} = StreamWidget.init(props)

      {:ok, state} = StreamWidget.handle_event(%Event.Key{char: "s"}, state)
      assert state.show_stats == false

      {:ok, state} = StreamWidget.handle_event(%Event.Key{char: "s"}, state)
      assert state.show_stats == true
    end
  end

  describe "stream_state/1" do
    test "returns idle initially" do
      props = StreamWidget.new([])
      {:ok, state} = StreamWidget.init(props)

      assert StreamWidget.stream_state(state) == :idle
    end
  end

  describe "handle_info/2" do
    test "handles stream_items message" do
      props = StreamWidget.new([])
      {:ok, state} = StreamWidget.init(props)

      {:ok, state} = StreamWidget.handle_info({:stream_items, ["a", "b"]}, state)

      assert StreamWidget.buffer_count(state) == 2
    end

    test "handles stream_item message" do
      props = StreamWidget.new([])
      {:ok, state} = StreamWidget.init(props)

      {:ok, state} = StreamWidget.handle_info({:stream_item, "single"}, state)

      assert StreamWidget.buffer_count(state) == 1
    end

    test "handles consumer_started message" do
      props = StreamWidget.new([])
      {:ok, state} = StreamWidget.init(props)

      {:ok, state} = StreamWidget.handle_info({:consumer_started, self()}, state)

      assert state.consumer_pid == self()
      assert StreamWidget.stream_state(state) == :running
    end

    test "handles consumer_stopped message" do
      props = StreamWidget.new([])
      {:ok, state} = StreamWidget.init(props)
      {:ok, state} = StreamWidget.handle_info({:consumer_started, self()}, state)

      {:ok, state} = StreamWidget.handle_info({:consumer_stopped, :normal}, state)

      assert state.consumer_pid == nil
      assert StreamWidget.stream_state(state) == :idle
    end
  end

  describe "render/2" do
    test "renders empty buffer" do
      props = StreamWidget.new([])
      {:ok, state} = StreamWidget.init(props)

      result = StreamWidget.render(state, @area)

      assert result.type == :stack
      assert result.direction == :vertical
    end

    test "renders items in buffer" do
      props = StreamWidget.new([])
      {:ok, state} = StreamWidget.init(props)
      {:ok, state} = StreamWidget.add_items(state, ["line 1", "line 2"])

      result = StreamWidget.render(state, @area)

      assert result.type == :stack
      # Find text nodes with our content
      texts =
        result.children
        |> Enum.filter(&(&1.type == :text))
        |> Enum.map(& &1.content)

      assert "line 1" in texts
      assert "line 2" in texts
    end

    test "renders status bar when show_stats is true" do
      props = StreamWidget.new(show_stats: true)
      {:ok, state} = StreamWidget.init(props)
      {:ok, state} = StreamWidget.add_item(state, "test")

      result = StreamWidget.render(state, @area)

      texts =
        result.children
        |> Enum.filter(&(&1.type == :text))
        |> Enum.map(& &1.content)

      # Status bar should include buffer info
      status_text = Enum.find(texts, &String.contains?(&1, "Buffer:"))
      assert status_text != nil
    end

    test "hides status bar when show_stats is false" do
      props = StreamWidget.new(show_stats: false)
      {:ok, state} = StreamWidget.init(props)

      result = StreamWidget.render(state, @area)

      texts =
        result.children
        |> Enum.filter(&(&1.type == :text))
        |> Enum.map(& &1.content)

      # No status bar text
      status_text = Enum.find(texts, &String.contains?(&1, "Buffer:"))
      assert status_text == nil
    end

    test "truncates long items" do
      props = StreamWidget.new([])
      {:ok, state} = StreamWidget.init(props)
      long_text = String.duplicate("x", 200)
      {:ok, state} = StreamWidget.add_item(state, long_text)

      result = StreamWidget.render(state, %{@area | width: 50})

      texts =
        Enum.filter(result.children, fn child ->
          child.type == :text and String.contains?(child.content, "x")
        end)

      [truncated_text | _] = texts
      assert String.length(truncated_text.content) <= 50
      assert String.ends_with?(truncated_text.content, "...")
    end
  end

  describe "custom item renderer" do
    test "uses custom renderer function" do
      props =
        StreamWidget.new(
          item_renderer: fn item ->
            "[CUSTOM] #{item.data}"
          end
        )

      {:ok, state} = StreamWidget.init(props)
      {:ok, state} = StreamWidget.add_item(state, "hello")

      result = StreamWidget.render(state, @area)

      texts =
        result.children
        |> Enum.filter(&(&1.type == :text))
        |> Enum.map(& &1.content)

      assert Enum.any?(texts, &String.contains?(&1, "[CUSTOM] hello"))
    end
  end

  describe "items per second calculation" do
    test "calculates rate based on received items" do
      props = StreamWidget.new([])
      {:ok, state} = StreamWidget.init(props)

      # Add items
      {:ok, state} = StreamWidget.add_items(state, Enum.to_list(1..100))

      stats = StreamWidget.get_stats(state)
      # Rate should be positive after adding items
      assert stats.items_per_second >= 0
      assert stats.items_received == 100
    end
  end
end
