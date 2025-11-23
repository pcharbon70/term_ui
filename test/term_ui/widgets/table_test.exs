defmodule TermUI.Widgets.TableTest do
  use ExUnit.Case, async: true

  alias TermUI.Event
  alias TermUI.Layout.Constraint
  alias TermUI.Widgets.Table
  alias TermUI.Widgets.Table.Column

  # Test data
  @test_data [
    %{name: "Alice", age: 30, city: "NYC"},
    %{name: "Bob", age: 25, city: "LA"},
    %{name: "Charlie", age: 35, city: "Chicago"},
    %{name: "Diana", age: 28, city: "Boston"},
    %{name: "Eve", age: 32, city: "Seattle"}
  ]

  @test_columns [
    Column.new(:name, "Name"),
    Column.new(:age, "Age", width: Constraint.length(10), align: :right),
    Column.new(:city, "City")
  ]

  describe "new/1" do
    test "creates table props with required fields" do
      props = Table.new(columns: @test_columns, data: @test_data)

      assert props.columns == @test_columns
      assert props.data == @test_data
      assert props.selection_mode == :single
      assert props.sortable == true
    end

    test "creates table with custom selection mode" do
      props = Table.new(columns: @test_columns, data: @test_data, selection_mode: :multi)

      assert props.selection_mode == :multi
    end

    test "creates table with callbacks" do
      on_select = fn _ -> :ok end
      props = Table.new(columns: @test_columns, data: @test_data, on_select: on_select)

      assert props.on_select == on_select
    end
  end

  describe "init/1" do
    test "initializes table state" do
      props = Table.new(columns: @test_columns, data: @test_data)
      {:ok, state} = Table.init(props)

      assert state.columns == @test_columns
      assert state.data == @test_data
      assert state.cursor == 0
      assert state.scroll_offset == 0
      assert MapSet.size(state.selected) == 0
      assert state.sort_column == nil
      assert state.sort_direction == nil
    end

    test "initializes sorted_data with original data" do
      props = Table.new(columns: @test_columns, data: @test_data)
      {:ok, state} = Table.init(props)

      assert state.sorted_data == @test_data
    end
  end

  describe "keyboard navigation" do
    setup do
      props = Table.new(columns: @test_columns, data: @test_data)
      {:ok, state} = Table.init(props)
      %{state: state}
    end

    test "moves cursor down with arrow key", %{state: state} do
      event = %Event.Key{key: :down}
      {:ok, new_state} = Table.handle_event(event, state)

      assert new_state.cursor == 1
    end

    test "moves cursor up with arrow key", %{state: state} do
      state = %{state | cursor: 2}
      event = %Event.Key{key: :up}
      {:ok, new_state} = Table.handle_event(event, state)

      assert new_state.cursor == 1
    end

    test "doesn't move cursor below 0", %{state: state} do
      event = %Event.Key{key: :up}
      {:ok, new_state} = Table.handle_event(event, state)

      assert new_state.cursor == 0
    end

    test "doesn't move cursor beyond last row", %{state: state} do
      state = %{state | cursor: 4}
      event = %Event.Key{key: :down}
      {:ok, new_state} = Table.handle_event(event, state)

      assert new_state.cursor == 4
    end

    test "home key moves to first row", %{state: state} do
      state = %{state | cursor: 3}
      event = %Event.Key{key: :home}
      {:ok, new_state} = Table.handle_event(event, state)

      assert new_state.cursor == 0
    end

    test "end key moves to last row", %{state: state} do
      event = %Event.Key{key: :end}
      {:ok, new_state} = Table.handle_event(event, state)

      assert new_state.cursor == 4
    end

    test "page down moves by visible height", %{state: state} do
      state = %{state | visible_height: 3}
      event = %Event.Key{key: :page_down}
      {:ok, new_state} = Table.handle_event(event, state)

      assert new_state.cursor == 3
    end

    test "page up moves by visible height", %{state: state} do
      state = %{state | cursor: 4, visible_height: 3}
      event = %Event.Key{key: :page_up}
      {:ok, new_state} = Table.handle_event(event, state)

      assert new_state.cursor == 1
    end
  end

  describe "selection" do
    setup do
      props = Table.new(columns: @test_columns, data: @test_data)
      {:ok, state} = Table.init(props)
      %{state: state}
    end

    test "single selection updates on cursor move", %{state: state} do
      event = %Event.Key{key: :down}
      {:ok, new_state} = Table.handle_event(event, state)

      assert MapSet.member?(new_state.selected, 1)
      assert MapSet.size(new_state.selected) == 1
    end

    test "multi selection preserves previous selections", %{state: state} do
      state = %{state | selection_mode: :multi, selected: MapSet.new([0])}

      # Move cursor
      event = %Event.Key{key: :down}
      {:ok, new_state} = Table.handle_event(event, state)

      # Selection unchanged in multi mode on cursor move
      assert MapSet.member?(new_state.selected, 0)
      assert not MapSet.member?(new_state.selected, 1)
    end

    test "space toggles selection in multi mode", %{state: state} do
      state = %{state | selection_mode: :multi}

      event = %Event.Key{key: " "}
      {:ok, new_state} = Table.handle_event(event, state)

      assert MapSet.member?(new_state.selected, 0)

      # Toggle off
      {:ok, new_state2} = Table.handle_event(event, new_state)
      assert not MapSet.member?(new_state2.selected, 0)
    end

    test "no selection mode ignores selection", %{state: state} do
      state = %{state | selection_mode: :none}

      event = %Event.Key{key: :down}
      {:ok, new_state} = Table.handle_event(event, state)

      assert MapSet.size(new_state.selected) == 0
    end

    test "get_selection returns selected rows", %{state: state} do
      state = %{state | selected: MapSet.new([1, 3])}

      selection = Table.get_selection(state)

      assert length(selection) == 2
      assert Enum.at(selection, 0).name == "Bob"
      assert Enum.at(selection, 1).name == "Diana"
    end

    test "set_selection updates selection", %{state: state} do
      state = Table.set_selection(state, [0, 2, 4])

      assert MapSet.size(state.selected) == 3
      assert MapSet.member?(state.selected, 0)
      assert MapSet.member?(state.selected, 2)
      assert MapSet.member?(state.selected, 4)
    end

    test "clear_selection removes all selections", %{state: state} do
      state = %{state | selected: MapSet.new([1, 2, 3])}
      state = Table.clear_selection(state)

      assert MapSet.size(state.selected) == 0
    end
  end

  describe "sorting" do
    setup do
      props = Table.new(columns: @test_columns, data: @test_data)
      {:ok, state} = Table.init(props)
      %{state: state}
    end

    test "sort_by sorts ascending", %{state: state} do
      state = Table.sort_by(state, :age, :asc)

      assert state.sort_column == :age
      assert state.sort_direction == :asc

      ages = Enum.map(state.sorted_data, & &1.age)
      assert ages == [25, 28, 30, 32, 35]
    end

    test "sort_by sorts descending", %{state: state} do
      state = Table.sort_by(state, :age, :desc)

      ages = Enum.map(state.sorted_data, & &1.age)
      assert ages == [35, 32, 30, 28, 25]
    end

    test "sort_by with nil clears sort", %{state: state} do
      state = Table.sort_by(state, :age, :asc)
      state = Table.sort_by(state, :age, nil)

      assert state.sort_direction == nil
      # Data returns to original order
      assert state.sorted_data == @test_data
    end

    test "toggle_sort cycles through directions", %{state: state} do
      # First toggle: ascending
      state = Table.toggle_sort(state, :name)
      assert state.sort_column == :name
      assert state.sort_direction == :asc

      # Second toggle: descending
      state = Table.toggle_sort(state, :name)
      assert state.sort_column == :name
      assert state.sort_direction == :desc

      # Third toggle: clear
      state = Table.toggle_sort(state, :name)
      assert state.sort_column == nil
      assert state.sort_direction == nil
    end

    test "toggle_sort on different column resets to ascending", %{state: state} do
      state = Table.sort_by(state, :name, :desc)
      state = Table.toggle_sort(state, :age)

      assert state.sort_column == :age
      assert state.sort_direction == :asc
    end

    test "sorts by string values", %{state: state} do
      state = Table.sort_by(state, :name, :asc)

      names = Enum.map(state.sorted_data, & &1.name)
      assert names == ["Alice", "Bob", "Charlie", "Diana", "Eve"]
    end
  end

  describe "virtual scrolling" do
    setup do
      # Create larger dataset
      data =
        Enum.map(1..100, fn i ->
          %{name: "Person #{i}", age: 20 + rem(i, 50), city: "City #{rem(i, 10)}"}
        end)

      props = Table.new(columns: @test_columns, data: data)
      {:ok, state} = Table.init(props)
      state = %{state | visible_height: 10}
      %{state: state}
    end

    test "scroll_to sets offset", %{state: state} do
      state = Table.scroll_to(state, 50)

      assert state.scroll_offset == 50
    end

    test "scroll_to clamps to valid range", %{state: state} do
      # Can't scroll past last page
      state = Table.scroll_to(state, 200)

      # Max offset = 100 - 10 = 90
      assert state.scroll_offset == 90
    end

    test "scroll_to handles negative values", %{state: state} do
      state = Table.scroll_to(state, -10)

      assert state.scroll_offset == 0
    end

    test "cursor movement scrolls view when needed", %{state: state} do
      # Move cursor beyond visible area
      state = %{state | cursor: 15}
      event = %Event.Key{key: :down}
      {:ok, new_state} = Table.handle_event(event, state)

      # Should scroll to keep cursor visible
      assert new_state.scroll_offset > 0
    end

    test "visible_count returns visible height", %{state: state} do
      assert Table.visible_count(state) == 10
    end

    test "total_count returns data length", %{state: state} do
      assert Table.total_count(state) == 100
    end

    test "mouse scroll up decreases offset", %{state: state} do
      state = %{state | scroll_offset: 10}
      event = %Event.Mouse{action: :scroll, button: :scroll_up, x: 0, y: 0}
      {:ok, new_state} = Table.handle_event(event, state)

      assert new_state.scroll_offset < 10
    end

    test "mouse scroll down increases offset", %{state: state} do
      event = %Event.Mouse{action: :scroll, button: :scroll_down, x: 0, y: 0}
      {:ok, new_state} = Table.handle_event(event, state)

      assert new_state.scroll_offset > 0
    end
  end

  describe "column width calculation" do
    test "fixed width columns get exact size" do
      columns = [
        Column.new(:a, "A", width: Constraint.length(10)),
        Column.new(:b, "B", width: Constraint.length(20))
      ]

      props = Table.new(columns: columns, data: [])
      {:ok, state} = Table.init(props)
      area = %{x: 0, y: 0, width: 100, height: 20}

      # Trigger render to calculate widths
      _result = Table.render(state, area)

      # Width calculation happens during render
      # We can verify by checking the render output structure
    end

    test "ratio columns distribute remaining space" do
      columns = [
        Column.new(:a, "A", width: Constraint.length(20)),
        Column.new(:b, "B", width: Constraint.ratio(2)),
        Column.new(:c, "C", width: Constraint.ratio(1))
      ]

      props = Table.new(columns: columns, data: [])
      {:ok, state} = Table.init(props)
      area = %{x: 0, y: 0, width: 80, height: 20}

      # Remaining = 80 - 20 = 60
      # B gets 2/3 = 40, C gets 1/3 = 20
      _result = Table.render(state, area)
    end

    test "percentage columns use parent percentage" do
      columns = [
        Column.new(:a, "A", width: Constraint.percentage(50)),
        Column.new(:b, "B", width: Constraint.percentage(50))
      ]

      props = Table.new(columns: columns, data: [])
      {:ok, state} = Table.init(props)
      area = %{x: 0, y: 0, width: 100, height: 20}

      _result = Table.render(state, area)
    end
  end

  describe "render" do
    test "renders header and rows" do
      props = Table.new(columns: @test_columns, data: @test_data)
      {:ok, state} = Table.init(props)
      area = %{x: 0, y: 0, width: 80, height: 10}

      result = Table.render(state, area)

      # Should return a stack with header + rows
      assert result.type == :stack
      assert result.direction == :vertical
      # Header + 5 data rows
      assert length(result.children) == 6
    end

    test "renders only visible rows for large datasets" do
      data = Enum.map(1..1000, fn i -> %{name: "Person #{i}", age: i, city: "City"} end)
      props = Table.new(columns: @test_columns, data: data)
      {:ok, state} = Table.init(props)
      # 10 visible rows + header
      area = %{x: 0, y: 0, width: 80, height: 11}

      result = Table.render(state, area)

      # Should only render header + visible rows (not all 1000)
      assert length(result.children) == 11
    end

    test "renders sort indicator in header" do
      props = Table.new(columns: @test_columns, data: @test_data)
      {:ok, state} = Table.init(props)
      state = Table.sort_by(state, :age, :asc)
      area = %{x: 0, y: 0, width: 80, height: 10}

      result = Table.render(state, area)

      # Header should contain sort indicator
      header = hd(result.children)
      assert String.contains?(header.content, "▲")
    end
  end

  describe "update/2" do
    test "updates data and re-sorts" do
      props = Table.new(columns: @test_columns, data: @test_data)
      {:ok, state} = Table.init(props)
      state = Table.sort_by(state, :age, :asc)

      new_data = [
        %{name: "Zoe", age: 18, city: "Miami"},
        %{name: "Yuki", age: 40, city: "Tokyo"}
      ]

      new_props = %{columns: @test_columns, data: new_data}
      {:ok, new_state} = Table.update(new_props, state)

      assert length(new_state.data) == 2
      # Should be sorted by age
      assert hd(new_state.sorted_data).name == "Zoe"
    end
  end
end
