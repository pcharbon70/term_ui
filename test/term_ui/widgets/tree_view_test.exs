defmodule TermUI.Widgets.TreeViewTest do
  use ExUnit.Case, async: true

  alias TermUI.Event
  alias TermUI.Widgets.TreeView

  @default_area %{x: 0, y: 0, width: 80, height: 24}

  # ----------------------------------------------------------------------------
  # Node Constructors
  # ----------------------------------------------------------------------------

  describe "node constructors" do
    test "node/3 creates a tree node with defaults" do
      node = TreeView.node(:test, "Test Node")

      assert node.id == :test
      assert node.label == "Test Node"
      assert node.icon == nil
      assert node.children == nil
      assert node.disabled == false
      assert node.metadata == %{}
    end

    test "node/3 accepts options" do
      node = TreeView.node(:test, "Test", icon: "📁", disabled: true, metadata: %{key: "value"})

      assert node.icon == "📁"
      assert node.disabled == true
      assert node.metadata == %{key: "value"}
    end

    test "leaf/3 creates a leaf node (no children)" do
      node = TreeView.leaf(:leaf, "Leaf Node")

      assert node.id == :leaf
      assert node.children == nil
    end

    test "branch/4 creates a branch node with children" do
      children = [TreeView.leaf(:child, "Child")]
      node = TreeView.branch(:parent, "Parent", children)

      assert node.id == :parent
      assert node.children == children
    end

    test "lazy/3 creates a lazy-loading node" do
      node = TreeView.lazy(:lazy, "Lazy Node")

      assert node.id == :lazy
      assert node.children == :lazy
    end
  end

  # ----------------------------------------------------------------------------
  # Initialization
  # ----------------------------------------------------------------------------

  describe "initialization" do
    test "init/1 creates initial state" do
      props = TreeView.new(nodes: [TreeView.leaf(:root, "Root")])
      {:ok, state} = TreeView.init(props)

      assert state.nodes == props.nodes
      assert state.cursor == 0
      assert state.selection_mode == :single
      assert MapSet.size(state.expanded) == 0
      assert MapSet.size(state.selected) == 0
    end

    test "init/1 expands initially_expanded nodes" do
      child = TreeView.leaf(:child, "Child")
      root = TreeView.branch(:root, "Root", [child])

      props = TreeView.new(nodes: [root], initially_expanded: [:root])
      {:ok, state} = TreeView.init(props)

      assert MapSet.member?(state.expanded, :root)
      # Should have 2 visible nodes (root + child)
      assert length(state.flat_nodes) == 2
    end

    test "init/1 selects initially_selected nodes" do
      props =
        TreeView.new(
          nodes: [TreeView.leaf(:a, "A"), TreeView.leaf(:b, "B")],
          initially_selected: [:b]
        )

      {:ok, state} = TreeView.init(props)

      assert MapSet.member?(state.selected, :b)
    end
  end

  # ----------------------------------------------------------------------------
  # Rendering
  # ----------------------------------------------------------------------------

  describe "rendering" do
    test "renders empty tree" do
      props = TreeView.new(nodes: [])
      {:ok, state} = TreeView.init(props)

      result = TreeView.render(state, @default_area)
      assert result != nil
    end

    test "renders single node" do
      props = TreeView.new(nodes: [TreeView.leaf(:root, "Root")])
      {:ok, state} = TreeView.init(props)

      result = TreeView.render(state, @default_area)
      assert result != nil
    end

    test "renders tree with correct indentation" do
      child = TreeView.leaf(:child, "Child")
      root = TreeView.branch(:root, "Root", [child])

      props = TreeView.new(nodes: [root], initially_expanded: [:root])
      {:ok, state} = TreeView.init(props)

      result = TreeView.render(state, @default_area)
      assert result.type == :stack
    end

    test "shows expand indicator for collapsed branch" do
      child = TreeView.leaf(:child, "Child")
      root = TreeView.branch(:root, "Root", [child])

      props = TreeView.new(nodes: [root])
      {:ok, state} = TreeView.init(props)

      # Only root is visible when collapsed
      assert length(state.flat_nodes) == 1
    end

    test "shows expand indicator for expanded branch" do
      child = TreeView.leaf(:child, "Child")
      root = TreeView.branch(:root, "Root", [child])

      props = TreeView.new(nodes: [root], initially_expanded: [:root])
      {:ok, state} = TreeView.init(props)

      # Root and child visible when expanded
      assert length(state.flat_nodes) == 2
    end

    test "renders custom icons" do
      node = TreeView.leaf(:file, "file.txt", icon: "📄")
      props = TreeView.new(nodes: [node])
      {:ok, state} = TreeView.init(props)

      result = TreeView.render(state, @default_area)
      assert result != nil
    end
  end

  # ----------------------------------------------------------------------------
  # Keyboard Navigation
  # ----------------------------------------------------------------------------

  describe "keyboard navigation" do
    test "down arrow moves cursor down" do
      nodes = [TreeView.leaf(:a, "A"), TreeView.leaf(:b, "B")]
      props = TreeView.new(nodes: nodes)
      {:ok, state} = TreeView.init(props)

      assert state.cursor == 0

      {:ok, state} = TreeView.handle_event(%Event.Key{key: :down}, state)
      assert state.cursor == 1
    end

    test "up arrow moves cursor up" do
      nodes = [TreeView.leaf(:a, "A"), TreeView.leaf(:b, "B")]
      props = TreeView.new(nodes: nodes)
      {:ok, state} = TreeView.init(props)

      {:ok, state} = TreeView.handle_event(%Event.Key{key: :down}, state)
      assert state.cursor == 1

      {:ok, state} = TreeView.handle_event(%Event.Key{key: :up}, state)
      assert state.cursor == 0
    end

    test "cursor stops at top" do
      nodes = [TreeView.leaf(:a, "A"), TreeView.leaf(:b, "B")]
      props = TreeView.new(nodes: nodes)
      {:ok, state} = TreeView.init(props)

      {:ok, state} = TreeView.handle_event(%Event.Key{key: :up}, state)
      assert state.cursor == 0
    end

    test "cursor stops at bottom" do
      nodes = [TreeView.leaf(:a, "A"), TreeView.leaf(:b, "B")]
      props = TreeView.new(nodes: nodes)
      {:ok, state} = TreeView.init(props)

      {:ok, state} = TreeView.handle_event(%Event.Key{key: :down}, state)
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :down}, state)
      assert state.cursor == 1
    end

    test "home jumps to first node" do
      nodes = [TreeView.leaf(:a, "A"), TreeView.leaf(:b, "B"), TreeView.leaf(:c, "C")]
      props = TreeView.new(nodes: nodes)
      {:ok, state} = TreeView.init(props)

      {:ok, state} = TreeView.handle_event(%Event.Key{key: :end}, state)
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :home}, state)
      assert state.cursor == 0
    end

    test "end jumps to last node" do
      nodes = [TreeView.leaf(:a, "A"), TreeView.leaf(:b, "B"), TreeView.leaf(:c, "C")]
      props = TreeView.new(nodes: nodes)
      {:ok, state} = TreeView.init(props)

      {:ok, state} = TreeView.handle_event(%Event.Key{key: :end}, state)
      assert state.cursor == 2
    end

    test "page_down jumps by 10" do
      nodes = for i <- 1..20, do: TreeView.leaf(:"node_#{i}", "Node #{i}")
      props = TreeView.new(nodes: nodes)
      {:ok, state} = TreeView.init(props)

      {:ok, state} = TreeView.handle_event(%Event.Key{key: :page_down}, state)
      assert state.cursor == 10
    end

    test "page_up jumps by 10" do
      nodes = for i <- 1..20, do: TreeView.leaf(:"node_#{i}", "Node #{i}")
      props = TreeView.new(nodes: nodes)
      {:ok, state} = TreeView.init(props)

      {:ok, state} = TreeView.handle_event(%Event.Key{key: :end}, state)
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :page_up}, state)
      assert state.cursor == 9
    end
  end

  # ----------------------------------------------------------------------------
  # Expand/Collapse
  # ----------------------------------------------------------------------------

  describe "expand/collapse" do
    test "right arrow expands collapsed node" do
      child = TreeView.leaf(:child, "Child")
      root = TreeView.branch(:root, "Root", [child])

      props = TreeView.new(nodes: [root])
      {:ok, state} = TreeView.init(props)

      assert length(state.flat_nodes) == 1
      refute MapSet.member?(state.expanded, :root)

      {:ok, state} = TreeView.handle_event(%Event.Key{key: :right}, state)

      assert MapSet.member?(state.expanded, :root)
      assert length(state.flat_nodes) == 2
    end

    test "left arrow collapses expanded node" do
      child = TreeView.leaf(:child, "Child")
      root = TreeView.branch(:root, "Root", [child])

      props = TreeView.new(nodes: [root], initially_expanded: [:root])
      {:ok, state} = TreeView.init(props)

      assert length(state.flat_nodes) == 2

      {:ok, state} = TreeView.handle_event(%Event.Key{key: :left}, state)

      refute MapSet.member?(state.expanded, :root)
      assert length(state.flat_nodes) == 1
    end

    test "enter toggles expand on branch" do
      child = TreeView.leaf(:child, "Child")
      root = TreeView.branch(:root, "Root", [child])

      props = TreeView.new(nodes: [root])
      {:ok, state} = TreeView.init(props)

      # Expand
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :enter}, state)
      assert MapSet.member?(state.expanded, :root)

      # Collapse
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :enter}, state)
      refute MapSet.member?(state.expanded, :root)
    end

    test "space toggles expand on branch" do
      child = TreeView.leaf(:child, "Child")
      root = TreeView.branch(:root, "Root", [child])

      props = TreeView.new(nodes: [root])
      {:ok, state} = TreeView.init(props)

      {:ok, state} = TreeView.handle_event(%Event.Key{key: " "}, state)
      assert MapSet.member?(state.expanded, :root)
    end

    test "left on leaf moves to parent" do
      child = TreeView.leaf(:child, "Child")
      root = TreeView.branch(:root, "Root", [child])

      props = TreeView.new(nodes: [root], initially_expanded: [:root])
      {:ok, state} = TreeView.init(props)

      # Move to child
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :down}, state)
      assert state.cursor == 1

      # Left should move to parent
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :left}, state)
      assert state.cursor == 0
    end

    test "right on expanded branch moves to first child" do
      child = TreeView.leaf(:child, "Child")
      root = TreeView.branch(:root, "Root", [child])

      props = TreeView.new(nodes: [root], initially_expanded: [:root])
      {:ok, state} = TreeView.init(props)

      assert state.cursor == 0

      {:ok, state} = TreeView.handle_event(%Event.Key{key: :right}, state)
      assert state.cursor == 1
    end
  end

  # ----------------------------------------------------------------------------
  # Selection
  # ----------------------------------------------------------------------------

  describe "single selection" do
    test "enter selects leaf node" do
      nodes = [TreeView.leaf(:a, "A"), TreeView.leaf(:b, "B")]
      props = TreeView.new(nodes: nodes, selection_mode: :single)
      {:ok, state} = TreeView.init(props)

      {:ok, state} = TreeView.handle_event(%Event.Key{key: :enter}, state)
      assert MapSet.member?(state.selected, :a)
    end

    test "selecting new node deselects previous in single mode" do
      nodes = [TreeView.leaf(:a, "A"), TreeView.leaf(:b, "B")]
      props = TreeView.new(nodes: nodes, selection_mode: :single)
      {:ok, state} = TreeView.init(props)

      # Select A
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :enter}, state)
      assert MapSet.member?(state.selected, :a)

      # Move to B and select
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :down}, state)
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :enter}, state)

      assert MapSet.member?(state.selected, :b)
      refute MapSet.member?(state.selected, :a)
    end

    test "escape clears selection" do
      nodes = [TreeView.leaf(:a, "A")]
      props = TreeView.new(nodes: nodes, selection_mode: :single)
      {:ok, state} = TreeView.init(props)

      {:ok, state} = TreeView.handle_event(%Event.Key{key: :enter}, state)
      assert MapSet.size(state.selected) == 1

      {:ok, state} = TreeView.handle_event(%Event.Key{key: :escape}, state)
      assert MapSet.size(state.selected) == 0
    end
  end

  describe "multi selection" do
    test "space toggles selection in multi mode" do
      nodes = [TreeView.leaf(:a, "A"), TreeView.leaf(:b, "B")]
      props = TreeView.new(nodes: nodes, selection_mode: :multi)
      {:ok, state} = TreeView.init(props)

      # Select A
      {:ok, state} = TreeView.handle_event(%Event.Key{key: " "}, state)
      assert MapSet.member?(state.selected, :a)

      # Move to B and select (keeps A)
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :down}, state)
      {:ok, state} = TreeView.handle_event(%Event.Key{key: " "}, state)

      assert MapSet.member?(state.selected, :a)
      assert MapSet.member?(state.selected, :b)
    end

    test "space deselects already selected in multi mode" do
      nodes = [TreeView.leaf(:a, "A")]
      props = TreeView.new(nodes: nodes, selection_mode: :multi)
      {:ok, state} = TreeView.init(props)

      {:ok, state} = TreeView.handle_event(%Event.Key{key: " "}, state)
      assert MapSet.member?(state.selected, :a)

      {:ok, state} = TreeView.handle_event(%Event.Key{key: " "}, state)
      refute MapSet.member?(state.selected, :a)
    end

    test "ctrl+a selects all in multi mode" do
      nodes = [TreeView.leaf(:a, "A"), TreeView.leaf(:b, "B"), TreeView.leaf(:c, "C")]
      props = TreeView.new(nodes: nodes, selection_mode: :multi)
      {:ok, state} = TreeView.init(props)

      {:ok, state} = TreeView.handle_event(%Event.Key{char: "a", modifiers: [:ctrl]}, state)

      assert MapSet.size(state.selected) == 3
      assert MapSet.member?(state.selected, :a)
      assert MapSet.member?(state.selected, :b)
      assert MapSet.member?(state.selected, :c)
    end

    test "ctrl+a does nothing in single mode" do
      nodes = [TreeView.leaf(:a, "A"), TreeView.leaf(:b, "B")]
      props = TreeView.new(nodes: nodes, selection_mode: :single)
      {:ok, state} = TreeView.init(props)

      {:ok, state} = TreeView.handle_event(%Event.Key{char: "a", modifiers: [:ctrl]}, state)

      assert MapSet.size(state.selected) == 0
    end

    test "shift+down extends selection" do
      nodes = [TreeView.leaf(:a, "A"), TreeView.leaf(:b, "B"), TreeView.leaf(:c, "C")]
      props = TreeView.new(nodes: nodes, selection_mode: :multi)
      {:ok, state} = TreeView.init(props)

      {:ok, state} = TreeView.handle_event(%Event.Key{key: :down, modifiers: [:shift]}, state)
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :down, modifiers: [:shift]}, state)

      assert MapSet.size(state.selected) == 3
    end
  end

  describe "no selection" do
    test "selection does nothing in :none mode" do
      nodes = [TreeView.leaf(:a, "A")]
      props = TreeView.new(nodes: nodes, selection_mode: :none)
      {:ok, state} = TreeView.init(props)

      {:ok, state} = TreeView.handle_event(%Event.Key{key: :enter}, state)
      assert MapSet.size(state.selected) == 0
    end
  end

  # ----------------------------------------------------------------------------
  # Filtering
  # ----------------------------------------------------------------------------

  describe "filtering" do
    test "/ starts filter mode" do
      nodes = [TreeView.leaf(:a, "Apple"), TreeView.leaf(:b, "Banana")]
      props = TreeView.new(nodes: nodes)
      {:ok, state} = TreeView.init(props)

      assert state.filter == nil

      {:ok, state} = TreeView.handle_event(%Event.Key{char: "/"}, state)
      assert state.filter == ""
    end

    test "typing in filter mode filters nodes" do
      nodes = [TreeView.leaf(:a, "Apple"), TreeView.leaf(:b, "Banana")]
      props = TreeView.new(nodes: nodes)
      {:ok, state} = TreeView.init(props)

      {:ok, state} = TreeView.handle_event(%Event.Key{char: "/"}, state)
      {:ok, state} = TreeView.handle_event(%Event.Key{char: "a"}, state)
      {:ok, state} = TreeView.handle_event(%Event.Key{char: "p"}, state)

      assert state.filter == "ap"
      # Should match "Apple"
      assert MapSet.member?(state.filter_matches, :a)
      refute MapSet.member?(state.filter_matches, :b)
    end

    test "backspace deletes filter character" do
      nodes = [TreeView.leaf(:a, "Apple")]
      props = TreeView.new(nodes: nodes)
      {:ok, state} = TreeView.init(props)

      {:ok, state} = TreeView.handle_event(%Event.Key{char: "/"}, state)
      {:ok, state} = TreeView.handle_event(%Event.Key{char: "a"}, state)
      {:ok, state} = TreeView.handle_event(%Event.Key{char: "p"}, state)

      assert state.filter == "ap"

      {:ok, state} = TreeView.handle_event(%Event.Key{key: :backspace}, state)
      assert state.filter == "a"
    end

    test "escape clears filter" do
      nodes = [TreeView.leaf(:a, "Apple")]
      props = TreeView.new(nodes: nodes)
      {:ok, state} = TreeView.init(props)

      {:ok, state} = TreeView.handle_event(%Event.Key{char: "/"}, state)
      {:ok, state} = TreeView.handle_event(%Event.Key{char: "a"}, state)

      {:ok, state} = TreeView.handle_event(%Event.Key{key: :escape}, state)
      assert state.filter == nil
    end

    test "filter auto-expands parent nodes of matches" do
      grandchild = TreeView.leaf(:gc, "Target")
      child = TreeView.branch(:child, "Child", [grandchild])
      root = TreeView.branch(:root, "Root", [child])

      props = TreeView.new(nodes: [root])
      {:ok, state} = TreeView.init(props)

      # Initially only root is visible
      assert length(state.flat_nodes) == 1

      # Filter for "Target"
      {:ok, state} = TreeView.handle_event(%Event.Key{char: "/"}, state)
      {:ok, state} = TreeView.handle_event(%Event.Key{char: "t"}, state)
      {:ok, state} = TreeView.handle_event(%Event.Key{char: "a"}, state)
      {:ok, state} = TreeView.handle_event(%Event.Key{char: "r"}, state)

      # Parents should be expanded to show match
      assert MapSet.member?(state.expanded, :root)
      assert MapSet.member?(state.expanded, :child)
    end
  end

  # ----------------------------------------------------------------------------
  # Lazy Loading
  # ----------------------------------------------------------------------------

  describe "lazy loading" do
    test "expanding lazy node sets loading state" do
      root = TreeView.lazy(:root, "Lazy Root")
      props = TreeView.new(nodes: [root])
      {:ok, state} = TreeView.init(props)

      {:ok, state} = TreeView.handle_event(%Event.Key{key: :right}, state)

      assert MapSet.member?(state.loading, :root)
    end

    test "on_expand callback is called for lazy nodes" do
      test_pid = self()
      root = TreeView.lazy(:root, "Lazy Root")

      props =
        TreeView.new(
          nodes: [root],
          on_expand: fn node -> send(test_pid, {:expanded, node.id}) end
        )

      {:ok, state} = TreeView.init(props)

      {:ok, _state} = TreeView.handle_event(%Event.Key{key: :right}, state)

      assert_receive {:expanded, :root}
    end

    test "set_children updates lazy node children" do
      root = TreeView.lazy(:root, "Lazy Root")
      props = TreeView.new(nodes: [root])
      {:ok, state} = TreeView.init(props)

      # Expand to trigger loading
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :right}, state)
      assert MapSet.member?(state.loading, :root)

      # Simulate receiving children
      children = [TreeView.leaf(:child1, "Child 1"), TreeView.leaf(:child2, "Child 2")]
      state = TreeView.set_children(state, :root, children)

      refute MapSet.member?(state.loading, :root)
      assert MapSet.member?(state.expanded, :root)
      # Root + 2 children
      assert length(state.flat_nodes) == 3
    end
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  describe "public API" do
    test "get_selected returns selected node IDs" do
      nodes = [TreeView.leaf(:a, "A"), TreeView.leaf(:b, "B")]
      props = TreeView.new(nodes: nodes, initially_selected: [:a, :b])
      {:ok, state} = TreeView.init(props)

      selected = TreeView.get_selected(state)
      assert MapSet.member?(selected, :a)
      assert MapSet.member?(selected, :b)
    end

    test "get_focused returns current node" do
      nodes = [TreeView.leaf(:a, "A"), TreeView.leaf(:b, "B")]
      props = TreeView.new(nodes: nodes)
      {:ok, state} = TreeView.init(props)

      focused = TreeView.get_focused(state)
      assert focused.id == :a
    end

    test "get_expanded returns expanded node IDs" do
      child = TreeView.leaf(:child, "Child")
      root = TreeView.branch(:root, "Root", [child])

      props = TreeView.new(nodes: [root], initially_expanded: [:root])
      {:ok, state} = TreeView.init(props)

      expanded = TreeView.get_expanded(state)
      assert MapSet.member?(expanded, :root)
    end

    test "expand/2 expands a node" do
      child = TreeView.leaf(:child, "Child")
      root = TreeView.branch(:root, "Root", [child])

      props = TreeView.new(nodes: [root])
      {:ok, state} = TreeView.init(props)

      state = TreeView.expand(state, :root)
      assert MapSet.member?(state.expanded, :root)
    end

    test "collapse/2 collapses a node" do
      child = TreeView.leaf(:child, "Child")
      root = TreeView.branch(:root, "Root", [child])

      props = TreeView.new(nodes: [root], initially_expanded: [:root])
      {:ok, state} = TreeView.init(props)

      state = TreeView.collapse(state, :root)
      refute MapSet.member?(state.expanded, :root)
    end

    test "expand_all/1 expands all nodes" do
      grandchild = TreeView.leaf(:gc, "Grandchild")
      child = TreeView.branch(:child, "Child", [grandchild])
      root = TreeView.branch(:root, "Root", [child])

      props = TreeView.new(nodes: [root])
      {:ok, state} = TreeView.init(props)

      state = TreeView.expand_all(state)

      assert MapSet.member?(state.expanded, :root)
      assert MapSet.member?(state.expanded, :child)
      # All 3 nodes visible
      assert length(state.flat_nodes) == 3
    end

    test "collapse_all/1 collapses all nodes" do
      grandchild = TreeView.leaf(:gc, "Grandchild")
      child = TreeView.branch(:child, "Child", [grandchild])
      root = TreeView.branch(:root, "Root", [child])

      props = TreeView.new(nodes: [root], initially_expanded: [:root, :child])
      {:ok, state} = TreeView.init(props)

      state = TreeView.collapse_all(state)

      refute MapSet.member?(state.expanded, :root)
      refute MapSet.member?(state.expanded, :child)
      # Only root visible
      assert length(state.flat_nodes) == 1
    end

    test "set_selected/2 sets selection" do
      nodes = [TreeView.leaf(:a, "A"), TreeView.leaf(:b, "B")]
      props = TreeView.new(nodes: nodes)
      {:ok, state} = TreeView.init(props)

      state = TreeView.set_selected(state, [:a, :b])

      assert MapSet.member?(state.selected, :a)
      assert MapSet.member?(state.selected, :b)
    end

    test "clear_selection/1 clears selection" do
      nodes = [TreeView.leaf(:a, "A")]
      props = TreeView.new(nodes: nodes, initially_selected: [:a])
      {:ok, state} = TreeView.init(props)

      state = TreeView.clear_selection(state)
      assert MapSet.size(state.selected) == 0
    end

    test "set_filter/2 sets filter" do
      nodes = [TreeView.leaf(:a, "Apple"), TreeView.leaf(:b, "Banana")]
      props = TreeView.new(nodes: nodes)
      {:ok, state} = TreeView.init(props)

      state = TreeView.set_filter(state, "app")

      assert state.filter == "app"
      assert MapSet.member?(state.filter_matches, :a)
    end

    test "clear_filter/1 clears filter" do
      nodes = [TreeView.leaf(:a, "Apple")]
      props = TreeView.new(nodes: nodes)
      {:ok, state} = TreeView.init(props)

      state = TreeView.set_filter(state, "app")
      state = TreeView.clear_filter(state)

      assert state.filter == nil
      assert MapSet.size(state.filter_matches) == 0
    end
  end

  # ----------------------------------------------------------------------------
  # Update Callback
  # ----------------------------------------------------------------------------

  describe "update/2" do
    test "updates nodes" do
      props = TreeView.new(nodes: [TreeView.leaf(:a, "A")])
      {:ok, state} = TreeView.init(props)

      new_nodes = [TreeView.leaf(:b, "B"), TreeView.leaf(:c, "C")]
      {:ok, state} = TreeView.update(%{nodes: new_nodes}, state)

      assert length(state.flat_nodes) == 2
    end

    test "clamps cursor on node removal" do
      nodes = [TreeView.leaf(:a, "A"), TreeView.leaf(:b, "B"), TreeView.leaf(:c, "C")]
      props = TreeView.new(nodes: nodes)
      {:ok, state} = TreeView.init(props)

      # Move to last node
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :end}, state)
      assert state.cursor == 2

      # Update with fewer nodes
      {:ok, state} = TreeView.update(%{nodes: [TreeView.leaf(:x, "X")]}, state)
      assert state.cursor == 0
    end
  end

  # ----------------------------------------------------------------------------
  # Callbacks
  # ----------------------------------------------------------------------------

  describe "callbacks" do
    test "on_select is called on selection" do
      test_pid = self()
      nodes = [TreeView.leaf(:a, "A")]

      props =
        TreeView.new(
          nodes: nodes,
          selection_mode: :single,
          on_select: fn node -> send(test_pid, {:selected, node.id}) end
        )

      {:ok, state} = TreeView.init(props)

      {:ok, _state} = TreeView.handle_event(%Event.Key{key: :enter}, state)

      assert_receive {:selected, :a}
    end

    test "on_expand is called on expand" do
      test_pid = self()
      child = TreeView.leaf(:child, "Child")
      root = TreeView.branch(:root, "Root", [child])

      props =
        TreeView.new(
          nodes: [root],
          on_expand: fn node -> send(test_pid, {:expanded, node.id}) end
        )

      {:ok, state} = TreeView.init(props)

      {:ok, _state} = TreeView.handle_event(%Event.Key{key: :right}, state)

      assert_receive {:expanded, :root}
    end

    test "on_collapse is called on collapse" do
      test_pid = self()
      child = TreeView.leaf(:child, "Child")
      root = TreeView.branch(:root, "Root", [child])

      props =
        TreeView.new(
          nodes: [root],
          initially_expanded: [:root],
          on_collapse: fn node -> send(test_pid, {:collapsed, node.id}) end
        )

      {:ok, state} = TreeView.init(props)

      {:ok, _state} = TreeView.handle_event(%Event.Key{key: :left}, state)

      assert_receive {:collapsed, :root}
    end
  end

  # ----------------------------------------------------------------------------
  # Edge Cases
  # ----------------------------------------------------------------------------

  describe "edge cases" do
    test "handles empty children list" do
      root = TreeView.branch(:root, "Root", [])
      props = TreeView.new(nodes: [root])
      {:ok, state} = TreeView.init(props)

      # Empty children means it's a leaf
      {:ok, state} = TreeView.handle_event(%Event.Key{key: :right}, state)
      # Should not expand (no children)
      assert length(state.flat_nodes) == 1
    end

    test "handles deeply nested tree" do
      # Create 10-level deep tree
      deepest = TreeView.leaf(:level10, "Level 10")

      tree =
        Enum.reduce(9..1//-1, deepest, fn level, child ->
          TreeView.branch(:"level#{level}", "Level #{level}", [child])
        end)

      props = TreeView.new(nodes: [tree])
      {:ok, state} = TreeView.init(props)

      # Expand all
      state = TreeView.expand_all(state)
      assert length(state.flat_nodes) == 10
    end

    test "handles multiple root nodes" do
      roots = [
        TreeView.branch(:a, "A", [TreeView.leaf(:a1, "A1")]),
        TreeView.branch(:b, "B", [TreeView.leaf(:b1, "B1")]),
        TreeView.leaf(:c, "C")
      ]

      props = TreeView.new(nodes: roots)
      {:ok, state} = TreeView.init(props)

      assert length(state.flat_nodes) == 3

      state = TreeView.expand_all(state)
      # A, A1, B, B1, C
      assert length(state.flat_nodes) == 5
    end

    test "disabled nodes render but don't select" do
      nodes = [TreeView.leaf(:disabled, "Disabled", disabled: true)]
      props = TreeView.new(nodes: nodes)
      {:ok, state} = TreeView.init(props)

      result = TreeView.render(state, @default_area)
      assert result != nil
    end
  end
end
