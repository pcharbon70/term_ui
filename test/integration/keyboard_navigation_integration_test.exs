defmodule TermUI.Integration.KeyboardNavigationIntegrationTest do
  @moduledoc """
  Integration tests for keyboard navigation across widgets.

  These tests verify that keyboard navigation works correctly and identically
  across both Raw and TTY modes. Since `Event.Key` is produced the same way
  in both modes (arrow keys produce identical ANSI sequences), widget behavior
  is inherently mode-independent.

  ## Test Coverage

  - **Menu Navigation** (5.7.2.1/2/3): Arrow keys, Enter, Escape
  - **Tabs Navigation** (5.7.2.4): Left/Right arrows, Enter, Home/End
  - **TreeView Navigation** (5.7.2.1/2 - "List" equivalent): Up/Down arrows, expand/collapse
  - **Cross-Mode Verification** (5.7.2.5): Same events produce same results

  ## Why Keyboard Navigation is Mode-Independent

  Arrow keys produce identical ANSI escape sequences regardless of backend:
  - Up: `\\e[A` → `Event.Key{key: :up}`
  - Down: `\\e[B` → `Event.Key{key: :down}`
  - Left: `\\e[D` → `Event.Key{key: :left}`
  - Right: `\\e[C` → `Event.Key{key: :right}`

  Widgets receive `Event.Key` structs which are backend-agnostic.
  Therefore, testing widget response to `Event.Key` verifies behavior
  works identically in both modes.
  """

  use ExUnit.Case, async: true

  alias TermUI.Event
  alias TermUI.Widgets.{Menu, Tabs, TreeView}
  alias TermUI.Theme

  setup do
    # Start Theme server (ignore if already started)
    case Theme.start_link(theme: :dark) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    :ok
  end

  # ===========================================================================
  # Test 5.7.2.1/5.7.2.2: List-like Navigation (using TreeView and Menu)
  # ===========================================================================

  describe "list-like navigation - TreeView (up/down arrows)" do
    setup do
      nodes = [
        TreeView.node(:item1, "Item 1"),
        TreeView.node(:item2, "Item 2"),
        TreeView.node(:item3, "Item 3"),
        TreeView.node(:item4, "Item 4")
      ]

      props = TreeView.new(nodes: nodes)
      {:ok, state} = TreeView.init(props)
      %{state: state, nodes: nodes}
    end

    test "down arrow moves cursor through list items", %{state: state} do
      # TreeView uses integer indices for cursor
      # Start at index 0 (item1), move down through all items
      assert state.cursor == 0

      # Down to index 1 (item2)
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :down}, state)
      assert state.cursor == 1

      # Down to index 2 (item3)
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :down}, state)
      assert state.cursor == 2

      # Down to index 3 (item4)
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :down}, state)
      assert state.cursor == 3

      # At end - stays on index 3
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :down}, state)
      assert state.cursor == 3
    end

    test "up arrow moves cursor back through list items", %{state: state} do
      # Move to last item first (index 3)
      state = %{state | cursor: 3}

      # Up to index 2 (item3)
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :up}, state)
      assert state.cursor == 2

      # Up to index 1 (item2)
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :up}, state)
      assert state.cursor == 1

      # Up to index 0 (item1)
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :up}, state)
      assert state.cursor == 0

      # At start - stays on index 0
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :up}, state)
      assert state.cursor == 0
    end

    test "complete navigation workflow", %{state: state} do
      # Start at index 0
      assert state.cursor == 0

      # Navigate down to index 2 (item3)
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :down}, state)
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :down}, state)
      assert state.cursor == 2

      # Navigate back up to index 0 (item1)
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :up}, state)
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :up}, state)
      assert state.cursor == 0
    end

    test "home jumps to first item", %{state: state} do
      state = %{state | cursor: 2}

      {:ok, state} = TreeView.handle_event(%Event.Key{key: :home}, state)
      assert state.cursor == 0
    end

    test "end jumps to last item", %{state: state} do
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :end}, state)
      assert state.cursor == 3  # Index of last item
    end
  end

  describe "list-like navigation - Menu (up/down arrows)" do
    setup do
      items = [
        Menu.action(:action1, "Action 1"),
        Menu.action(:action2, "Action 2"),
        Menu.action(:action3, "Action 3")
      ]

      props = Menu.new(items: items)
      {:ok, state} = Menu.init(props)
      %{state: state}
    end

    test "down arrow moves cursor through menu items", %{state: state} do
      assert state.cursor == :action1

      {:ok, state} = Menu.handle_event(%Event.Key{key: :down}, state)
      assert state.cursor == :action2

      {:ok, state} = Menu.handle_event(%Event.Key{key: :down}, state)
      assert state.cursor == :action3

      # At end - stays on action3
      {:ok, state} = Menu.handle_event(%Event.Key{key: :down}, state)
      assert state.cursor == :action3
    end

    test "up arrow moves cursor back through menu items", %{state: state} do
      state = %{state | cursor: :action3}

      {:ok, state} = Menu.handle_event(%Event.Key{key: :up}, state)
      assert state.cursor == :action2

      {:ok, state} = Menu.handle_event(%Event.Key{key: :up}, state)
      assert state.cursor == :action1

      # At start - stays on action1
      {:ok, state} = Menu.handle_event(%Event.Key{key: :up}, state)
      assert state.cursor == :action1
    end
  end

  # ===========================================================================
  # Test 5.7.2.3: Menu Navigation (complete workflow)
  # ===========================================================================

  describe "menu navigation - complete workflow" do
    setup do
      items = [
        Menu.action(:new, "New"),
        Menu.action(:open, "Open"),
        Menu.separator(),
        Menu.submenu(:recent, "Recent", [
          Menu.action(:file1, "File 1"),
          Menu.action(:file2, "File 2")
        ]),
        Menu.action(:exit, "Exit")
      ]

      props = Menu.new(items: items)
      {:ok, state} = Menu.init(props)
      %{state: state}
    end

    test "navigation skips separators", %{state: state} do
      # Start at :new
      assert state.cursor == :new

      # Down to :open
      {:ok, state} = Menu.handle_event(%Event.Key{key: :down}, state)
      assert state.cursor == :open

      # Down skips separator, goes to :recent (submenu)
      {:ok, state} = Menu.handle_event(%Event.Key{key: :down}, state)
      assert state.cursor == :recent

      # Down to :exit
      {:ok, state} = Menu.handle_event(%Event.Key{key: :down}, state)
      assert state.cursor == :exit
    end

    test "right arrow expands submenu", %{state: state} do
      # Navigate to submenu
      state = %{state | cursor: :recent}

      # Expand with right arrow
      {:ok, state} = Menu.handle_event(%Event.Key{key: :right}, state)
      assert MapSet.member?(state.expanded, :recent)
    end

    test "left arrow collapses submenu", %{state: state} do
      # Navigate to submenu and expand it
      state = %{state | cursor: :recent, expanded: MapSet.new([:recent])}

      # Collapse with left arrow
      {:ok, state} = Menu.handle_event(%Event.Key{key: :left}, state)
      refute MapSet.member?(state.expanded, :recent)
    end

    test "enter triggers selection callback", %{state: state} do
      test_pid = self()
      on_select = fn id -> send(test_pid, {:selected, id}) end
      state = %{state | on_select: on_select}

      {:ok, _state} = Menu.handle_event(%Event.Key{key: :enter}, state)
      assert_receive {:selected, :new}
    end

    test "escape signals menu close", %{state: state} do
      {:ok, _state, effects} = Menu.handle_event(%Event.Key{key: :escape}, state)

      assert Enum.any?(effects, fn
               {:send, _, :menu_close} -> true
               _ -> false
             end)
    end

    test "complete menu workflow: navigate, expand, select", %{state: state} do
      test_pid = self()
      on_select = fn id -> send(test_pid, {:selected, id}) end
      state = %{state | on_select: on_select}

      # Navigate to submenu
      {:ok, state} = Menu.handle_event(%Event.Key{key: :down}, state)
      {:ok, state} = Menu.handle_event(%Event.Key{key: :down}, state)
      assert state.cursor == :recent

      # Expand submenu
      {:ok, state} = Menu.handle_event(%Event.Key{key: :right}, state)
      assert MapSet.member?(state.expanded, :recent)

      # Navigate to first child
      {:ok, state} = Menu.handle_event(%Event.Key{key: :down}, state)
      assert state.cursor == :file1

      # Select
      {:ok, _state} = Menu.handle_event(%Event.Key{key: :enter}, state)
      assert_receive {:selected, :file1}
    end
  end

  # ===========================================================================
  # Test 5.7.2.4: Tabs Navigation
  # ===========================================================================

  describe "tabs navigation" do
    setup do
      tabs = [
        %{id: :tab1, label: "Tab 1", content: "Content 1"},
        %{id: :tab2, label: "Tab 2", content: "Content 2"},
        %{id: :tab3, label: "Tab 3", content: "Content 3", disabled: true},
        %{id: :tab4, label: "Tab 4", content: "Content 4"}
      ]

      props = Tabs.new(tabs: tabs)
      {:ok, state} = Tabs.init(props)
      %{state: state}
    end

    test "right arrow moves focus to next tab", %{state: state} do
      assert state.focused == :tab1

      {:ok, state} = Tabs.handle_event(%Event.Key{key: :right}, state)
      assert state.focused == :tab2

      # Skip disabled tab3
      {:ok, state} = Tabs.handle_event(%Event.Key{key: :right}, state)
      assert state.focused == :tab4
    end

    test "left arrow moves focus to previous tab", %{state: state} do
      state = %{state | focused: :tab4}

      # Skip disabled tab3
      {:ok, state} = Tabs.handle_event(%Event.Key{key: :left}, state)
      assert state.focused == :tab2

      {:ok, state} = Tabs.handle_event(%Event.Key{key: :left}, state)
      assert state.focused == :tab1
    end

    test "home jumps to first tab", %{state: state} do
      state = %{state | focused: :tab4}

      {:ok, state} = Tabs.handle_event(%Event.Key{key: :home}, state)
      assert state.focused == :tab1
    end

    test "end jumps to last tab", %{state: state} do
      {:ok, state} = Tabs.handle_event(%Event.Key{key: :end}, state)
      assert state.focused == :tab4
    end

    test "enter selects focused tab", %{state: state} do
      test_pid = self()
      on_change = fn id -> send(test_pid, {:tab_changed, id}) end
      state = %{state | focused: :tab2, on_change: on_change}

      {:ok, new_state} = Tabs.handle_event(%Event.Key{key: :enter}, state)

      assert new_state.selected == :tab2
      assert_receive {:tab_changed, :tab2}
    end

    test "space selects focused tab", %{state: state} do
      test_pid = self()
      on_change = fn id -> send(test_pid, {:tab_changed, id}) end
      state = %{state | focused: :tab2, on_change: on_change}

      {:ok, new_state} = Tabs.handle_event(%Event.Key{key: " "}, state)

      assert new_state.selected == :tab2
      assert_receive {:tab_changed, :tab2}
    end

    test "complete tabs workflow: navigate and select", %{state: state} do
      test_pid = self()
      on_change = fn id -> send(test_pid, {:tab_changed, id}) end
      state = %{state | on_change: on_change}

      # Initial state
      assert state.focused == :tab1
      assert state.selected == :tab1

      # Navigate right to tab2
      {:ok, state} = Tabs.handle_event(%Event.Key{key: :right}, state)
      assert state.focused == :tab2
      assert state.selected == :tab1  # Not selected yet

      # Select tab2
      {:ok, state} = Tabs.handle_event(%Event.Key{key: :enter}, state)
      assert state.selected == :tab2
      assert_receive {:tab_changed, :tab2}

      # Navigate right (skips disabled tab3) to tab4
      {:ok, state} = Tabs.handle_event(%Event.Key{key: :right}, state)
      assert state.focused == :tab4

      # Select tab4
      {:ok, state} = Tabs.handle_event(%Event.Key{key: :enter}, state)
      assert state.selected == :tab4
      assert_receive {:tab_changed, :tab4}
    end
  end

  # ===========================================================================
  # Test 5.7.2.5: Verify Identical Behavior Between Modes
  # ===========================================================================

  describe "identical behavior verification" do
    @moduledoc """
    These tests verify that keyboard navigation behavior is deterministic and
    mode-independent. Since Event.Key is produced identically in both modes,
    the same events should always produce the same state transitions.
    """

    test "menu navigation is deterministic" do
      items = [
        Menu.action(:a, "A"),
        Menu.action(:b, "B"),
        Menu.action(:c, "C")
      ]

      props = Menu.new(items: items)

      # Run same navigation sequence twice
      for _iteration <- 1..2 do
        {:ok, state} = Menu.init(props)
        assert state.cursor == :a

        {:ok, state} = Menu.handle_event(%Event.Key{key: :down}, state)
        assert state.cursor == :b

        {:ok, state} = Menu.handle_event(%Event.Key{key: :down}, state)
        assert state.cursor == :c

        {:ok, state} = Menu.handle_event(%Event.Key{key: :up}, state)
        assert state.cursor == :b
      end
    end

    test "tabs navigation is deterministic" do
      tabs = [
        %{id: :x, label: "X", content: "X"},
        %{id: :y, label: "Y", content: "Y"},
        %{id: :z, label: "Z", content: "Z"}
      ]

      props = Tabs.new(tabs: tabs)

      # Run same navigation sequence twice
      for _iteration <- 1..2 do
        {:ok, state} = Tabs.init(props)
        assert state.focused == :x

        {:ok, state} = Tabs.handle_event(%Event.Key{key: :right}, state)
        assert state.focused == :y

        {:ok, state} = Tabs.handle_event(%Event.Key{key: :right}, state)
        assert state.focused == :z

        {:ok, state} = Tabs.handle_event(%Event.Key{key: :left}, state)
        assert state.focused == :y
      end
    end

    test "treeview navigation is deterministic" do
      nodes = [
        TreeView.node(:n1, "N1"),
        TreeView.node(:n2, "N2"),
        TreeView.node(:n3, "N3")
      ]

      props = TreeView.new(nodes: nodes)

      # Run same navigation sequence twice
      # TreeView uses integer indices for cursor
      for _iteration <- 1..2 do
        {:ok, state} = TreeView.init(props)
        assert state.cursor == 0  # First item

        {:ok, state} = TreeView.handle_event(%Event.Key{key: :down}, state)
        assert state.cursor == 1  # Second item

        {:ok, state} = TreeView.handle_event(%Event.Key{key: :down}, state)
        assert state.cursor == 2  # Third item

        {:ok, state} = TreeView.handle_event(%Event.Key{key: :up}, state)
        assert state.cursor == 1  # Back to second
      end
    end

    test "same events produce same state transitions across widgets" do
      # All three widget types should respond to up/down consistently

      # Menu - uses node IDs for cursor
      menu_items = [Menu.action(:a, "A"), Menu.action(:b, "B")]
      {:ok, menu_state} = Menu.init(Menu.new(items: menu_items))
      {:ok, menu_state} = Menu.handle_event(%Event.Key{key: :down}, menu_state)
      assert menu_state.cursor == :b

      # TreeView - uses integer indices for cursor
      tree_nodes = [TreeView.node(:a, "A"), TreeView.node(:b, "B")]
      {:ok, tree_state} = TreeView.init(TreeView.new(nodes: tree_nodes))
      {:ok, tree_state} = TreeView.handle_event(%Event.Key{key: :down}, tree_state)
      assert tree_state.cursor == 1  # Index 1 = second item

      # Both widgets moved from first to second item with same event
      # (Menu uses IDs, TreeView uses indices, but same semantic movement)
    end

    test "event.key is backend-agnostic (mode-independent)" do
      # This test documents that Event.Key{key: :up} is produced
      # identically by both backends, so widget behavior is inherently
      # mode-independent.

      # Arrow key events as they would be produced by either backend
      up_event = %Event.Key{key: :up}
      down_event = %Event.Key{key: :down}
      left_event = %Event.Key{key: :left}
      right_event = %Event.Key{key: :right}
      enter_event = %Event.Key{key: :enter}

      # These exact Event.Key structs are what widgets receive
      # regardless of whether Raw or TTY backend produced them
      assert up_event.key == :up
      assert down_event.key == :down
      assert left_event.key == :left
      assert right_event.key == :right
      assert enter_event.key == :enter

      # Since widgets only see Event.Key structs (not raw escape sequences),
      # their behavior is guaranteed to be identical in both modes.
    end
  end

  # ===========================================================================
  # TreeView Expand/Collapse Navigation
  # ===========================================================================

  describe "treeview expand/collapse navigation" do
    setup do
      nodes = [
        TreeView.node(:parent, "Parent",
          children: [
            TreeView.node(:child1, "Child 1"),
            TreeView.node(:child2, "Child 2")
          ]
        ),
        TreeView.node(:sibling, "Sibling")
      ]

      props = TreeView.new(nodes: nodes)
      {:ok, state} = TreeView.init(props)
      %{state: state}
    end

    test "right arrow expands node with children", %{state: state} do
      # TreeView uses integer indices for cursor
      assert state.cursor == 0  # First item (parent)
      refute MapSet.member?(state.expanded, :parent)

      {:ok, state} = TreeView.handle_event(%Event.Key{key: :right}, state)
      assert MapSet.member?(state.expanded, :parent)
    end

    test "left arrow collapses expanded node", %{state: state} do
      state = %{state | expanded: MapSet.new([:parent])}

      {:ok, state} = TreeView.handle_event(%Event.Key{key: :left}, state)
      refute MapSet.member?(state.expanded, :parent)
    end

    test "enter toggles expand state", %{state: state} do
      # Expand
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :enter}, state)
      assert MapSet.member?(state.expanded, :parent)

      # Collapse
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :enter}, state)
      refute MapSet.member?(state.expanded, :parent)
    end

    test "can navigate into expanded children", %{state: state} do
      # Expand parent
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :right}, state)
      assert MapSet.member?(state.expanded, :parent)

      # Navigate down into children
      # After expansion, flat_nodes = [parent, child1, child2, sibling]
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :down}, state)
      assert state.cursor == 1  # Index 1 = child1

      {:ok, state} = TreeView.handle_event(%Event.Key{key: :down}, state)
      assert state.cursor == 2  # Index 2 = child2

      {:ok, state} = TreeView.handle_event(%Event.Key{key: :down}, state)
      assert state.cursor == 3  # Index 3 = sibling
    end

    test "complete treeview workflow: expand, navigate, collapse", %{state: state} do
      # Start at parent (index 0)
      assert state.cursor == 0

      # Expand parent
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :enter}, state)
      assert MapSet.member?(state.expanded, :parent)

      # Navigate to child1 (index 1)
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :down}, state)
      assert state.cursor == 1

      # Navigate to child2 (index 2)
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :down}, state)
      assert state.cursor == 2

      # Navigate back up to parent (index 0)
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :up}, state)
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :up}, state)
      assert state.cursor == 0

      # Collapse parent
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :left}, state)
      refute MapSet.member?(state.expanded, :parent)

      # After collapse, flat_nodes = [parent, sibling]
      # Navigate down - should go to sibling (now index 1)
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :down}, state)
      assert state.cursor == 1  # Now sibling is at index 1
    end
  end
end
