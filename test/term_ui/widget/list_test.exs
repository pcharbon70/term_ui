defmodule TermUI.Widget.ListTest do
  use ExUnit.Case, async: true

  alias TermUI.Widget.List, as: ListWidget
  alias TermUI.Component.RenderNode
  alias TermUI.Event

  @area %{x: 0, y: 0, width: 20, height: 5}
  @items ["Apple", "Banana", "Cherry", "Date", "Elderberry", "Fig", "Grape"]

  describe "init/1" do
    test "initializes with default values" do
      {:ok, state} = ListWidget.init(%{})

      assert state.selected_index == 0
      assert state.selected_indices == MapSet.new()
      assert state.scroll_offset == 0
      assert state.item_count == 0
    end

    test "counts items from props" do
      {:ok, state} = ListWidget.init(%{items: @items})
      assert state.item_count == 7
    end

    test "stores props in state" do
      props = %{items: @items}
      {:ok, state} = ListWidget.init(props)
      assert state.props == props
    end
  end

  describe "handle_event/2 navigation" do
    test "down key moves selection down" do
      {:ok, state} = ListWidget.init(%{items: @items})
      {:ok, new_state} = ListWidget.handle_event(%Event.Key{key: :down}, state)

      assert new_state.selected_index == 1
    end

    test "up key moves selection up" do
      {:ok, state} = ListWidget.init(%{items: @items})
      state = %{state | selected_index: 3}
      {:ok, new_state} = ListWidget.handle_event(%Event.Key{key: :up}, state)

      assert new_state.selected_index == 2
    end

    test "up key stops at top" do
      {:ok, state} = ListWidget.init(%{items: @items})
      {:ok, new_state} = ListWidget.handle_event(%Event.Key{key: :up}, state)

      assert new_state.selected_index == 0
    end

    test "down key stops at bottom" do
      {:ok, state} = ListWidget.init(%{items: @items})
      state = %{state | selected_index: 6}
      {:ok, new_state} = ListWidget.handle_event(%Event.Key{key: :down}, state)

      assert new_state.selected_index == 6
    end

    test "home key moves to first item" do
      {:ok, state} = ListWidget.init(%{items: @items})
      state = %{state | selected_index: 5}
      {:ok, new_state} = ListWidget.handle_event(%Event.Key{key: :home}, state)

      assert new_state.selected_index == 0
    end

    test "end key moves to last item" do
      {:ok, state} = ListWidget.init(%{items: @items})
      {:ok, new_state} = ListWidget.handle_event(%Event.Key{key: :end}, state)

      assert new_state.selected_index == 6
    end

    test "page_up moves up by 10" do
      {:ok, state} = ListWidget.init(%{items: @items})
      state = %{state | selected_index: 6}
      {:ok, new_state} = ListWidget.handle_event(%Event.Key{key: :page_up}, state)

      assert new_state.selected_index == 0
    end

    test "page_down moves down by 10" do
      {:ok, state} = ListWidget.init(%{items: @items})
      {:ok, new_state} = ListWidget.handle_event(%Event.Key{key: :page_down}, state)

      assert new_state.selected_index == 6
    end
  end

  describe "handle_event/2 selection" do
    test "enter triggers select command" do
      {:ok, state} = ListWidget.init(%{items: @items})
      state = %{state | selected_index: 2}
      {:ok, _state, commands} = ListWidget.handle_event(%Event.Key{key: :enter}, state)

      assert [{:send, _pid, {:select, 2}}] = commands
    end

    test "space triggers toggle command" do
      {:ok, state} = ListWidget.init(%{items: @items})
      state = %{state | selected_index: 1}
      {:ok, _state, commands} = ListWidget.handle_event(%Event.Key{key: :space}, state)

      assert [{:send, _pid, {:toggle, 1}}] = commands
    end
  end

  describe "handle_info/2" do
    test "select message invokes callback" do
      test_pid = self()
      callback = fn item -> send(test_pid, {:selected, item}) end
      props = %{items: @items, on_select: callback}
      {:ok, state} = ListWidget.init(props)
      state = %{state | selected_index: 2}

      {:ok, _state} = ListWidget.handle_info({:select, 2}, state)
      assert_receive {:selected, "Cherry"}
    end

    test "toggle adds to selected_indices in multi-select" do
      props = %{items: @items, multi_select: true}
      {:ok, state} = ListWidget.init(props)

      {:ok, new_state} = ListWidget.handle_info({:toggle, 1}, state)
      assert MapSet.member?(new_state.selected_indices, 1)
    end

    test "toggle removes from selected_indices" do
      props = %{items: @items, multi_select: true}
      {:ok, state} = ListWidget.init(props)
      state = %{state | selected_indices: MapSet.new([1, 2])}

      {:ok, new_state} = ListWidget.handle_info({:toggle, 1}, state)
      refute MapSet.member?(new_state.selected_indices, 1)
      assert MapSet.member?(new_state.selected_indices, 2)
    end

    test "toggle does nothing without multi_select" do
      props = %{items: @items}
      {:ok, state} = ListWidget.init(props)

      {:ok, new_state} = ListWidget.handle_info({:toggle, 1}, state)
      assert new_state.selected_indices == MapSet.new()
    end

    test "set_items updates item count" do
      {:ok, state} = ListWidget.init(%{items: @items})
      {:ok, new_state} = ListWidget.handle_info({:set_items, ["A", "B", "C"]}, state)

      assert new_state.item_count == 3
    end

    test "set_items adjusts selection if needed" do
      {:ok, state} = ListWidget.init(%{items: @items})
      state = %{state | selected_index: 6}

      {:ok, new_state} = ListWidget.handle_info({:set_items, ["A", "B"]}, state)
      assert new_state.selected_index == 1
    end
  end

  describe "render/2" do
    test "renders visible items" do
      props = %{items: @items}
      {:ok, state} = ListWidget.init(props)
      result = ListWidget.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result

      # Check first row contains "Apple"
      row0 = Enum.filter(cells, fn c -> c.y == 0 end)
      text = Enum.map(row0, fn c -> c.cell.char end) |> Enum.join() |> String.trim()
      assert String.starts_with?(text, "Apple")
    end

    test "renders only as many items as height allows" do
      props = %{items: @items}
      {:ok, state} = ListWidget.init(props)
      result = ListWidget.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result

      # Should only render 5 rows (area height)
      max_y = Enum.max_by(cells, fn c -> c.y end).y
      assert max_y == 4
    end

    test "highlights selected item" do
      props = %{items: @items, highlight_style: %{fg: :black, bg: :white}}
      {:ok, state} = ListWidget.init(props)
      state = %{state | selected_index: 1}
      result = ListWidget.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result

      # Row 1 (Banana) should have highlight style
      row1 = Enum.filter(cells, fn c -> c.y == 1 end)
      first_cell = hd(row1)
      assert first_cell.cell.fg == :black
      assert first_cell.cell.bg == :white
    end

    test "renders multi-select indicators" do
      props = %{items: @items, multi_select: true}
      {:ok, state} = ListWidget.init(props)
      state = %{state | selected_indices: MapSet.new([1])}
      result = ListWidget.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result

      # Row 0 should have "[ ] "
      row0 = Enum.filter(cells, fn c -> c.y == 0 end)
      row0_text = Enum.map(row0, fn c -> c.cell.char end) |> Enum.join()
      assert String.starts_with?(row0_text, "[ ]")

      # Row 1 should have "[x] "
      row1 = Enum.filter(cells, fn c -> c.y == 1 end)
      row1_text = Enum.map(row1, fn c -> c.cell.char end) |> Enum.join()
      assert String.starts_with?(row1_text, "[x]")
    end

    test "truncates long items with ellipsis" do
      props = %{items: ["This is a very long item name that should be truncated"]}
      {:ok, state} = ListWidget.init(props)
      result = ListWidget.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      row0 = Enum.filter(cells, fn c -> c.y == 0 end)
      chars = Enum.map(row0, fn c -> c.cell.char end)
      assert List.last(chars) == "…"
    end

    test "scrolls to keep selection visible" do
      props = %{items: @items}
      {:ok, state} = ListWidget.init(props)
      state = %{state | selected_index: 6}  # Last item
      result = ListWidget.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result

      # Should have scrolled to show Grape
      row4 = Enum.filter(cells, fn c -> c.y == 4 end)
      text = Enum.map(row4, fn c -> c.cell.char end) |> Enum.join() |> String.trim()
      assert String.starts_with?(text, "Grape")
    end

    test "handles empty list" do
      props = %{items: []}
      {:ok, state} = ListWidget.init(props)
      result = ListWidget.render(state, @area)

      assert %RenderNode{type: :cells, cells: []} = result
    end

    test "applies custom style" do
      props = %{items: @items, style: %{fg: :green}}
      {:ok, state} = ListWidget.init(props)
      result = ListWidget.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      # Non-selected item should have green fg
      row1 = Enum.filter(cells, fn c -> c.y == 1 end)
      first_cell = hd(row1)
      assert first_cell.cell.fg == :green
    end
  end
end
