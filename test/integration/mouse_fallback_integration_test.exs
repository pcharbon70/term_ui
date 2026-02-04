defmodule TermUI.Integration.MouseFallbackIntegrationTest do
  @moduledoc """
  Integration tests for mouse fallback features.

  These tests verify that keyboard alternatives for mouse-dependent features
  work correctly, ensuring widgets remain fully functional in TTY mode where
  mouse interaction may not be available.

  ## Test Coverage

  - SplitPane: Ctrl+arrow keyboard resize
  - ContextMenu.Inline: Number key selection

  ## Key Insight

  Scrollbar keyboard alternatives (5.7.3.3) are already covered by the
  keyboard navigation tests since scrolling uses arrow keys which trigger
  the same navigation behavior.
  """

  use TermUI.TestCase, async: false

  alias TermUI.Event
  alias TermUI.Theme
  alias TermUI.Widgets.SplitPane
  alias TermUI.Widgets.ContextMenu
  alias TermUI.Widgets.ContextMenu.Inline

  # ============================================================================
  # Setup
  # ============================================================================

  setup do
    # Start Theme server for color support (ignore if already started)
    case Theme.start_link(theme: :dark) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    :ok
  end

  # Helper to create a test area for rendering
  defp test_area(width \\ 100, height \\ 50) do
    %{x: 0, y: 0, width: width, height: height}
  end

  # ============================================================================
  # SplitPane Keyboard Resize Tests
  # ============================================================================

  describe "SplitPane Ctrl+arrow keyboard resize - horizontal split" do
    setup do
      props =
        SplitPane.new(
          orientation: :horizontal,
          panes: [
            SplitPane.pane(:left, "Left Content", size: 0.5),
            SplitPane.pane(:right, "Right Content", size: 0.5)
          ],
          ctrl_resize_step: 0.1,
          min_ratio: 0.1,
          max_ratio: 0.9
        )

      {:ok, state} = SplitPane.init(props)
      # Render once to set total_size and computed sizes
      _render = SplitPane.render(state, test_area())
      %{state: state}
    end

    test "Ctrl+Right increases left pane ratio", %{state: state} do
      # Get initial left pane size
      initial_left_size = Enum.at(state.panes, 0).size

      # Send Ctrl+Right event
      {:ok, new_state} =
        SplitPane.handle_event(%Event.Key{key: :right, modifiers: [:ctrl]}, state)

      # Left pane should be larger
      new_left_size = Enum.at(new_state.panes, 0).size
      assert new_left_size > initial_left_size
      assert_in_delta new_left_size, initial_left_size + 0.1, 0.01
    end

    test "Ctrl+Left decreases left pane ratio", %{state: state} do
      # Get initial left pane size
      initial_left_size = Enum.at(state.panes, 0).size

      # Send Ctrl+Left event
      {:ok, new_state} =
        SplitPane.handle_event(%Event.Key{key: :left, modifiers: [:ctrl]}, state)

      # Left pane should be smaller
      new_left_size = Enum.at(new_state.panes, 0).size
      assert new_left_size < initial_left_size
      assert_in_delta new_left_size, initial_left_size - 0.1, 0.01
    end

    test "multiple Ctrl+Right increases accumulate", %{state: state} do
      initial_left_size = Enum.at(state.panes, 0).size

      # Apply multiple increases
      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :right, modifiers: [:ctrl]}, state)
      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :right, modifiers: [:ctrl]}, state)
      {:ok, state} = SplitPane.handle_event(%Event.Key{key: :right, modifiers: [:ctrl]}, state)

      new_left_size = Enum.at(state.panes, 0).size
      assert_in_delta new_left_size, initial_left_size + 0.3, 0.01
    end

    test "ratio is clamped to max_ratio", %{state: state} do
      # Increase many times to hit max
      state =
        Enum.reduce(1..20, state, fn _, s ->
          {:ok, new_s} = SplitPane.handle_event(%Event.Key{key: :right, modifiers: [:ctrl]}, s)
          new_s
        end)

      left_size = Enum.at(state.panes, 0).size
      # Should be clamped to max_ratio (0.9)
      assert left_size <= 0.9
    end

    test "ratio is clamped to min_ratio", %{state: state} do
      # Decrease many times to hit min
      state =
        Enum.reduce(1..20, state, fn _, s ->
          {:ok, new_s} = SplitPane.handle_event(%Event.Key{key: :left, modifiers: [:ctrl]}, s)
          new_s
        end)

      left_size = Enum.at(state.panes, 0).size
      # Should be clamped to min_ratio (0.1)
      assert left_size >= 0.1
    end

    test "arrow keys without Ctrl modifier do not resize when no divider focused", %{state: state} do
      initial_left_size = Enum.at(state.panes, 0).size

      # Arrow without Ctrl should not change size
      {:ok, new_state} = SplitPane.handle_event(%Event.Key{key: :right, modifiers: []}, state)

      new_left_size = Enum.at(new_state.panes, 0).size
      assert new_left_size == initial_left_size
    end
  end

  describe "SplitPane Ctrl+arrow keyboard resize - vertical split" do
    setup do
      props =
        SplitPane.new(
          orientation: :vertical,
          panes: [
            SplitPane.pane(:top, "Top Content", size: 0.5),
            SplitPane.pane(:bottom, "Bottom Content", size: 0.5)
          ],
          ctrl_resize_step: 0.1,
          min_ratio: 0.1,
          max_ratio: 0.9
        )

      {:ok, state} = SplitPane.init(props)
      _render = SplitPane.render(state, test_area())
      %{state: state}
    end

    test "Ctrl+Down increases top pane ratio", %{state: state} do
      initial_top_size = Enum.at(state.panes, 0).size

      {:ok, new_state} =
        SplitPane.handle_event(%Event.Key{key: :down, modifiers: [:ctrl]}, state)

      new_top_size = Enum.at(new_state.panes, 0).size
      assert new_top_size > initial_top_size
      assert_in_delta new_top_size, initial_top_size + 0.1, 0.01
    end

    test "Ctrl+Up decreases top pane ratio", %{state: state} do
      initial_top_size = Enum.at(state.panes, 0).size

      {:ok, new_state} =
        SplitPane.handle_event(%Event.Key{key: :up, modifiers: [:ctrl]}, state)

      new_top_size = Enum.at(new_state.panes, 0).size
      assert new_top_size < initial_top_size
      assert_in_delta new_top_size, initial_top_size - 0.1, 0.01
    end
  end

  describe "SplitPane keyboard resize configuration" do
    test "ctrl_resize_step is configurable" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, "Left", size: 0.5),
            SplitPane.pane(:right, "Right", size: 0.5)
          ],
          ctrl_resize_step: 0.05
        )

      {:ok, state} = SplitPane.init(props)
      initial_size = Enum.at(state.panes, 0).size

      {:ok, new_state} =
        SplitPane.handle_event(%Event.Key{key: :right, modifiers: [:ctrl]}, state)

      new_size = Enum.at(new_state.panes, 0).size
      assert_in_delta new_size, initial_size + 0.05, 0.01
    end

    test "min_ratio and max_ratio are configurable" do
      props =
        SplitPane.new(
          panes: [
            SplitPane.pane(:left, "Left", size: 0.5),
            SplitPane.pane(:right, "Right", size: 0.5)
          ],
          ctrl_resize_step: 0.2,
          min_ratio: 0.2,
          max_ratio: 0.8
        )

      {:ok, state} = SplitPane.init(props)

      # Try to go below min
      state =
        Enum.reduce(1..10, state, fn _, s ->
          {:ok, new_s} = SplitPane.handle_event(%Event.Key{key: :left, modifiers: [:ctrl]}, s)
          new_s
        end)

      assert Enum.at(state.panes, 0).size >= 0.2

      # Reset and try to go above max
      {:ok, state} = SplitPane.init(props)

      state =
        Enum.reduce(1..10, state, fn _, s ->
          {:ok, new_s} = SplitPane.handle_event(%Event.Key{key: :right, modifiers: [:ctrl]}, s)
          new_s
        end)

      assert Enum.at(state.panes, 0).size <= 0.8
    end
  end

  # ============================================================================
  # ContextMenu.Inline Number Selection Tests
  # ============================================================================

  describe "ContextMenu.Inline number selection" do
    setup do
      test_pid = self()

      props =
        Inline.new(
          items: [
            ContextMenu.action(:copy, "Copy"),
            ContextMenu.action(:paste, "Paste"),
            ContextMenu.action(:delete, "Delete"),
            ContextMenu.action(:rename, "Rename"),
            ContextMenu.action(:move, "Move")
          ],
          on_select: fn id -> send(test_pid, {:selected, id}) end,
          on_close: fn -> send(test_pid, :closed) end
        )

      {:ok, state} = Inline.init(props)
      %{state: state}
    end

    test "pressing 1 selects first item", %{state: state} do
      {:ok, _new_state} = Inline.handle_event(%Event.Key{key: "1"}, state)

      assert_receive {:selected, :copy}
    end

    test "pressing 2 selects second item", %{state: state} do
      {:ok, _new_state} = Inline.handle_event(%Event.Key{key: "2"}, state)

      assert_receive {:selected, :paste}
    end

    test "pressing 3 selects third item", %{state: state} do
      {:ok, _new_state} = Inline.handle_event(%Event.Key{key: "3"}, state)

      assert_receive {:selected, :delete}
    end

    test "pressing 5 selects fifth item", %{state: state} do
      {:ok, _new_state} = Inline.handle_event(%Event.Key{key: "5"}, state)

      assert_receive {:selected, :move}
    end

    test "menu closes after number selection", %{state: state} do
      {:ok, new_state} = Inline.handle_event(%Event.Key{key: "1"}, state)

      refute Inline.visible?(new_state)
    end

    test "pressing number beyond item count does nothing", %{state: state} do
      # We have 5 items, pressing 9 should do nothing
      {:ok, new_state} = Inline.handle_event(%Event.Key{key: "9"}, state)

      # Should not receive selection message
      refute_receive {:selected, _}
      # Menu should still be visible
      assert Inline.visible?(new_state)
    end
  end

  describe "ContextMenu.Inline number selection with disabled items" do
    setup do
      test_pid = self()

      props =
        Inline.new(
          items: [
            ContextMenu.action(:copy, "Copy"),
            ContextMenu.action(:paste, "Paste", disabled: true),
            ContextMenu.action(:delete, "Delete")
          ],
          on_select: fn id -> send(test_pid, {:selected, id}) end
        )

      {:ok, state} = Inline.init(props)
      %{state: state}
    end

    test "disabled items are not numbered", %{state: state} do
      # Number map should skip disabled item
      # 1 -> :copy, 2 -> :delete (paste is skipped)
      assert state.number_map == %{1 => :copy, 2 => :delete}
    end

    test "pressing 2 selects delete (not disabled paste)", %{state: state} do
      {:ok, _new_state} = Inline.handle_event(%Event.Key{key: "2"}, state)

      assert_receive {:selected, :delete}
      refute_receive {:selected, :paste}
    end
  end

  describe "ContextMenu.Inline number selection with separators" do
    setup do
      test_pid = self()

      props =
        Inline.new(
          items: [
            ContextMenu.action(:cut, "Cut"),
            ContextMenu.action(:copy, "Copy"),
            ContextMenu.separator(),
            ContextMenu.action(:paste, "Paste"),
            ContextMenu.action(:delete, "Delete")
          ],
          on_select: fn id -> send(test_pid, {:selected, id}) end
        )

      {:ok, state} = Inline.init(props)
      %{state: state}
    end

    test "separators are not numbered", %{state: state} do
      # Number map should skip separator
      # 1 -> :cut, 2 -> :copy, 3 -> :paste, 4 -> :delete
      assert state.number_map == %{1 => :cut, 2 => :copy, 3 => :paste, 4 => :delete}
    end

    test "pressing 3 selects paste (after separator)", %{state: state} do
      {:ok, _new_state} = Inline.handle_event(%Event.Key{key: "3"}, state)

      assert_receive {:selected, :paste}
    end
  end

  describe "ContextMenu.Inline with more than 9 items" do
    setup do
      test_pid = self()

      items =
        for i <- 1..12 do
          ContextMenu.action(:"item_#{i}", "Item #{i}")
        end

      props =
        Inline.new(
          items: items,
          on_select: fn id -> send(test_pid, {:selected, id}) end
        )

      {:ok, state} = Inline.init(props)
      %{state: state}
    end

    test "only first 9 items are numbered", %{state: state} do
      assert map_size(state.number_map) == 9
      assert Map.has_key?(state.number_map, 1)
      assert Map.has_key?(state.number_map, 9)
      refute Map.has_key?(state.number_map, 10)
    end

    test "pressing 9 selects ninth item", %{state: state} do
      {:ok, _new_state} = Inline.handle_event(%Event.Key{key: "9"}, state)

      assert_receive {:selected, :item_9}
    end

    test "items 10-12 can be reached with arrow navigation", %{state: state} do
      # Navigate down to item 10
      state =
        Enum.reduce(1..9, state, fn _, s ->
          {:ok, new_s} = Inline.handle_event(%Event.Key{key: :down}, s)
          new_s
        end)

      # Now at item 10
      assert Inline.get_cursor(state) == :item_10

      # Select with Enter
      {:ok, _new_state} = Inline.handle_event(%Event.Key{key: :enter}, state)

      assert_receive {:selected, :item_10}
    end
  end

  describe "ContextMenu.Inline combined keyboard navigation" do
    setup do
      test_pid = self()

      props =
        Inline.new(
          items: [
            ContextMenu.action(:copy, "Copy"),
            ContextMenu.action(:paste, "Paste"),
            ContextMenu.action(:delete, "Delete")
          ],
          on_select: fn id -> send(test_pid, {:selected, id}) end,
          on_close: fn -> send(test_pid, :closed) end
        )

      {:ok, state} = Inline.init(props)
      %{state: state}
    end

    test "arrow navigation still works alongside number selection", %{state: state} do
      # Navigate down
      {:ok, state} = Inline.handle_event(%Event.Key{key: :down}, state)
      assert Inline.get_cursor(state) == :paste

      # Navigate down again
      {:ok, state} = Inline.handle_event(%Event.Key{key: :down}, state)
      assert Inline.get_cursor(state) == :delete

      # Select with Enter
      {:ok, _new_state} = Inline.handle_event(%Event.Key{key: :enter}, state)
      assert_receive {:selected, :delete}
    end

    test "Escape closes menu without selecting", %{state: state} do
      {:ok, new_state} = Inline.handle_event(%Event.Key{key: :escape}, state)

      assert_receive :closed
      refute_receive {:selected, _}
      refute Inline.visible?(new_state)
    end

    test "complete workflow: navigate then use number key", %{state: state} do
      # Navigate down (cursor moves but doesn't affect number mapping)
      {:ok, state} = Inline.handle_event(%Event.Key{key: :down}, state)
      assert Inline.get_cursor(state) == :paste

      # Press number key - should still select first item
      {:ok, _new_state} = Inline.handle_event(%Event.Key{key: "1"}, state)
      assert_receive {:selected, :copy}
    end
  end
end
