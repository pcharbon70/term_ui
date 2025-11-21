defmodule TermUI.Widget.ProgressTest do
  use ExUnit.Case, async: true

  alias TermUI.Widget.Progress
  alias TermUI.Component.RenderNode

  @area %{x: 0, y: 0, width: 20, height: 1}

  describe "init/1" do
    test "initializes with default values" do
      {:ok, state} = Progress.init(%{})

      assert state.value == 0.0
      assert state.mode == :bar
      assert state.spinner_frame == 0
    end

    test "initializes with provided value" do
      {:ok, state} = Progress.init(%{value: 0.5})
      assert state.value == 0.5
    end

    test "initializes with spinner mode" do
      {:ok, state} = Progress.init(%{mode: :spinner})
      assert state.mode == :spinner
    end

    test "stores props in state" do
      props = %{value: 0.75, mode: :bar}
      {:ok, state} = Progress.init(props)
      assert state.props == props
    end
  end

  describe "handle_event/2" do
    test "set_value event updates value" do
      {:ok, state} = Progress.init(%{})
      {:ok, new_state} = Progress.handle_event({:set_value, 0.75}, state)
      assert new_state.value == 0.75
    end

    test "set_value clamps to 0-1 range" do
      {:ok, state} = Progress.init(%{})

      {:ok, high_state} = Progress.handle_event({:set_value, 2.0}, state)
      assert high_state.value == 1.0

      {:ok, low_state} = Progress.handle_event({:set_value, -0.5}, state)
      assert low_state.value == 0.0
    end

    test "tick event advances spinner frame" do
      {:ok, state} = Progress.init(%{mode: :spinner})
      assert state.spinner_frame == 0

      {:ok, state1} = Progress.handle_event(:tick, state)
      assert state1.spinner_frame == 1

      {:ok, state2} = Progress.handle_event(:tick, state1)
      assert state2.spinner_frame == 2
    end

    test "tick wraps around spinner frames" do
      {:ok, state} = Progress.init(%{mode: :spinner})
      # Advance 10 times (number of spinner frames)
      final_state = Enum.reduce(1..10, state, fn _, s ->
        {:ok, new_s} = Progress.handle_event(:tick, s)
        new_s
      end)
      assert final_state.spinner_frame == 0
    end

    test "ignores unknown events" do
      {:ok, state} = Progress.init(%{})
      {:ok, new_state} = Progress.handle_event(:unknown, state)
      assert new_state == state
    end
  end

  describe "render/2 bar mode" do
    test "renders empty bar at 0%" do
      props = %{value: 0.0}
      {:ok, state} = Progress.init(props)
      result = Progress.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      assert length(cells) == 20

      # All should be empty char
      chars = Enum.map(cells, fn %{cell: cell} -> cell.char end)
      assert Enum.all?(chars, fn c -> c == "░" end)
    end

    test "renders full bar at 100%" do
      props = %{value: 1.0}
      {:ok, state} = Progress.init(props)
      result = Progress.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      chars = Enum.map(cells, fn %{cell: cell} -> cell.char end)
      assert Enum.all?(chars, fn c -> c == "█" end)
    end

    test "renders partial bar at 50%" do
      props = %{value: 0.5}
      {:ok, state} = Progress.init(props)
      result = Progress.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      chars = Enum.map(cells, fn %{cell: cell} -> cell.char end)

      filled = Enum.count(chars, fn c -> c == "█" end)
      empty = Enum.count(chars, fn c -> c == "░" end)

      assert filled == 10
      assert empty == 10
    end

    test "renders percentage when enabled" do
      props = %{value: 0.5, show_percentage: true}
      {:ok, state} = Progress.init(props)
      result = Progress.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      text = Enum.map(cells, fn %{cell: cell} -> cell.char end) |> Enum.join()
      assert String.contains?(text, "50%")
    end

    test "uses custom filled char" do
      props = %{value: 1.0, filled_char: "="}
      {:ok, state} = Progress.init(props)
      result = Progress.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      chars = Enum.map(cells, fn %{cell: cell} -> cell.char end)
      assert Enum.all?(chars, fn c -> c == "=" end)
    end

    test "uses custom empty char" do
      props = %{value: 0.0, empty_char: "-"}
      {:ok, state} = Progress.init(props)
      result = Progress.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      chars = Enum.map(cells, fn %{cell: cell} -> cell.char end)
      assert Enum.all?(chars, fn c -> c == "-" end)
    end

    test "applies style to cells" do
      props = %{value: 0.5, style: %{fg: :green}}
      {:ok, state} = Progress.init(props)
      result = Progress.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      first_cell = hd(cells)
      assert first_cell.cell.fg == :green
    end
  end

  describe "render/2 spinner mode" do
    test "renders spinner frame" do
      props = %{mode: :spinner}
      {:ok, state} = Progress.init(props)
      result = Progress.render(state, @area)

      assert %RenderNode{type: :cells, cells: cells} = result
      assert length(cells) == 1

      first_cell = hd(cells)
      assert first_cell.x == 0
      assert first_cell.y == 0
      # First spinner frame
      assert first_cell.cell.char == "⠋"
    end

    test "renders different spinner frames after tick" do
      props = %{mode: :spinner}
      {:ok, state} = Progress.init(props)
      {:ok, state1} = Progress.handle_event(:tick, state)

      result = Progress.render(state1, @area)
      assert %RenderNode{type: :cells, cells: cells} = result
      first_cell = hd(cells)
      # Second spinner frame
      assert first_cell.cell.char == "⠙"
    end

    test "returns empty cells for zero width" do
      props = %{mode: :spinner}
      {:ok, state} = Progress.init(props)
      area = %{x: 0, y: 0, width: 0, height: 1}
      result = Progress.render(state, area)

      assert %RenderNode{type: :cells, cells: []} = result
    end
  end
end
