defmodule TreeView.App do
  @moduledoc """
  TreeView Widget Example

  This example demonstrates how to use the TermUI.Widgets.TreeView widget
  for displaying hierarchical data with expand/collapse functionality.

  Features demonstrated:
  - Hierarchical tree structure with indentation
  - Expand/collapse with keyboard
  - Single and multi-selection modes
  - Custom node icons
  - Search/filter with path highlighting
  - Lazy loading simulation

  Controls:
  - Up/Down: Navigate between nodes
  - Left: Collapse node or move to parent
  - Right: Expand node or move to first child
  - Enter/Space: Toggle expand or select
  - Home/End: Jump to first/last node
  - /: Start search filter
  - Escape: Clear filter or selection
  - M: Toggle multi-select mode
  - E: Expand all
  - C: Collapse all
  - L: Load lazy node children
  - Q: Quit the application
  """

  use TermUI.Elm

  alias TermUI.Event
  alias TermUI.Renderer.Style
  alias TermUI.Widgets.TreeView, as: TV

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.
  """
  def init(_opts) do
    %{
      tree_state: nil,
      selection_mode: :single,
      status_message: "Navigate with arrows, Enter to expand/select"
    }
  end

  defp build_tree_state(selection_mode) do
    nodes = build_file_tree()

    props = TV.new(
      nodes: nodes,
      selection_mode: selection_mode,
      initially_expanded: [:root, :src],
      icons: %{
        expanded: "▼",
        collapsed: "▶",
        leaf: " ",
        loading: "⟳"
      }
    )

    {:ok, tree_state} = TV.init(props)
    tree_state
  end

  defp build_file_tree do
    [
      TV.branch(:root, "my_project", [
        TV.branch(:src, "src", [
          TV.branch(:lib, "lib", [
            TV.leaf(:main, "main.ex", icon: "📄"),
            TV.leaf(:utils, "utils.ex", icon: "📄"),
            TV.leaf(:config, "config.ex", icon: "📄")
          ]),
          TV.branch(:test, "test", [
            TV.leaf(:main_test, "main_test.exs", icon: "🧪"),
            TV.leaf(:utils_test, "utils_test.exs", icon: "🧪")
          ])
        ]),
        TV.branch(:docs, "docs", [
          TV.leaf(:readme, "README.md", icon: "📝"),
          TV.leaf(:changelog, "CHANGELOG.md", icon: "📝"),
          TV.leaf(:license, "LICENSE", icon: "📋")
        ]),
        TV.lazy(:deps, "deps (lazy)", icon: "📦"),
        TV.branch(:config_dir, "config", [
          TV.leaf(:config_exs, "config.exs", icon: "⚙️"),
          TV.leaf(:dev_exs, "dev.exs", icon: "⚙️"),
          TV.leaf(:prod_exs, "prod.exs", icon: "⚙️")
        ]),
        TV.leaf(:mix_exs, "mix.exs", icon: "📄"),
        TV.leaf(:mix_lock, "mix.lock", icon: "🔒"),
        TV.leaf(:gitignore, ".gitignore", icon: "🚫")
      ], icon: "📁")
    ]
  end

  @doc """
  Convert keyboard events to messages.
  """
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"], do: {:msg, :quit}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["m", "M"], do: {:msg, :toggle_mode}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["e", "E"], do: {:msg, :expand_all}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["c", "C"], do: {:msg, :collapse_all}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["l", "L"], do: {:msg, :load_lazy}
  def event_to_msg(event, _state) do
    # Forward other events to tree
    {:msg, {:tree_event, event}}
  end

  @doc """
  Update state based on messages.
  """
  def update(:quit, state) do
    {state, [:quit]}
  end

  def update(:toggle_mode, state) do
    new_mode = if state.selection_mode == :single, do: :multi, else: :single
    tree_state = build_tree_state(new_mode)
    message = "Selection mode: #{new_mode}"
    {%{state | selection_mode: new_mode, tree_state: tree_state, status_message: message}, []}
  end

  def update(:expand_all, state) do
    tree_state = ensure_tree_state(state)
    tree_state = TV.expand_all(tree_state)
    {%{state | tree_state: tree_state, status_message: "Expanded all nodes"}, []}
  end

  def update(:collapse_all, state) do
    tree_state = ensure_tree_state(state)
    tree_state = TV.collapse_all(tree_state)
    {%{state | tree_state: tree_state, status_message: "Collapsed all nodes"}, []}
  end

  def update(:load_lazy, state) do
    tree_state = ensure_tree_state(state)
    focused = TV.get_focused(tree_state)

    if focused && focused.children == :lazy do
      # Simulate loading children
      children = [
        TV.leaf(:dep1, "jason", icon: "📦"),
        TV.leaf(:dep2, "plug", icon: "📦"),
        TV.leaf(:dep3, "ecto", icon: "📦"),
        TV.leaf(:dep4, "phoenix", icon: "📦")
      ]
      tree_state = TV.set_children(tree_state, focused.id, children)
      {%{state | tree_state: tree_state, status_message: "Loaded children for #{focused.label}"}, []}
    else
      {%{state | status_message: "Focus a lazy node (📦) and press L to load"}, []}
    end
  end

  def update({:tree_event, event}, state) do
    tree_state = ensure_tree_state(state)
    {:ok, tree_state} = TV.handle_event(event, tree_state)

    # Update status based on state
    message = get_status_message(tree_state)
    {%{state | tree_state: tree_state, status_message: message}, []}
  end

  defp ensure_tree_state(state) do
    state.tree_state || build_tree_state(state.selection_mode)
  end

  defp get_status_message(tree_state) do
    focused = TV.get_focused(tree_state)
    selected = TV.get_selected(tree_state)
    filter = tree_state.filter

    cond do
      filter != nil ->
        "Filter: #{filter} (#{MapSet.size(tree_state.filter_matches)} matches)"

      MapSet.size(selected) > 0 ->
        "Selected: #{MapSet.size(selected)} node(s)"

      focused ->
        "Focused: #{focused.label}"

      true ->
        "Navigate with arrows"
    end
  end

  @doc """
  Render the current state to a render tree.
  """
  def view(state) do
    tree_state = ensure_tree_state(state)

    stack(:vertical, [
      # Title
      text("TreeView Widget Example", Style.new(fg: :cyan, attrs: [:bold])),
      text("", nil),

      # Tree view
      render_tree_container(tree_state),

      # Status
      text("", nil),
      text(state.status_message, Style.new(fg: :yellow)),

      # Controls
      render_controls(state)
    ])
  end

  defp render_tree_container(tree_state) do
    # Render the tree
    tree_render = TV.render(tree_state, %{x: 0, y: 0, width: 60, height: 20})

    box_width = 62
    inner_width = box_width - 2

    top_border = "┌─ File Browser " <> String.duplicate("─", inner_width - 16) <> "┐"
    bottom_border = "└" <> String.duplicate("─", inner_width) <> "┘"

    stack(:vertical, [
      text(top_border, Style.new(fg: :blue)),
      stack(:horizontal, [
        text("│ ", nil),
        tree_render,
        text(" │", nil)
      ]),
      text(bottom_border, Style.new(fg: :blue))
    ])
  end

  defp render_controls(state) do
    box_width = 50
    inner_width = box_width - 2

    mode_str = if state.selection_mode == :single, do: "single", else: "multi"

    top_border = "┌─ Controls " <> String.duplicate("─", inner_width - 12) <> "─┐"
    bottom_border = "└" <> String.duplicate("─", inner_width) <> "┘"

    stack(:vertical, [
      text("", nil),
      text(top_border, Style.new(fg: :yellow)),
      text("│" <> String.pad_trailing("  ↑/↓       Navigate", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  ←/→       Collapse/Expand", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Enter     Toggle expand/select", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Home/End  First/Last node", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  /         Start search filter", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Escape    Clear filter/selection", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  M         Toggle mode (#{mode_str})", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  E/C       Expand/Collapse all", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  L         Load lazy node", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Q         Quit", inner_width) <> "│", nil),
      text(bottom_border, Style.new(fg: :yellow))
    ])
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Run the tree view example application.
  """
  def run do
    TermUI.Runtime.run(root: __MODULE__)
  end
end
