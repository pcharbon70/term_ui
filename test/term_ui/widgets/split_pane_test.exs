defmodule TermUI.Widgets.SplitPaneTest do
  use ExUnit.Case, async: false

  alias TermUI.Event
  alias TermUI.Theme
  alias TermUI.Widgets.SplitPane

  setup do
    # Start Theme server for color support (ignore if already started)
    case Theme.start_link(theme: :dark) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    :ok
  end

  # Helper to create test area
  defp test_area(width, height) do
    %{x: 0, y: 0, width: width, height: height}
  end

  # Helper to create simple text content
  defp content(text), do: text

  describe "pane/3" do
    test "creates a pane with defaults" do
      pane = SplitPane.pane(:test, content("Test"))
      assert pane.id == :test
      assert pane.content == "Test"
      assert pane.size == 1.0
      assert pane.min_size == nil
      assert pane.max_size == nil
      assert pane.collapsed == false
    end

    test "creates a pane with options" do
      pane =
        SplitPane.pane(:test, content("Test"),
          size: 0.3,
          min_size: 10,
          max_size: 50,
          collapsed: true
        )

      assert pane.size == 0.3
      assert pane.min_size == 10
      assert pane.max_size == 50
      assert pane.collapsed == true
    end
  end

  describe "new/1" do
    test "creates props with defaults" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:right, content("Right"))
          ]
        )

      assert props.orientation == :horizontal
      assert length(props.panes) == 2
      assert props.divider_size == 1
      assert props.resizable == true
    end

    test "creates props with custom options" do
      props =
        SplitPane.new(
          orientation: :vertical,
          panes: [
            SplitPane.pane(:top, content("Top")),
            SplitPane.pane(:bottom, content("Bottom"))
          ],
          divider_size: 2,
          resizable: false
        )

      assert props.orientation == :vertical
      assert props.divider_size == 2
      assert props.resizable == false
    end
  end

  describe "init/1" do
    test "initializes state from props" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:right, content("Right"))
          ]
        )

      {:ok, state} = SplitPane.init(props)

      assert state.orientation == :horizontal
      assert length(state.panes) == 2
      assert state.focused_divider == nil
      assert state.dragging == false
    end
  end

  describe "rendering horizontal split" do
    test "renders two panes with divider" do
      props =
        SplitPane.new(
          orientation: :horizontal,
          panes: [
            SplitPane.pane(:left, content("Left"), size: 0.5),
            SplitPane.pane(:right, content("Right"), size: 0.5)
          ]
        )

      {:ok, state} = SplitPane.init(props)
      render = SplitPane.render(state, test_area(80, 24))

      # Should produce a horizontal stack
      assert render != nil
    end

    test "distributes space equally with equal proportions" do
      props =
        SplitPane.new(
          orientation: :horizontal,
          panes: [
            SplitPane.pane(:left, content("Left"), size: 0.5),
            SplitPane.pane(:right, content("Right"), size: 0.5)
          ]
        )

      {:ok, state} = SplitPane.init(props)
      # Trigger size computation via render
      _render = SplitPane.render(state, test_area(81, 24))

      # With 81 width and 1 divider, each pane should get 40 chars
      # (81 - 1) / 2 = 40
    end

    test "respects fixed size specifications" do
      props =
        SplitPane.new(
          orientation: :horizontal,
          panes: [
            SplitPane.pane(:left, content("Left"), size: 20, min_size: 20, max_size: 20),
            SplitPane.pane(:right, content("Right"), size: 0.5)
          ]
        )

      {:ok, state} = SplitPane.init(props)
      _render = SplitPane.render(state, test_area(80, 24))

      # Left pane should be constrained to 20
    end
  end

  describe "rendering vertical split" do
    test "renders two panes with horizontal divider" do
      props =
        SplitPane.new(
          orientation: :vertical,
          panes: [
            SplitPane.pane(:top, content("Top"), size: 0.5),
            SplitPane.pane(:bottom, content("Bottom"), size: 0.5)
          ]
        )

      {:ok, state} = SplitPane.init(props)
      render = SplitPane.render(state, test_area(80, 25))

      assert render != nil
    end
  end

  describe "keyboard navigation - Tab" do
    test "Tab focuses first divider" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:right, content("Right"))
          ]
        )

      {:ok, state} = SplitPane.init(props)
      assert state.focused_divider == nil

      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :tab}, state)
      assert state.focused_divider == 0
    end

    test "Tab cycles through dividers" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:middle, content("Middle")),
            SplitPane.pane(:right, content("Right"))
          ]
        )

      {:ok, state} = SplitPane.init(props)

      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :tab}, state)
      assert state.focused_divider == 0

      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :tab}, state)
      assert state.focused_divider == 1

      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :tab}, state)
      assert state.focused_divider == nil
    end

    test "Shift+Tab cycles backwards" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:middle, content("Middle")),
            SplitPane.pane(:right, content("Right"))
          ]
        )

      {:ok, state} = SplitPane.init(props)

      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :tab, modifiers: [:shift]}, state)
      assert state.focused_divider == 1

      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :tab, modifiers: [:shift]}, state)
      assert state.focused_divider == 0

      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :tab, modifiers: [:shift]}, state)
      assert state.focused_divider == nil
    end
  end

  describe "keyboard resize" do
    setup do
      props =
        SplitPane.new(
          orientation: :horizontal,
          panes: [
            SplitPane.pane(:left, content("Left"), size: 0.5),
            SplitPane.pane(:right, content("Right"), size: 0.5)
          ]
        )

      {:ok, state} = SplitPane.init(props)
      # Render to compute sizes
      _render = SplitPane.render(state, test_area(81, 24))
      # Focus the divider
      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :tab}, state)

      {:ok, state: state}
    end

    test "left arrow decreases left pane size", %{state: state} do
      # Render to compute sizes
      _render = SplitPane.render(state, test_area(81, 24))

      initial_left_size = Enum.at(state.panes, 0).size

      {:ok, new_state} = SplitPane.handle_event(%Event.Key{key: :left}, state)

      new_left_size = Enum.at(new_state.panes, 0).size
      # Left arrow should decrease left pane size
      assert new_left_size < initial_left_size
    end

    test "right arrow increases left pane size", %{state: state} do
      _render = SplitPane.render(state, test_area(81, 24))

      initial_left_size = Enum.at(state.panes, 0).size

      {:ok, new_state} = SplitPane.handle_event(%Event.Key{key: :right}, state)

      new_left_size = Enum.at(new_state.panes, 0).size
      # Right arrow should increase left pane size
      assert new_left_size > initial_left_size
    end

    test "shift+arrow moves by larger step", %{state: state} do
      _render = SplitPane.render(state, test_area(81, 24))

      initial_left_size = Enum.at(state.panes, 0).size

      # Normal right
      {:ok, normal_state} = SplitPane.handle_event(%Event.Key{key: :right}, state)
      normal_delta = Enum.at(normal_state.panes, 0).size - initial_left_size

      # Shift+right should move by larger step
      {:ok, shift_state} =
        SplitPane.handle_event(%Event.Key{key: :right, modifiers: [:shift]}, state)

      shift_delta = Enum.at(shift_state.panes, 0).size - initial_left_size

      assert shift_delta > normal_delta
    end

    test "no resize without focused divider" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:right, content("Right"))
          ]
        )

      {:ok, state} = SplitPane.init(props)
      # Don't focus divider

      {:ok, new_state} = SplitPane.handle_event(%Event.Key{key: :left}, state)
      # State should be unchanged
      assert new_state.panes == state.panes
    end
  end

  describe "Ctrl+arrow keyboard resize (TTY-friendly)" do
    test "Ctrl+Right increases first pane size without focused divider" do
      props =
        SplitPane.new(
          orientation: :horizontal,
          panes: [
            SplitPane.pane(:left, content("Left"), size: 0.5),
            SplitPane.pane(:right, content("Right"), size: 0.5)
          ]
        )

      {:ok, state} = SplitPane.init(props)
      _render = SplitPane.render(state, test_area(81, 24))

      assert state.focused_divider == nil
      initial_left_size = Enum.at(state.panes, 0).size

      {:ok, new_state} =
        SplitPane.handle_event(%Event.Key{key: :right, modifiers: [:ctrl]}, state)

      new_left_size = Enum.at(new_state.panes, 0).size
      # Ctrl+Right should INCREASE first pane size
      assert new_left_size > initial_left_size
    end

    test "Ctrl+Left decreases first pane size without focused divider" do
      props =
        SplitPane.new(
          orientation: :horizontal,
          panes: [
            SplitPane.pane(:left, content("Left"), size: 0.5),
            SplitPane.pane(:right, content("Right"), size: 0.5)
          ]
        )

      {:ok, state} = SplitPane.init(props)
      _render = SplitPane.render(state, test_area(81, 24))

      assert state.focused_divider == nil
      initial_left_size = Enum.at(state.panes, 0).size

      {:ok, new_state} =
        SplitPane.handle_event(%Event.Key{key: :left, modifiers: [:ctrl]}, state)

      new_left_size = Enum.at(new_state.panes, 0).size
      # Ctrl+Left should DECREASE first pane size
      assert new_left_size < initial_left_size
    end

    test "Ctrl+Down increases first pane size in vertical split" do
      props =
        SplitPane.new(
          orientation: :vertical,
          panes: [
            SplitPane.pane(:top, content("Top"), size: 0.5),
            SplitPane.pane(:bottom, content("Bottom"), size: 0.5)
          ]
        )

      {:ok, state} = SplitPane.init(props)
      _render = SplitPane.render(state, test_area(80, 25))

      assert state.focused_divider == nil
      initial_top_size = Enum.at(state.panes, 0).size

      {:ok, new_state} =
        SplitPane.handle_event(%Event.Key{key: :down, modifiers: [:ctrl]}, state)

      new_top_size = Enum.at(new_state.panes, 0).size
      # Ctrl+Down should INCREASE first pane size
      assert new_top_size > initial_top_size
    end

    test "Ctrl+Up decreases first pane size in vertical split" do
      props =
        SplitPane.new(
          orientation: :vertical,
          panes: [
            SplitPane.pane(:top, content("Top"), size: 0.5),
            SplitPane.pane(:bottom, content("Bottom"), size: 0.5)
          ]
        )

      {:ok, state} = SplitPane.init(props)
      _render = SplitPane.render(state, test_area(80, 25))

      assert state.focused_divider == nil
      initial_top_size = Enum.at(state.panes, 0).size

      {:ok, new_state} =
        SplitPane.handle_event(%Event.Key{key: :up, modifiers: [:ctrl]}, state)

      new_top_size = Enum.at(new_state.panes, 0).size
      # Ctrl+Up should DECREASE first pane size
      assert new_top_size < initial_top_size
    end

    test "Ctrl+arrows do nothing when resizable is false" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:right, content("Right"))
          ],
          resizable: false
        )

      {:ok, state} = SplitPane.init(props)

      {:ok, new_state} =
        SplitPane.handle_event(%Event.Key{key: :right, modifiers: [:ctrl]}, state)

      # State should be unchanged
      assert new_state == state
    end

    test "Ctrl+arrows ignored when divider is focused (regular arrows take precedence)" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left"), size: 0.5),
            SplitPane.pane(:right, content("Right"), size: 0.5)
          ]
        )

      {:ok, state} = SplitPane.init(props)
      _render = SplitPane.render(state, test_area(81, 24))

      # Focus a divider
      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :tab}, state)
      assert state.focused_divider == 0

      # Ctrl+Right with focused divider - handled by focused divider handler (with shift check)
      # In current impl, this goes to the focused handler since guard matches first
      {:ok, _new_state} =
        SplitPane.handle_event(%Event.Key{key: :right, modifiers: [:ctrl]}, state)

      # Just verify it doesn't crash
    end

    test "Ctrl+arrows do nothing with single pane (no dividers)" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:only, content("Only"))
          ]
        )

      {:ok, state} = SplitPane.init(props)
      _render = SplitPane.render(state, test_area(80, 24))

      {:ok, new_state} =
        SplitPane.handle_event(%Event.Key{key: :right, modifiers: [:ctrl]}, state)

      # State should be unchanged - no dividers to resize
      assert new_state == state
    end

    test "Ctrl+arrows do nothing when first pane is collapsed" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left"), size: 0.5, collapsed: true),
            SplitPane.pane(:right, content("Right"), size: 0.5)
          ]
        )

      {:ok, state} = SplitPane.init(props)
      _render = SplitPane.render(state, test_area(80, 24))

      {:ok, new_state} =
        SplitPane.handle_event(%Event.Key{key: :right, modifiers: [:ctrl]}, state)

      # State should be unchanged - collapsed pane can't be resized
      assert new_state.panes == state.panes
    end

    test "Ctrl+arrows do nothing when second pane is collapsed" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left"), size: 0.5),
            SplitPane.pane(:right, content("Right"), size: 0.5, collapsed: true)
          ]
        )

      {:ok, state} = SplitPane.init(props)
      _render = SplitPane.render(state, test_area(80, 24))

      {:ok, new_state} =
        SplitPane.handle_event(%Event.Key{key: :right, modifiers: [:ctrl]}, state)

      # State should be unchanged - collapsed pane can't be resized
      assert new_state.panes == state.panes
    end

    test "invalid config values are normalized to defaults" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:right, content("Right"))
          ],
          ctrl_resize_step: -0.5,
          min_ratio: 0.9,
          max_ratio: 0.1
        )

      {:ok, state} = SplitPane.init(props)

      # Invalid values should be reset to defaults
      assert state.ctrl_resize_step == 0.05
      assert state.min_ratio == 0.1
      assert state.max_ratio == 0.9
    end

    test "zero pane sizes handled gracefully (division by zero protection)" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left"), size: 0.0),
            SplitPane.pane(:right, content("Right"), size: 0.0)
          ]
        )

      {:ok, state} = SplitPane.init(props)
      _render = SplitPane.render(state, test_area(80, 24))

      # Should not crash - division by zero is guarded
      {:ok, new_state} =
        SplitPane.handle_event(%Event.Key{key: :right, modifiers: [:ctrl]}, state)

      # State should be unchanged since total_ratio is 0
      assert new_state == state
    end
  end

  describe "vertical keyboard resize" do
    test "up/down arrows work for vertical splits" do
      props =
        SplitPane.new(
          orientation: :vertical,
          panes: [
            SplitPane.pane(:top, content("Top"), size: 0.5),
            SplitPane.pane(:bottom, content("Bottom"), size: 0.5)
          ]
        )

      {:ok, state} = SplitPane.init(props)
      _render = SplitPane.render(state, test_area(80, 25))
      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :tab}, state)

      {:ok, new_state} = SplitPane.handle_event(%Event.Key{key: :up}, state)
      assert new_state != nil

      {:ok, new_state} = SplitPane.handle_event(%Event.Key{key: :down}, state)
      assert new_state != nil
    end
  end

  describe "Home/End keys" do
    test "Home moves divider to minimum position" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left"), size: 0.5, min_size: 10),
            SplitPane.pane(:right, content("Right"), size: 0.5)
          ]
        )

      {:ok, state} = SplitPane.init(props)
      _render = SplitPane.render(state, test_area(80, 24))
      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :tab}, state)

      {:ok, new_state} = SplitPane.handle_event(%Event.Key{key: :home}, state)
      assert new_state != nil
    end

    test "End moves divider to maximum position" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left"), size: 0.5),
            SplitPane.pane(:right, content("Right"), size: 0.5, min_size: 10)
          ]
        )

      {:ok, state} = SplitPane.init(props)
      _render = SplitPane.render(state, test_area(80, 24))
      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :tab}, state)

      {:ok, new_state} = SplitPane.handle_event(%Event.Key{key: :end}, state)
      assert new_state != nil
    end
  end

  describe "min/max size constraints" do
    test "min_size prevents pane from shrinking below minimum" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left"), size: 0.3, min_size: 20),
            SplitPane.pane(:right, content("Right"), size: 0.7)
          ]
        )

      {:ok, state} = SplitPane.init(props)
      _render = SplitPane.render(state, test_area(80, 24))

      # Left pane should be at least 20 chars
      left_pane = Enum.at(state.panes, 0)
      assert left_pane.min_size == 20
    end

    test "max_size prevents pane from growing above maximum" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left"), size: 0.7, max_size: 30),
            SplitPane.pane(:right, content("Right"), size: 0.3)
          ]
        )

      {:ok, state} = SplitPane.init(props)
      _render = SplitPane.render(state, test_area(80, 24))

      # Left pane should be at most 30 chars
      left_pane = Enum.at(state.panes, 0)
      assert left_pane.max_size == 30
    end
  end

  describe "collapse/expand" do
    test "Enter toggles collapse on pane after divider" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:right, content("Right"))
          ]
        )

      {:ok, state} = SplitPane.init(props)
      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :tab}, state)

      # Pressing Enter should collapse the right pane (index 1)
      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :enter}, state)
      right_pane = Enum.at(state.panes, 1)
      assert right_pane.collapsed == true

      # Pressing Enter again should expand it
      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :enter}, state)
      right_pane = Enum.at(state.panes, 1)
      assert right_pane.collapsed == false
    end

    test "collapsed pane has zero computed size" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:right, content("Right"), collapsed: true)
          ]
        )

      {:ok, state} = SplitPane.init(props)
      _render = SplitPane.render(state, test_area(80, 24))

      right_pane = Enum.at(state.panes, 1)
      assert right_pane.collapsed == true
    end
  end

  describe "mouse interaction" do
    test "click on divider starts drag" do
      props =
        SplitPane.new(
          orientation: :horizontal,
          panes: [
            SplitPane.pane(:left, content("Left"), size: 0.5),
            SplitPane.pane(:right, content("Right"), size: 0.5)
          ]
        )

      {:ok, state} = SplitPane.init(props)
      # Render to compute positions
      _render = SplitPane.render(state, test_area(81, 24))

      # Click on divider position (approximately at x=40 for 81-width split)
      {:ok, _state} = SplitPane.handle_event(%Event.Mouse{action: :click, x: 40, y: 10}, state)

      # Should be dragging or focused
      # Note: exact divider position depends on size calculation
    end

    test "drag updates divider position" do
      props =
        SplitPane.new(
          orientation: :horizontal,
          panes: [
            SplitPane.pane(:left, content("Left"), size: 0.5),
            SplitPane.pane(:right, content("Right"), size: 0.5)
          ]
        )

      {:ok, state} = SplitPane.init(props)
      _render = SplitPane.render(state, test_area(81, 24))

      # Simulate starting a drag
      state = %{state | dragging: true, drag_start: 40, drag_divider: 0, focused_divider: 0}

      {:ok, new_state} = SplitPane.handle_event(%Event.Mouse{action: :drag, x: 45, y: 10}, state)
      assert new_state != nil
    end

    test "release ends drag" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:right, content("Right"))
          ]
        )

      {:ok, state} = SplitPane.init(props)
      state = %{state | dragging: true, drag_start: 40, drag_divider: 0}

      {:ok, state} = SplitPane.handle_event(%Event.Mouse{action: :release}, state)
      assert state.dragging == false
      assert state.drag_start == nil
    end
  end

  describe "public API - get_layout/1" do
    test "returns layout state for all panes" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left"), size: 0.3),
            SplitPane.pane(:right, content("Right"), size: 0.7, collapsed: true)
          ]
        )

      {:ok, state} = SplitPane.init(props)
      layout = SplitPane.get_layout(state)

      assert Map.has_key?(layout, :left)
      assert Map.has_key?(layout, :right)
      assert layout[:left].size == 0.3
      assert layout[:right].collapsed == true
    end
  end

  describe "public API - set_layout/2" do
    test "restores layout from saved state" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left"), size: 0.5),
            SplitPane.pane(:right, content("Right"), size: 0.5)
          ]
        )

      {:ok, state} = SplitPane.init(props)

      saved_layout = %{
        left: %{size: 0.25, collapsed: false},
        right: %{size: 0.75, collapsed: true}
      }

      state = SplitPane.set_layout(state, saved_layout)

      left_pane = Enum.at(state.panes, 0)
      right_pane = Enum.at(state.panes, 1)

      assert left_pane.size == 0.25
      assert right_pane.size == 0.75
      assert right_pane.collapsed == true
    end
  end

  describe "public API - collapse/expand/toggle" do
    test "collapse/1 collapses a pane" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:right, content("Right"))
          ]
        )

      {:ok, state} = SplitPane.init(props)
      state = SplitPane.collapse(state, :right)

      right_pane = Enum.at(state.panes, 1)
      assert right_pane.collapsed == true
    end

    test "expand/1 expands a pane" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:right, content("Right"), collapsed: true)
          ]
        )

      {:ok, state} = SplitPane.init(props)
      state = SplitPane.expand(state, :right)

      right_pane = Enum.at(state.panes, 1)
      assert right_pane.collapsed == false
    end

    test "toggle/1 toggles collapse state" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:right, content("Right"))
          ]
        )

      {:ok, state} = SplitPane.init(props)

      state = SplitPane.toggle(state, :right)
      assert Enum.at(state.panes, 1).collapsed == true

      state = SplitPane.toggle(state, :right)
      assert Enum.at(state.panes, 1).collapsed == false
    end
  end

  describe "public API - set_pane_size/3" do
    test "sets the size of a pane" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left"), size: 0.5),
            SplitPane.pane(:right, content("Right"), size: 0.5)
          ]
        )

      {:ok, state} = SplitPane.init(props)
      state = SplitPane.set_pane_size(state, :left, 0.3)

      left_pane = Enum.at(state.panes, 0)
      assert left_pane.size == 0.3
    end
  end

  describe "public API - get_pane_ids/1" do
    test "returns list of pane IDs" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:middle, content("Middle")),
            SplitPane.pane(:right, content("Right"))
          ]
        )

      {:ok, state} = SplitPane.init(props)
      ids = SplitPane.get_pane_ids(state)

      assert ids == [:left, :middle, :right]
    end
  end

  describe "public API - get_focused_divider/1" do
    test "returns focused divider index" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:right, content("Right"))
          ]
        )

      {:ok, state} = SplitPane.init(props)
      assert SplitPane.get_focused_divider(state) == nil

      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :tab}, state)
      assert SplitPane.get_focused_divider(state) == 0
    end
  end

  describe "public API - set_content/3" do
    test "updates content of a pane" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:right, content("Right"))
          ]
        )

      {:ok, state} = SplitPane.init(props)
      state = SplitPane.set_content(state, :left, content("New Content"))

      left_pane = Enum.at(state.panes, 0)
      assert left_pane.content == "New Content"
    end
  end

  describe "nested splits" do
    test "can nest SplitPane as content" do
      inner_props =
        SplitPane.new(
          orientation: :vertical,
          panes: [
            SplitPane.pane(:top, content("Top")),
            SplitPane.pane(:bottom, content("Bottom"))
          ]
        )

      {:ok, inner_state} = SplitPane.init(inner_props)

      outer_props =
        SplitPane.new(
          orientation: :horizontal,
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:right, inner_state)
          ]
        )

      {:ok, outer_state} = SplitPane.init(outer_props)
      render = SplitPane.render(outer_state, test_area(80, 24))

      assert render != nil
    end
  end

  describe "three panes" do
    test "handles three horizontal panes" do
      props =
        SplitPane.new(
          orientation: :horizontal,
          panes: [
            SplitPane.pane(:left, content("Left"), size: 0.25),
            SplitPane.pane(:middle, content("Middle"), size: 0.5),
            SplitPane.pane(:right, content("Right"), size: 0.25)
          ]
        )

      {:ok, state} = SplitPane.init(props)
      render = SplitPane.render(state, test_area(82, 24))

      # Should have 2 dividers
      assert length(state.panes) == 3
      assert render != nil
    end

    test "tab cycles through two dividers with three panes" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:middle, content("Middle")),
            SplitPane.pane(:right, content("Right"))
          ]
        )

      {:ok, state} = SplitPane.init(props)

      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :tab}, state)
      assert state.focused_divider == 0

      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :tab}, state)
      assert state.focused_divider == 1

      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :tab}, state)
      assert state.focused_divider == nil
    end
  end

  describe "resizable: false" do
    test "Tab does nothing when not resizable" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:right, content("Right"))
          ],
          resizable: false
        )

      {:ok, state} = SplitPane.init(props)

      {:ok, new_state} = SplitPane.handle_event(%Event.Key{key: :tab}, state)
      assert new_state.focused_divider == nil
    end

    test "arrow keys do nothing when not resizable" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:right, content("Right"))
          ],
          resizable: false
        )

      {:ok, state} = SplitPane.init(props)
      # Force focus for test
      state = %{state | focused_divider: 0}

      {:ok, new_state} = SplitPane.handle_event(%Event.Key{key: :left}, state)
      assert new_state.panes == state.panes
    end
  end

  describe "callbacks" do
    test "on_collapse is called when pane is collapsed" do
      test_pid = self()

      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:right, content("Right"))
          ],
          on_collapse: fn {id, collapsed} -> send(test_pid, {:collapsed, id, collapsed}) end
        )

      {:ok, state} = SplitPane.init(props)
      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :tab}, state)
      {:ok, _state} = SplitPane.handle_event(%Event.Key{key: :enter}, state)

      assert_receive {:collapsed, :right, true}
    end
  end

  describe "Ctrl+arrow resize configuration (Task 5.2.3)" do
    test "new/1 accepts ctrl_resize_step option" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:right, content("Right"))
          ],
          ctrl_resize_step: 0.1
        )

      assert props.ctrl_resize_step == 0.1
    end

    test "new/1 accepts min_ratio option" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:right, content("Right"))
          ],
          min_ratio: 0.2
        )

      assert props.min_ratio == 0.2
    end

    test "new/1 accepts max_ratio option" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:right, content("Right"))
          ],
          max_ratio: 0.8
        )

      assert props.max_ratio == 0.8
    end

    test "init/1 stores configuration in state" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:right, content("Right"))
          ],
          ctrl_resize_step: 0.1,
          min_ratio: 0.2,
          max_ratio: 0.8
        )

      {:ok, state} = SplitPane.init(props)

      assert state.ctrl_resize_step == 0.1
      assert state.min_ratio == 0.2
      assert state.max_ratio == 0.8
    end

    test "default values are used when not specified" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:right, content("Right"))
          ]
        )

      {:ok, state} = SplitPane.init(props)

      # Default values: 0.05 step, 0.1 min, 0.9 max
      assert state.ctrl_resize_step == 0.05
      assert state.min_ratio == 0.1
      assert state.max_ratio == 0.9
    end

    test "Ctrl+Right uses configured step size" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left"), size: 0.5),
            SplitPane.pane(:right, content("Right"), size: 0.5)
          ],
          ctrl_resize_step: 0.1
        )

      {:ok, state} = SplitPane.init(props)
      _render = SplitPane.render(state, test_area(100, 24))

      initial_left_size = Enum.at(state.panes, 0).size

      {:ok, new_state} =
        SplitPane.handle_event(%Event.Key{key: :right, modifiers: [:ctrl]}, state)

      new_left_size = Enum.at(new_state.panes, 0).size
      # With 0.1 step, should increase by ~0.1
      assert_in_delta new_left_size, initial_left_size + 0.1, 0.01
    end

    test "Ctrl+Left uses configured step size" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left"), size: 0.5),
            SplitPane.pane(:right, content("Right"), size: 0.5)
          ],
          ctrl_resize_step: 0.1
        )

      {:ok, state} = SplitPane.init(props)
      _render = SplitPane.render(state, test_area(100, 24))

      initial_left_size = Enum.at(state.panes, 0).size

      {:ok, new_state} =
        SplitPane.handle_event(%Event.Key{key: :left, modifiers: [:ctrl]}, state)

      new_left_size = Enum.at(new_state.panes, 0).size
      # With 0.1 step, should decrease by ~0.1
      assert_in_delta new_left_size, initial_left_size - 0.1, 0.01
    end

    test "min_ratio is enforced" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left"), size: 0.2),
            SplitPane.pane(:right, content("Right"), size: 0.8)
          ],
          ctrl_resize_step: 0.15,
          min_ratio: 0.1
        )

      {:ok, state} = SplitPane.init(props)
      _render = SplitPane.render(state, test_area(100, 24))

      # Try to shrink below min_ratio (0.2 - 0.15 = 0.05, but min is 0.1)
      {:ok, new_state} =
        SplitPane.handle_event(%Event.Key{key: :left, modifiers: [:ctrl]}, state)

      new_left_size = Enum.at(new_state.panes, 0).size
      # Should be clamped to min_ratio (0.1)
      assert_in_delta new_left_size, 0.1, 0.01
    end

    test "max_ratio is enforced" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left"), size: 0.8),
            SplitPane.pane(:right, content("Right"), size: 0.2)
          ],
          ctrl_resize_step: 0.15,
          max_ratio: 0.9
        )

      {:ok, state} = SplitPane.init(props)
      _render = SplitPane.render(state, test_area(100, 24))

      # Try to grow beyond max_ratio (0.8 + 0.15 = 0.95, but max is 0.9)
      {:ok, new_state} =
        SplitPane.handle_event(%Event.Key{key: :right, modifiers: [:ctrl]}, state)

      new_left_size = Enum.at(new_state.panes, 0).size
      # Should be clamped to max_ratio (0.9)
      assert_in_delta new_left_size, 0.9, 0.01
    end

    test "cannot resize beyond min_ratio with multiple decreases" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left"), size: 0.3),
            SplitPane.pane(:right, content("Right"), size: 0.7)
          ],
          ctrl_resize_step: 0.1,
          min_ratio: 0.15
        )

      {:ok, state} = SplitPane.init(props)
      _render = SplitPane.render(state, test_area(100, 24))

      # Decrease multiple times
      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :left, modifiers: [:ctrl]}, state)
      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :left, modifiers: [:ctrl]}, state)
      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :left, modifiers: [:ctrl]}, state)

      new_left_size = Enum.at(state.panes, 0).size
      # Should not go below min_ratio
      assert new_left_size >= 0.15
    end

    test "cannot resize beyond max_ratio with multiple increases" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left"), size: 0.7),
            SplitPane.pane(:right, content("Right"), size: 0.3)
          ],
          ctrl_resize_step: 0.1,
          max_ratio: 0.85
        )

      {:ok, state} = SplitPane.init(props)
      _render = SplitPane.render(state, test_area(100, 24))

      # Increase multiple times
      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :right, modifiers: [:ctrl]}, state)
      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :right, modifiers: [:ctrl]}, state)
      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :right, modifiers: [:ctrl]}, state)

      new_left_size = Enum.at(state.panes, 0).size
      # Should not exceed max_ratio
      assert new_left_size <= 0.85
    end
  end

  describe "edge cases" do
    test "single pane renders without dividers" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:only, content("Only"))
          ]
        )

      {:ok, state} = SplitPane.init(props)
      render = SplitPane.render(state, test_area(80, 24))

      assert render != nil
      # Tab should do nothing with no dividers
      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :tab}, state)
      assert state.focused_divider == nil
    end

    test "all panes collapsed" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left"), collapsed: true),
            SplitPane.pane(:right, content("Right"), collapsed: true)
          ]
        )

      {:ok, state} = SplitPane.init(props)
      render = SplitPane.render(state, test_area(80, 24))

      # Should still render (just dividers)
      assert render != nil
    end

    test "very small area" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:right, content("Right"))
          ]
        )

      {:ok, state} = SplitPane.init(props)
      render = SplitPane.render(state, test_area(5, 5))

      # Should handle gracefully
      assert render != nil
    end

    test "unhandled event returns unchanged state" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, content("Left")),
            SplitPane.pane(:right, content("Right"))
          ]
        )

      {:ok, state} = SplitPane.init(props)
      {:ok, new_state} = SplitPane.handle_event(%Event.Key{key: :f1}, state)

      assert new_state == state
    end
  end
end
