# TreeView Widget Example

This example demonstrates how to use the `TermUI.Widgets.TreeView` widget for displaying hierarchical data with expand/collapse functionality.

## Features Demonstrated

- Hierarchical tree structure with indentation
- Expand/collapse nodes with keyboard
- Single and multi-selection modes
- Custom node icons
- Search/filter with path highlighting
- Lazy loading simulation
- Keyboard navigation (arrows, Home/End, Page Up/Down)

## Installation

```bash
cd examples/tree_view
mix deps.get
```

## Running

```bash
mix run run.exs
```

## Controls

| Key | Action |
|-----|--------|
| ↑/↓ | Navigate between visible nodes |
| ← | Collapse node or move to parent |
| → | Expand node or move to first child |
| Enter/Space | Toggle expand or select |
| Home/End | Jump to first/last node |
| Page Up/Down | Jump by 10 nodes |
| / | Start search filter |
| Escape | Clear filter or selection |
| Backspace | Delete character from filter |
| M | Toggle multi-select mode |
| E | Expand all nodes |
| C | Collapse all nodes |
| L | Load lazy node children (for nodes with 📦) |
| Q | Quit |

## Code Overview

### Creating Tree Nodes

```elixir
alias TermUI.Widgets.TreeView

# Leaf node (no children)
TreeView.leaf(:id, "Label", icon: "📄")

# Branch node with children
TreeView.branch(:parent, "Parent", [
  TreeView.leaf(:child1, "Child 1"),
  TreeView.leaf(:child2, "Child 2")
], icon: "📁")

# Lazy-loading node (children loaded on demand)
TreeView.lazy(:deps, "Dependencies", icon: "📦")
```

### Creating a TreeView

```elixir
props = TreeView.new(
  nodes: [
    TreeView.branch(:root, "Root", [
      TreeView.branch(:folder1, "Folder 1", [
        TreeView.leaf(:file1, "file1.txt", icon: "📄"),
        TreeView.leaf(:file2, "file2.txt", icon: "📄")
      ], icon: "📁"),
      TreeView.lazy(:deps, "Dependencies", icon: "📦")
    ], icon: "📁")
  ],
  selection_mode: :single,      # :single, :multi, or :none
  initially_expanded: [:root],  # Node IDs to expand initially
  on_select: fn node -> IO.puts("Selected: #{node.label}") end,
  on_expand: fn node -> load_children(node) end
)

{:ok, state} = TreeView.init(props)
```

### Widget Options

```elixir
TreeView.new(
  nodes: [],                    # List of root nodes (required)
  selection_mode: :single,      # :single, :multi, :none
  show_root: true,              # Show root nodes
  indent_size: 2,               # Characters per indent level
  icons: %{                     # Icon configuration
    expanded: "▼",
    collapsed: "▶",
    leaf: " ",
    loading: "⟳"
  },
  initially_expanded: [],       # Node IDs to expand initially
  initially_selected: [],       # Node IDs to select initially
  on_select: fn node -> ... end,     # Selection callback
  on_expand: fn node -> ... end,     # Expand callback
  on_collapse: fn node -> ... end    # Collapse callback
)
```

### Node Structure

Each node is a map with:

```elixir
%{
  id: :unique_id,           # Unique identifier (required)
  label: "Display Name",    # Display text (required)
  icon: "📄",               # Optional icon string
  children: [child_nodes],  # List of children, :lazy, or nil for leaf
  disabled: false,          # Whether node is disabled
  metadata: %{}             # User-defined data
}
```

## TreeView API

```elixir
# Get selected node IDs
selected = TreeView.get_selected(state)  # Returns MapSet

# Get focused node
node = TreeView.get_focused(state)

# Get expanded node IDs
expanded = TreeView.get_expanded(state)

# Expand/collapse nodes
state = TreeView.expand(state, node_id)
state = TreeView.collapse(state, node_id)
state = TreeView.expand_all(state)
state = TreeView.collapse_all(state)

# Selection operations
state = TreeView.set_selected(state, [node_id1, node_id2])
state = TreeView.clear_selection(state)

# Filter operations
state = TreeView.set_filter(state, "search term")
state = TreeView.clear_filter(state)

# Lazy loading
state = TreeView.set_children(state, node_id, [child_nodes])
state = TreeView.finish_loading(state, node_id)
```

## Features

### Selection Modes

- **Single**: Select one node at a time (default)
- **Multi**: Select multiple nodes with Space, extend selection with Shift+arrows
- **None**: No selection allowed

### Search/Filter

Press `/` to enter filter mode. Type to search node labels:
- Matching nodes are highlighted in yellow
- Non-matching nodes are hidden
- Parent paths to matches are automatically expanded
- Filter text and match count shown at top
- Press Escape to clear filter

### Lazy Loading

Nodes with `children: :lazy` show a loading icon (⟳) and can load children on demand:

```elixir
# Mark node as lazy
TreeView.lazy(:deps, "Dependencies", icon: "📦")

# In your on_expand callback:
on_expand: fn node ->
  if node.children == :lazy do
    # Load children asynchronously
    children = load_children_from_api(node.id)
    send(self(), {:set_children, node.id, children})
  end
end

# When children are loaded:
state = TreeView.set_children(state, node_id, children)
```

### Visual Indicators

| Indicator | Meaning |
|-----------|---------|
| ► | Collapsed branch |
| ▼ | Expanded branch |
| ● | Cursor + selected |
| ► | Cursor (not selected) |
| ○ | Selected (not at cursor) |
| (space) | Normal node |
| (yellow) | Filter match |
| (dimmed) | Disabled node |

### Keyboard Navigation

The TreeView supports efficient keyboard navigation:

- **Arrow keys**: Navigate through visible nodes
- **Left/Right**: Smart navigation (collapse/expand or move to parent/child)
- **Home/End**: Jump to boundaries
- **Page Up/Down**: Fast scrolling
- **Enter/Space**: Context-aware action (expand/collapse or select)

### Multi-Selection

In multi-select mode:
- **Space**: Toggle individual node selection
- **Shift+Up/Down**: Extend selection range
- **Ctrl+A**: Select all nodes
- **Escape**: Clear selection

## Example Structure

The example creates a simulated file browser with:

- **my_project** (root folder)
  - **src** (source code)
    - **lib** (library code with .ex files)
    - **test** (test files with .exs files)
  - **docs** (documentation with .md files)
  - **deps** (lazy-loaded dependencies)
  - **config** (configuration files)
  - Various project files (.gitignore, mix.exs, etc.)

Each file type has a custom icon (📄, 🧪, 📝, ⚙️, 📦, etc.) to demonstrate icon support.

## Widget API

See `lib/term_ui/widgets/tree_view.ex` for the full API documentation.
