defmodule TermUI.Widgets.SupervisionTreeViewer do
  @moduledoc """
  SupervisionTreeViewer widget for OTP supervision hierarchy visualization.

  SupervisionTreeViewer displays the supervision tree with live status indicators,
  restart counts, and provides controls for process management and inspection.

  ## Usage

      SupervisionTreeViewer.new(
        root: MyApp.Supervisor,
        update_interval: 2000,
        on_select: fn node -> handle_select(node) end
      )

  ## Features

  - Tree view of supervision hierarchy
  - Live status indicators (running, restarting, terminated)
  - Restart count and history display
  - Supervisor strategy display
  - Process state inspection
  - Restart/terminate controls with confirmation
  - Auto-refresh on supervision tree changes

  ## Keyboard Controls

  - Up/Down: Move selection
  - Left: Collapse node or move to parent
  - Right: Expand node or move to first child
  - Enter: Toggle expand/collapse
  - i: Show process info panel
  - r: Restart selected process (with confirmation)
  - k: Terminate selected process (with confirmation)
  - R: Refresh tree
  - /: Filter by name
  - Escape: Clear filter/close panel
  """

  use TermUI.StatefulComponent

  alias TermUI.Event

  @type node_type :: :supervisor | :worker
  @type node_status :: :running | :restarting | :terminated | :undefined

  @type sup_node :: %{
          id: term(),
          pid: pid() | :restarting | :undefined,
          name: atom() | nil,
          type: node_type(),
          status: node_status(),
          child_spec: map() | nil,
          strategy: atom() | nil,
          restart_count: non_neg_integer(),
          max_restarts: non_neg_integer() | nil,
          max_seconds: non_neg_integer() | nil,
          children: [sup_node()] | nil,
          memory: non_neg_integer(),
          reductions: non_neg_integer(),
          message_queue_len: non_neg_integer(),
          depth: non_neg_integer(),
          parent_pid: pid() | nil
        }

  @default_interval 2000
  @page_size 15

  @status_icons %{
    running: "●",
    restarting: "◐",
    terminated: "○",
    undefined: "?"
  }

  @status_colors %{
    running: :green,
    restarting: :yellow,
    terminated: :red,
    undefined: :white
  }

  @type_icons %{
    supervisor: "□",
    worker: "◇"
  }

  @strategy_display %{
    one_for_one: "1:1",
    one_for_all: "1:*",
    rest_for_one: "1:→",
    simple_one_for_one: "1:1+"
  }

  # ----------------------------------------------------------------------------
  # Props
  # ----------------------------------------------------------------------------

  @doc """
  Creates new SupervisionTreeViewer widget props.

  ## Options

  - `:root` - Root supervisor (pid, registered name, or module) - required
  - `:update_interval` - Refresh interval in ms (default: 2000)
  - `:on_select` - Callback when node is selected: `fn node -> ... end`
  - `:on_action` - Callback when action is performed: `fn {:restarted | :terminated, pid} -> ... end`
  - `:show_workers` - Show worker processes (default: true)
  - `:auto_expand` - Expand all nodes initially (default: true)
  """
  @spec new(keyword()) :: map()
  def new(opts) do
    root = Keyword.fetch!(opts, :root)

    %{
      root: root,
      update_interval: Keyword.get(opts, :update_interval, @default_interval),
      on_select: Keyword.get(opts, :on_select),
      on_action: Keyword.get(opts, :on_action),
      show_workers: Keyword.get(opts, :show_workers, true),
      auto_expand: Keyword.get(opts, :auto_expand, true)
    }
  end

  # ----------------------------------------------------------------------------
  # State Initialization
  # ----------------------------------------------------------------------------

  @doc """
  Initializes the SupervisionTreeViewer state.
  """
  @impl true
  def init(props) do
    root_pid = resolve_supervisor(props.root)
    tree = build_tree(root_pid, nil, 0, props.show_workers)

    expanded =
      if props.auto_expand do
        collect_supervisor_ids(tree)
      else
        MapSet.new()
      end

    flattened = flatten_tree(tree, expanded, true)

    state = %{
      root: props.root,
      root_pid: root_pid,
      tree: tree,
      flattened: flattened,
      expanded: expanded,
      selected_idx: 0,
      scroll_offset: 0,
      update_interval: props.update_interval,
      on_select: props.on_select,
      on_action: props.on_action,
      show_workers: props.show_workers,
      show_info: false,
      pending_action: nil,
      filter: nil,
      filter_input: nil
    }

    {:ok, state}
  end

  # ----------------------------------------------------------------------------
  # Event Handling
  # ----------------------------------------------------------------------------

  @impl true
  def handle_event(%Event.Key{key: key}, state) when key in [:up, :down] do
    max_idx = max(0, length(state.flattened) - 1)

    new_idx =
      case key do
        :up -> max(0, state.selected_idx - 1)
        :down -> min(max_idx, state.selected_idx + 1)
      end

    state = %{state | selected_idx: new_idx}
    state = maybe_call_on_select(state)
    {:ok, state}
  end

  def handle_event(%Event.Key{key: :page_up}, state) do
    new_idx = max(0, state.selected_idx - @page_size)
    state = %{state | selected_idx: new_idx}
    state = maybe_call_on_select(state)
    {:ok, state}
  end

  def handle_event(%Event.Key{key: :page_down}, state) do
    max_idx = max(0, length(state.flattened) - 1)
    new_idx = min(max_idx, state.selected_idx + @page_size)
    state = %{state | selected_idx: new_idx}
    state = maybe_call_on_select(state)
    {:ok, state}
  end

  def handle_event(%Event.Key{key: :home}, state) do
    state = %{state | selected_idx: 0}
    state = maybe_call_on_select(state)
    {:ok, state}
  end

  def handle_event(%Event.Key{key: :end}, state) do
    max_idx = max(0, length(state.flattened) - 1)
    state = %{state | selected_idx: max_idx}
    state = maybe_call_on_select(state)
    {:ok, state}
  end

  # Left - collapse or move to parent
  def handle_event(%Event.Key{key: :left}, state) do
    case get_selected(state) do
      nil ->
        {:ok, state}

      node ->
        if node.type == :supervisor and MapSet.member?(state.expanded, node.id) do
          # Collapse this node
          expanded = MapSet.delete(state.expanded, node.id)
          flattened = flatten_tree(state.tree, expanded, true)
          {:ok, %{state | expanded: expanded, flattened: flattened}}
        else
          # Move to parent
          parent_idx = find_parent_idx(state.flattened, state.selected_idx)

          if parent_idx do
            {:ok, %{state | selected_idx: parent_idx}}
          else
            {:ok, state}
          end
        end
    end
  end

  # Right - expand or move to first child
  def handle_event(%Event.Key{key: :right}, state) do
    case get_selected(state) do
      nil ->
        {:ok, state}

      node ->
        if node.type == :supervisor do
          if MapSet.member?(state.expanded, node.id) do
            # Move to first child
            child_idx = state.selected_idx + 1

            if child_idx < length(state.flattened) do
              {:ok, %{state | selected_idx: child_idx}}
            else
              {:ok, state}
            end
          else
            # Expand this node
            expanded = MapSet.put(state.expanded, node.id)
            flattened = flatten_tree(state.tree, expanded, true)
            {:ok, %{state | expanded: expanded, flattened: flattened}}
          end
        else
          {:ok, state}
        end
    end
  end

  # Enter - toggle expand/collapse
  def handle_event(%Event.Key{key: :enter}, state) when state.filter_input != nil do
    # Apply filter
    filter = if state.filter_input == "", do: nil, else: state.filter_input
    flattened = flatten_tree(state.tree, state.expanded, true)

    flattened =
      if filter do
        Enum.filter(flattened, fn node ->
          name_str = node_display_name(node)
          String.contains?(String.downcase(name_str), String.downcase(filter))
        end)
      else
        flattened
      end

    {:ok, %{state | filter: filter, filter_input: nil, flattened: flattened, selected_idx: 0}}
  end

  def handle_event(%Event.Key{key: :enter}, state) do
    case get_selected(state) do
      nil ->
        {:ok, state}

      node ->
        if node.type == :supervisor do
          expanded =
            if MapSet.member?(state.expanded, node.id) do
              MapSet.delete(state.expanded, node.id)
            else
              MapSet.put(state.expanded, node.id)
            end

          flattened = flatten_tree(state.tree, expanded, true)
          {:ok, %{state | expanded: expanded, flattened: flattened}}
        else
          # Toggle info panel for workers
          {:ok, %{state | show_info: not state.show_info}}
        end
    end
  end

  # i - show info panel
  def handle_event(%Event.Key{char: "i"}, state) do
    {:ok, %{state | show_info: not state.show_info}}
  end

  # R - force refresh
  def handle_event(%Event.Key{char: "R"}, state) do
    refresh(state)
  end

  # r - restart process (with confirmation)
  def handle_event(%Event.Key{char: "r"}, state)
      when state.pending_action == nil and state.filter_input == nil do
    case get_selected(state) do
      nil -> {:ok, state}
      _node -> {:ok, %{state | pending_action: :restart}}
    end
  end

  # k - terminate process (with confirmation)
  def handle_event(%Event.Key{char: "k"}, state)
      when state.pending_action == nil and state.filter_input == nil do
    case get_selected(state) do
      nil -> {:ok, state}
      _node -> {:ok, %{state | pending_action: :terminate}}
    end
  end

  # y - confirm action
  def handle_event(%Event.Key{char: "y"}, state) when state.pending_action != nil do
    case get_selected(state) do
      nil ->
        {:ok, %{state | pending_action: nil}}

      node ->
        result = execute_action(state.pending_action, node)

        if state.on_action do
          state.on_action.(result)
        end

        # Refresh after action
        {:ok, state} = refresh(%{state | pending_action: nil})
        {:ok, state}
    end
  end

  # n - cancel action
  def handle_event(%Event.Key{char: "n"}, state) when state.pending_action != nil do
    {:ok, %{state | pending_action: nil}}
  end

  # / - start filter input
  def handle_event(%Event.Key{char: "/"}, state) when state.filter_input == nil do
    {:ok, %{state | filter_input: ""}}
  end

  # Filter input handling
  def handle_event(%Event.Key{char: char}, state)
      when state.filter_input != nil and char != nil do
    {:ok, %{state | filter_input: state.filter_input <> char}}
  end

  def handle_event(%Event.Key{key: :backspace}, state) when state.filter_input != nil do
    new_input =
      if String.length(state.filter_input) > 0 do
        String.slice(state.filter_input, 0..-2//1)
      else
        state.filter_input
      end

    {:ok, %{state | filter_input: new_input}}
  end

  # Escape - close panel, clear filter, cancel action
  def handle_event(%Event.Key{key: :escape}, state) do
    cond do
      state.pending_action != nil ->
        {:ok, %{state | pending_action: nil}}

      state.filter_input != nil ->
        {:ok, %{state | filter_input: nil}}

      state.show_info ->
        {:ok, %{state | show_info: false}}

      state.filter != nil ->
        flattened = flatten_tree(state.tree, state.expanded, true)
        {:ok, %{state | filter: nil, flattened: flattened, selected_idx: 0}}

      true ->
        {:ok, state}
    end
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  # ----------------------------------------------------------------------------
  # Handle Info (Timer)
  # ----------------------------------------------------------------------------

  @impl true
  def handle_info(:refresh, state) do
    refresh(state)
  end

  def handle_info(_msg, state) do
    {:ok, state}
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Forces a refresh of the supervision tree.
  """
  @spec refresh(map()) :: {:ok, map()}
  def refresh(state) do
    root_pid = resolve_supervisor(state.root)
    tree = build_tree(root_pid, nil, 0, state.show_workers)
    flattened = flatten_tree(tree, state.expanded, true)

    # Apply filter if active
    flattened =
      if state.filter do
        Enum.filter(flattened, fn node ->
          name_str = node_display_name(node)
          String.contains?(String.downcase(name_str), String.downcase(state.filter))
        end)
      else
        flattened
      end

    # Adjust selected_idx if out of bounds
    max_idx = max(0, length(flattened) - 1)
    selected_idx = min(state.selected_idx, max_idx)

    {:ok, %{state | root_pid: root_pid, tree: tree, flattened: flattened, selected_idx: selected_idx}}
  end

  @doc """
  Sets the root supervisor.
  """
  @spec set_root(map(), term()) :: {:ok, map()}
  def set_root(state, root) do
    state = %{state | root: root, expanded: MapSet.new(), selected_idx: 0}
    refresh(state)
  end

  @doc """
  Gets the currently selected node.
  """
  @spec get_selected(map()) :: sup_node() | nil
  def get_selected(state) do
    Enum.at(state.flattened, state.selected_idx)
  end

  @doc """
  Expands all supervisor nodes.
  """
  @spec expand_all(map()) :: {:ok, map()}
  def expand_all(state) do
    expanded = collect_supervisor_ids(state.tree)
    flattened = flatten_tree(state.tree, expanded, true)
    {:ok, %{state | expanded: expanded, flattened: flattened}}
  end

  @doc """
  Collapses all nodes.
  """
  @spec collapse_all(map()) :: {:ok, map()}
  def collapse_all(state) do
    expanded = MapSet.new()
    flattened = flatten_tree(state.tree, expanded, true)
    {:ok, %{state | expanded: expanded, flattened: flattened}}
  end

  @doc """
  Gets the process state for the selected node.
  """
  @spec get_process_state(map()) :: {:ok, term()} | {:error, term()}
  def get_process_state(state) do
    case get_selected(state) do
      nil ->
        {:error, :no_selection}

      node ->
        if is_pid(node.pid) and Process.alive?(node.pid) do
          try do
            {:ok, :sys.get_state(node.pid, 1000)}
          catch
            :exit, reason -> {:error, reason}
          end
        else
          {:error, :not_alive}
        end
    end
  end

  # ----------------------------------------------------------------------------
  # Tree Building
  # ----------------------------------------------------------------------------

  defp resolve_supervisor(sup) when is_pid(sup), do: sup
  defp resolve_supervisor(sup) when is_atom(sup), do: Process.whereis(sup)

  defp resolve_supervisor({:via, _, _} = sup) do
    GenServer.whereis(sup)
  end

  defp resolve_supervisor({:global, name}) do
    :global.whereis_name(name)
  end

  defp build_tree(nil, _parent_pid, _depth, _show_workers), do: nil

  defp build_tree(sup_pid, parent_pid, depth, show_workers) do
    children =
      try do
        Supervisor.which_children(sup_pid)
      catch
        :exit, _ -> []
      end

    # Get supervisor info
    {strategy, max_restarts, max_seconds} = get_supervisor_flags(sup_pid)
    process_info = get_process_info(sup_pid)

    child_nodes =
      children
      |> Enum.map(fn {id, child_pid, type, _modules} ->
        build_child_node(id, child_pid, type, sup_pid, depth + 1, show_workers)
      end)
      |> Enum.reject(&is_nil/1)

    %{
      id: sup_pid,
      pid: sup_pid,
      name: get_registered_name(sup_pid),
      type: :supervisor,
      status: :running,
      child_spec: nil,
      strategy: strategy,
      restart_count: 0,
      max_restarts: max_restarts,
      max_seconds: max_seconds,
      children: child_nodes,
      memory: process_info[:memory] || 0,
      reductions: process_info[:reductions] || 0,
      message_queue_len: process_info[:message_queue_len] || 0,
      depth: depth,
      parent_pid: parent_pid
    }
  end

  defp build_child_node(id, child_pid, type, parent_pid, depth, show_workers) do
    case {type, child_pid} do
      {:supervisor, pid} when is_pid(pid) ->
        build_tree(pid, parent_pid, depth, show_workers)

      {:supervisor, :restarting} ->
        %{
          id: id,
          pid: :restarting,
          name: nil,
          type: :supervisor,
          status: :restarting,
          child_spec: nil,
          strategy: nil,
          restart_count: 0,
          max_restarts: nil,
          max_seconds: nil,
          children: nil,
          memory: 0,
          reductions: 0,
          message_queue_len: 0,
          depth: depth,
          parent_pid: parent_pid
        }

      {:supervisor, :undefined} ->
        %{
          id: id,
          pid: :undefined,
          name: nil,
          type: :supervisor,
          status: :undefined,
          child_spec: nil,
          strategy: nil,
          restart_count: 0,
          max_restarts: nil,
          max_seconds: nil,
          children: nil,
          memory: 0,
          reductions: 0,
          message_queue_len: 0,
          depth: depth,
          parent_pid: parent_pid
        }

      {:worker, pid} when is_pid(pid) ->
        if show_workers do
          process_info = get_process_info(pid)

          %{
            id: id,
            pid: pid,
            name: get_registered_name(pid),
            type: :worker,
            status: :running,
            child_spec: nil,
            strategy: nil,
            restart_count: 0,
            max_restarts: nil,
            max_seconds: nil,
            children: nil,
            memory: process_info[:memory] || 0,
            reductions: process_info[:reductions] || 0,
            message_queue_len: process_info[:message_queue_len] || 0,
            depth: depth,
            parent_pid: parent_pid
          }
        else
          nil
        end

      {:worker, :restarting} ->
        if show_workers do
          %{
            id: id,
            pid: :restarting,
            name: nil,
            type: :worker,
            status: :restarting,
            child_spec: nil,
            strategy: nil,
            restart_count: 0,
            max_restarts: nil,
            max_seconds: nil,
            children: nil,
            memory: 0,
            reductions: 0,
            message_queue_len: 0,
            depth: depth,
            parent_pid: parent_pid
          }
        else
          nil
        end

      {:worker, :undefined} ->
        if show_workers do
          %{
            id: id,
            pid: :undefined,
            name: nil,
            type: :worker,
            status: :undefined,
            child_spec: nil,
            strategy: nil,
            restart_count: 0,
            max_restarts: nil,
            max_seconds: nil,
            children: nil,
            memory: 0,
            reductions: 0,
            message_queue_len: 0,
            depth: depth,
            parent_pid: parent_pid
          }
        else
          nil
        end
    end
  end

  defp get_supervisor_flags(sup_pid) do
    try do
      # Try to get supervisor init args
      case :sys.get_state(sup_pid, 500) do
        %{strategy: strategy, intensity: intensity, period: period} ->
          {strategy, intensity, period}

        # For older supervisor state format
        state when is_tuple(state) ->
          # Try to extract from supervisor internal state
          {:one_for_one, nil, nil}

        _ ->
          {:one_for_one, nil, nil}
      end
    catch
      :exit, _ -> {:one_for_one, nil, nil}
    end
  end

  defp get_process_info(pid) when is_pid(pid) do
    case Process.info(pid, [:memory, :reductions, :message_queue_len, :registered_name]) do
      nil -> []
      info -> info
    end
  end

  defp get_process_info(_), do: []

  defp get_registered_name(pid) when is_pid(pid) do
    case Process.info(pid, :registered_name) do
      {:registered_name, name} -> name
      _ -> nil
    end
  end

  defp get_registered_name(_), do: nil

  # ----------------------------------------------------------------------------
  # Tree Flattening
  # ----------------------------------------------------------------------------

  defp flatten_tree(nil, _expanded, _visible), do: []

  defp flatten_tree(node, expanded, visible) do
    if visible do
      children_visible = MapSet.member?(expanded, node.id) and node.children != nil

      children_nodes =
        if children_visible and node.children do
          Enum.flat_map(node.children, &flatten_tree(&1, expanded, true))
        else
          []
        end

      [node | children_nodes]
    else
      []
    end
  end

  defp collect_supervisor_ids(nil), do: MapSet.new()

  defp collect_supervisor_ids(node) do
    if node.type == :supervisor do
      children_ids =
        if node.children do
          Enum.reduce(node.children, MapSet.new(), fn child, acc ->
            MapSet.union(acc, collect_supervisor_ids(child))
          end)
        else
          MapSet.new()
        end

      MapSet.put(children_ids, node.id)
    else
      MapSet.new()
    end
  end

  defp find_parent_idx(flattened, current_idx) do
    case Enum.at(flattened, current_idx) do
      nil ->
        nil

      current ->
        current_depth = current.depth

        flattened
        |> Enum.take(current_idx)
        |> Enum.with_index()
        |> Enum.reverse()
        |> Enum.find_value(fn {node, idx} ->
          if node.depth < current_depth, do: idx, else: nil
        end)
    end
  end

  # ----------------------------------------------------------------------------
  # Actions
  # ----------------------------------------------------------------------------

  defp execute_action(:restart, node) do
    case {node.parent_pid, node.id} do
      {nil, _} ->
        {:error, :no_parent}

      {parent_pid, child_id} ->
        try do
          case Supervisor.restart_child(parent_pid, child_id) do
            {:ok, _pid} -> {:restarted, node.pid}
            {:ok, _pid, _info} -> {:restarted, node.pid}
            {:error, reason} -> {:error, reason}
          end
        catch
          :exit, reason -> {:error, reason}
        end
    end
  end

  defp execute_action(:terminate, node) do
    case {node.parent_pid, node.id} do
      {nil, _} ->
        {:error, :no_parent}

      {parent_pid, child_id} ->
        try do
          case Supervisor.terminate_child(parent_pid, child_id) do
            :ok -> {:terminated, node.pid}
            {:error, reason} -> {:error, reason}
          end
        catch
          :exit, reason -> {:error, reason}
        end
    end
  end

  # ----------------------------------------------------------------------------
  # Helpers
  # ----------------------------------------------------------------------------

  defp maybe_call_on_select(state) do
    if state.on_select do
      case get_selected(state) do
        nil -> state
        node -> state.on_select.(node)
      end
    end

    state
  end

  defp node_display_name(node) do
    cond do
      node.name != nil ->
        inspect(node.name)

      is_pid(node.pid) ->
        inspect(node.pid)

      true ->
        inspect(node.id)
    end
  end

  # ----------------------------------------------------------------------------
  # Rendering
  # ----------------------------------------------------------------------------

  @impl true
  def render(state, area) do
    header = render_header(state)
    tree_view = render_tree_view(state, area)
    filter_line = render_filter_line(state)
    info_panel = render_info_panel(state)
    confirmation = render_confirmation(state)
    footer = render_footer(state)

    children =
      [header, tree_view, filter_line, info_panel, confirmation, footer]
      |> Enum.reject(&is_nil/1)

    stack(:vertical, children)
  end

  defp render_header(state) do
    root_name =
      if state.tree do
        node_display_name(state.tree)
      else
        "No supervisor"
      end

    count = length(state.flattened)

    text(
      "Supervision Tree: #{root_name} | Nodes: #{count}",
      Style.new(fg: :cyan, attrs: [:bold])
    )
  end

  defp render_tree_view(state, area) do
    visible_height = min(area.height - 4, length(state.flattened))

    # Calculate scroll offset to keep selected in view
    scroll_offset =
      cond do
        state.selected_idx < state.scroll_offset ->
          state.selected_idx

        state.selected_idx >= state.scroll_offset + visible_height ->
          state.selected_idx - visible_height + 1

        true ->
          state.scroll_offset
      end

    visible_nodes =
      state.flattened
      |> Enum.drop(scroll_offset)
      |> Enum.take(visible_height)
      |> Enum.with_index(scroll_offset)

    if Enum.empty?(visible_nodes) do
      text("  No processes found", Style.new(fg: :white, attrs: [:dim]))
    else
      lines =
        Enum.map(visible_nodes, fn {node, idx} ->
          render_node_line(node, idx == state.selected_idx, state.expanded)
        end)

      stack(:vertical, lines)
    end
  end

  defp render_node_line(node, selected, expanded) do
    indent = String.duplicate("  ", node.depth)

    # Expand/collapse indicator
    expand_indicator =
      case {node.type, node.children} do
        {:supervisor, children} when is_list(children) and length(children) > 0 ->
          if MapSet.member?(expanded, node.id), do: "▼ ", else: "▶ "

        {:supervisor, _} ->
          "▶ "

        _ ->
          "  "
      end

    # Status icon with color
    status_icon = Map.get(@status_icons, node.status, "?")
    status_color = Map.get(@status_colors, node.status, :white)

    # Type icon
    type_icon = Map.get(@type_icons, node.type, " ")

    # Name
    name = node_display_name(node)

    # Strategy for supervisors
    strategy_str =
      if node.type == :supervisor and node.strategy do
        " [#{Map.get(@strategy_display, node.strategy, "?")}]"
      else
        ""
      end

    # Memory info
    memory_str =
      if node.memory > 0 do
        " #{format_bytes(node.memory)}"
      else
        ""
      end

    content = "#{indent}#{expand_indicator}#{type_icon} #{name}#{strategy_str}#{memory_str}"

    # For now, render as simple text with status indicator prefix
    full_content = "#{status_icon} #{content}"

    if selected do
      text(full_content, Style.new(bg: :blue, fg: :white))
    else
      # Use the status color for the whole line
      text(full_content, Style.new(fg: status_color))
    end
  end

  defp render_filter_line(state) do
    cond do
      state.filter_input != nil ->
        text("Filter: #{state.filter_input}_", Style.new(fg: :yellow))

      state.filter != nil ->
        text("Filter: #{state.filter} (Esc to clear)", Style.new(fg: :yellow, attrs: [:dim]))

      true ->
        nil
    end
  end

  defp render_info_panel(state) do
    if state.show_info do
      case get_selected(state) do
        nil ->
          nil

        node ->
          lines = [
            text("─── Process Info ───", Style.new(fg: :cyan)),
            text("  ID: #{inspect(node.id)}", nil),
            text("  PID: #{inspect(node.pid)}", nil),
            text("  Name: #{inspect(node.name)}", nil),
            text("  Type: #{node.type}", nil),
            text("  Status: #{node.status}", Style.new(fg: Map.get(@status_colors, node.status, :white)))
          ]

          lines =
            if node.type == :supervisor do
              lines ++
                [
                  text("  Strategy: #{node.strategy || "unknown"}", nil),
                  text("  Max restarts: #{node.max_restarts || "?"}/#{node.max_seconds || "?"}s", nil)
                ]
            else
              lines
            end

          lines =
            lines ++
              [
                text("  Memory: #{format_bytes(node.memory)}", nil),
                text("  Reductions: #{format_number(node.reductions)}", nil),
                text("  Msg Queue: #{node.message_queue_len}", nil)
              ]

          stack(:vertical, lines)
      end
    else
      nil
    end
  end

  defp render_confirmation(state) do
    case state.pending_action do
      nil ->
        nil

      :restart ->
        node = get_selected(state)
        name = if node, do: node_display_name(node), else: "?"
        text("Restart #{name}? [y/n]", Style.new(fg: :yellow, attrs: [:bold]))

      :terminate ->
        node = get_selected(state)
        name = if node, do: node_display_name(node), else: "?"
        text("Terminate #{name}? [y/n]", Style.new(fg: :red, attrs: [:bold]))
    end
  end

  defp render_footer(_state) do
    text(
      "[↑↓] Navigate [←→] Expand/Collapse [i] Info [r] Restart [k] Kill [R] Refresh [/] Filter",
      Style.new(fg: :white, attrs: [:dim])
    )
  end

  # ----------------------------------------------------------------------------
  # Formatting Helpers
  # ----------------------------------------------------------------------------

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes}B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)}KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1024 / 1024, 1)}MB"

  defp format_number(n) when n < 1000, do: "#{n}"
  defp format_number(n) when n < 1_000_000, do: "#{Float.round(n / 1000, 1)}K"
  defp format_number(n), do: "#{Float.round(n / 1_000_000, 1)}M"
end
