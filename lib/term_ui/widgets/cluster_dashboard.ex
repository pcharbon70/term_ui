defmodule TermUI.Widgets.ClusterDashboard do
  @moduledoc """
  ClusterDashboard widget for visualizing distributed Erlang clusters.

  ClusterDashboard displays cluster connectivity, node health metrics,
  cross-node process registries, and connection events. It provides
  tools for monitoring and debugging distributed BEAM applications.

  ## Usage

      ClusterDashboard.new(
        update_interval: 2000,
        show_health_metrics: true,
        show_pg_groups: true
      )

  ## Features

  - Connected nodes list with status indicators
  - Node health metrics (CPU, memory, scheduler utilization)
  - Cross-node process registry (:global names)
  - PG group membership visualization
  - Network partition detection and alerts
  - Node connection/disconnection event log
  - RPC interface for remote node inspection

  ## Keyboard Controls

  - Up/Down: Navigate node/item list
  - PageUp/PageDown: Scroll by page
  - Enter: Toggle details panel
  - r: Refresh now
  - g: Show :global names view
  - p: Show :pg groups view
  - n: Show nodes view
  - e: Show events view
  - i: Inspect selected node (RPC details)
  - Escape: Close details
  """

  use TermUI.StatefulComponent

  alias TermUI.Event

  @type view_mode :: :nodes | :globals | :pg_groups | :events
  @type node_status :: :connected | :disconnected | :local

  @type node_info :: %{
          node: node(),
          status: node_status(),
          connected_at: DateTime.t() | nil,
          metrics: map() | nil
        }

  @type node_event :: %{
          node: node(),
          event: :nodeup | :nodedown,
          timestamp: DateTime.t()
        }

  @default_interval 2000
  @page_size 10
  @max_events 50
  @rpc_timeout 5000

  # ----------------------------------------------------------------------------
  # Props
  # ----------------------------------------------------------------------------

  @doc """
  Creates new ClusterDashboard widget props.

  ## Options

  - `:update_interval` - Refresh interval in ms (default: 2000)
  - `:show_health_metrics` - Fetch and show CPU/memory/load (default: true)
  - `:show_pg_groups` - Show :pg process groups (default: true)
  - `:show_global_names` - Show :global registered names (default: true)
  - `:on_node_select` - Callback when node is selected
  """
  @spec new(keyword()) :: map()
  def new(opts \\ []) do
    %{
      update_interval: Keyword.get(opts, :update_interval, @default_interval),
      show_health_metrics: Keyword.get(opts, :show_health_metrics, true),
      show_pg_groups: Keyword.get(opts, :show_pg_groups, true),
      show_global_names: Keyword.get(opts, :show_global_names, true),
      on_node_select: Keyword.get(opts, :on_node_select)
    }
  end

  # ----------------------------------------------------------------------------
  # StatefulComponent Callbacks
  # ----------------------------------------------------------------------------

  @impl true
  def init(props) do
    state = %{
      # View state
      view_mode: :nodes,
      selected_idx: 0,
      scroll_offset: 0,
      show_details: false,

      # Data
      nodes: [],
      global_names: [],
      pg_groups: [],
      events: [],

      # Partition detection
      known_nodes: MapSet.new(),
      partition_alert: nil,

      # Settings
      update_interval: props.update_interval,
      show_health_metrics: props.show_health_metrics,
      show_pg_groups: props.show_pg_groups,
      show_global_names: props.show_global_names,
      timer_ref: nil,

      # Callbacks
      on_node_select: props.on_node_select,

      # Viewport
      viewport_height: 15,
      viewport_width: 80
    }

    # Fetch initial data
    nodes = fetch_nodes(state)
    global_names = if state.show_global_names, do: fetch_global_names(), else: []
    pg_groups = if state.show_pg_groups, do: fetch_pg_groups(), else: []
    known = MapSet.new(Enum.map(nodes, & &1.node))

    state = %{
      state
      | nodes: nodes,
        global_names: global_names,
        pg_groups: pg_groups,
        known_nodes: known
    }

    {:ok, state}
  end

  @impl true
  def mount(state) do
    # Start node monitoring
    :ok = start_node_monitoring()

    # Start refresh timer
    timer_ref = schedule_refresh(state.update_interval)
    {:ok, %{state | timer_ref: timer_ref}}
  end

  @impl true
  def unmount(state) do
    if state.timer_ref do
      Process.cancel_timer(state.timer_ref)
    end

    stop_node_monitoring()
    :ok
  end

  # ----------------------------------------------------------------------------
  # Event Handling
  # ----------------------------------------------------------------------------

  @impl true
  def handle_event(%Event.Key{key: :up}, state) do
    move_selection(state, -1)
  end

  def handle_event(%Event.Key{key: :down}, state) do
    move_selection(state, 1)
  end

  def handle_event(%Event.Key{key: :page_up}, state) do
    move_selection(state, -@page_size)
  end

  def handle_event(%Event.Key{key: :page_down}, state) do
    move_selection(state, @page_size)
  end

  def handle_event(%Event.Key{key: :home}, state) do
    {:ok, %{state | selected_idx: 0, scroll_offset: 0}}
  end

  def handle_event(%Event.Key{key: :end}, state) do
    count = get_item_count(state)
    last = max(0, count - 1)
    scroll = max(0, count - state.viewport_height)
    {:ok, %{state | selected_idx: last, scroll_offset: scroll}}
  end

  # Enter - toggle details
  def handle_event(%Event.Key{key: :enter}, state) do
    {:ok, %{state | show_details: not state.show_details}}
  end

  # r - refresh
  def handle_event(%Event.Key{char: "r"}, state) do
    refresh(state)
  end

  # n - nodes view
  def handle_event(%Event.Key{char: "n"}, state) do
    {:ok, %{state | view_mode: :nodes, selected_idx: 0, scroll_offset: 0, show_details: false}}
  end

  # g - global names view
  def handle_event(%Event.Key{char: "g"}, state) do
    {:ok, %{state | view_mode: :globals, selected_idx: 0, scroll_offset: 0, show_details: false}}
  end

  # p - pg groups view
  def handle_event(%Event.Key{char: "p"}, state) do
    {:ok,
     %{state | view_mode: :pg_groups, selected_idx: 0, scroll_offset: 0, show_details: false}}
  end

  # e - events view
  def handle_event(%Event.Key{char: "e"}, state) do
    {:ok, %{state | view_mode: :events, selected_idx: 0, scroll_offset: 0, show_details: false}}
  end

  # i - inspect node (RPC)
  def handle_event(%Event.Key{char: "i"}, state) when state.view_mode == :nodes do
    node_info = Enum.at(state.nodes, state.selected_idx)

    if node_info && node_info.status == :connected do
      {:ok, %{state | show_details: true}}
    else
      {:ok, state}
    end
  end

  def handle_event(%Event.Key{char: "i"}, state), do: {:ok, state}

  # Escape - close details / clear alert
  def handle_event(%Event.Key{key: :escape}, state) do
    cond do
      state.show_details ->
        {:ok, %{state | show_details: false}}

      state.partition_alert ->
        {:ok, %{state | partition_alert: nil}}

      true ->
        {:ok, state}
    end
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  # ----------------------------------------------------------------------------
  # Message Handling
  # ----------------------------------------------------------------------------

  @impl true
  def handle_info(:refresh, state) do
    state = do_refresh(state)
    timer_ref = schedule_refresh(state.update_interval)
    {:ok, %{state | timer_ref: timer_ref}}
  end

  # Node monitoring events
  def handle_info({:nodeup, node}, state) do
    event = %{node: node, event: :nodeup, timestamp: DateTime.utc_now()}
    events = [event | state.events] |> Enum.take(@max_events)

    # Update known nodes
    known = MapSet.put(state.known_nodes, node)

    # Refresh node list
    nodes = fetch_nodes(state)

    {:ok, %{state | nodes: nodes, events: events, known_nodes: known, partition_alert: nil}}
  end

  def handle_info({:nodedown, node}, state) do
    event = %{node: node, event: :nodedown, timestamp: DateTime.utc_now()}
    events = [event | state.events] |> Enum.take(@max_events)

    # Check for partition (multiple nodes down in quick succession)
    recent_downs =
      events
      |> Enum.filter(fn e ->
        e.event == :nodedown &&
          DateTime.diff(DateTime.utc_now(), e.timestamp, :second) < 5
      end)
      |> length()

    partition_alert =
      if recent_downs >= 2 do
        "Potential network partition detected! #{recent_downs} nodes disconnected"
      else
        state.partition_alert
      end

    # Refresh node list
    nodes = fetch_nodes(state)

    {:ok, %{state | nodes: nodes, events: events, partition_alert: partition_alert}}
  end

  def handle_info(_msg, state) do
    {:ok, state}
  end

  # ----------------------------------------------------------------------------
  # Data Fetching
  # ----------------------------------------------------------------------------

  defp fetch_nodes(state) do
    # Get local node info
    local_node = %{
      node: node(),
      status: :local,
      connected_at: nil,
      metrics: if(state.show_health_metrics, do: fetch_local_metrics(), else: nil)
    }

    # Get connected nodes
    connected =
      Node.list()
      |> Enum.map(fn n ->
        %{
          node: n,
          status: :connected,
          connected_at: nil,
          metrics: if(state.show_health_metrics, do: fetch_remote_metrics(n), else: nil)
        }
      end)

    [local_node | connected]
  end

  defp fetch_local_metrics do
    %{
      memory: :erlang.memory(),
      process_count: length(Process.list()),
      scheduler_count: :erlang.system_info(:schedulers_online),
      uptime: get_uptime(),
      otp_release: :erlang.system_info(:otp_release) |> to_string()
    }
  end

  defp fetch_remote_metrics(node) do
    try do
      case :rpc.call(node, :erlang, :memory, [], @rpc_timeout) do
        {:badrpc, _reason} ->
          nil

        memory ->
          process_count =
            case :rpc.call(node, Process, :list, [], @rpc_timeout) do
              {:badrpc, _} -> 0
              list -> length(list)
            end

          scheduler_count =
            case :rpc.call(node, :erlang, :system_info, [:schedulers_online], @rpc_timeout) do
              {:badrpc, _} -> 0
              count -> count
            end

          %{
            memory: memory,
            process_count: process_count,
            scheduler_count: scheduler_count,
            uptime: nil,
            otp_release: nil
          }
      end
    rescue
      _ -> nil
    catch
      _, _ -> nil
    end
  end

  defp fetch_global_names do
    try do
      :global.registered_names()
      |> Enum.map(fn name ->
        pid = :global.whereis_name(name)

        node =
          if is_pid(pid) do
            node(pid)
          else
            :unknown
          end

        %{name: name, pid: pid, node: node}
      end)
      |> Enum.sort_by(& &1.name)
    rescue
      _ -> []
    catch
      _, _ -> []
    end
  end

  defp fetch_pg_groups do
    try do
      # Try OTP 23+ :pg module
      groups = :pg.which_groups()

      Enum.map(groups, fn group ->
        members = :pg.get_members(group)

        nodes =
          members
          |> Enum.map(&node/1)
          |> Enum.uniq()

        %{
          group: group,
          member_count: length(members),
          nodes: nodes
        }
      end)
      |> Enum.sort_by(& &1.group)
    rescue
      _ -> []
    catch
      :exit, {:noproc, _} ->
        # :pg not started
        []

      _, _ ->
        []
    end
  end

  defp get_uptime do
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    div(uptime_ms, 1000)
  end

  # ----------------------------------------------------------------------------
  # Node Monitoring
  # ----------------------------------------------------------------------------

  defp start_node_monitoring do
    try do
      :net_kernel.monitor_nodes(true)
    rescue
      _ -> :ok
    catch
      _, _ -> :ok
    end
  end

  defp stop_node_monitoring do
    try do
      :net_kernel.monitor_nodes(false)
    rescue
      _ -> :ok
    catch
      _, _ -> :ok
    end
  end

  # ----------------------------------------------------------------------------
  # Navigation
  # ----------------------------------------------------------------------------

  defp move_selection(state, delta) do
    count = get_item_count(state)

    if count == 0 do
      {:ok, state}
    else
      new_idx = state.selected_idx + delta
      new_idx = max(0, min(new_idx, count - 1))

      new_scroll =
        cond do
          new_idx < state.scroll_offset ->
            new_idx

          new_idx >= state.scroll_offset + state.viewport_height ->
            new_idx - state.viewport_height + 1

          true ->
            state.scroll_offset
        end

      new_state = %{state | selected_idx: new_idx, scroll_offset: max(0, new_scroll)}

      # Call on_node_select callback for nodes view
      if state.view_mode == :nodes && state.on_node_select && new_idx != state.selected_idx do
        node_info = Enum.at(state.nodes, new_idx)
        if node_info, do: state.on_node_select.(node_info)
      end

      {:ok, new_state}
    end
  end

  defp get_item_count(state) do
    case state.view_mode do
      :nodes -> length(state.nodes)
      :globals -> length(state.global_names)
      :pg_groups -> length(state.pg_groups)
      :events -> length(state.events)
    end
  end

  # ----------------------------------------------------------------------------
  # Timer
  # ----------------------------------------------------------------------------

  defp schedule_refresh(interval) do
    Process.send_after(self(), :refresh, interval)
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Force refresh the cluster data.
  """
  @spec refresh(map()) :: {:ok, map()}
  def refresh(state) do
    {:ok, do_refresh(state)}
  end

  defp do_refresh(state) do
    nodes = fetch_nodes(state)
    global_names = if state.show_global_names, do: fetch_global_names(), else: []
    pg_groups = if state.show_pg_groups, do: fetch_pg_groups(), else: []
    known = MapSet.new(Enum.map(nodes, & &1.node))

    %{
      state
      | nodes: nodes,
        global_names: global_names,
        pg_groups: pg_groups,
        known_nodes: known
    }
  end

  @doc """
  Set the update interval.
  """
  @spec set_interval(map(), non_neg_integer()) :: {:ok, map()}
  def set_interval(state, interval) when interval > 0 do
    if state.timer_ref do
      Process.cancel_timer(state.timer_ref)
    end

    timer_ref = schedule_refresh(interval)
    {:ok, %{state | update_interval: interval, timer_ref: timer_ref}}
  end

  @doc """
  Get currently selected node.
  """
  @spec get_selected_node(map()) :: node_info() | nil
  def get_selected_node(state) when state.view_mode == :nodes do
    Enum.at(state.nodes, state.selected_idx)
  end

  def get_selected_node(_state), do: nil

  @doc """
  Get node count.
  """
  @spec node_count(map()) :: non_neg_integer()
  def node_count(state), do: length(state.nodes)

  @doc """
  Check if cluster is distributed.
  """
  @spec distributed?(map()) :: boolean()
  def distributed?(state), do: length(state.nodes) > 1

  @doc """
  Perform RPC call to a node with timeout.
  """
  @spec rpc_call(node(), module(), atom(), list()) :: term() | {:error, term()}
  def rpc_call(node, module, function, args) do
    case :rpc.call(node, module, function, args, @rpc_timeout) do
      {:badrpc, reason} -> {:error, reason}
      result -> result
    end
  rescue
    e -> {:error, e}
  catch
    _, e -> {:error, e}
  end

  # ----------------------------------------------------------------------------
  # Rendering
  # ----------------------------------------------------------------------------

  @impl true
  def render(state, area) do
    # Update viewport dimensions
    detail_height = if state.show_details, do: 8, else: 0

    state = %{
      state
      | viewport_height: area.height - 5 - detail_height,
        viewport_width: area.width
    }

    # Build render tree
    alert = render_alert(state)
    header = render_header(state)
    content = render_content(state)
    details = if state.show_details, do: render_details(state), else: []
    footer = render_footer(state)

    all = alert ++ [header] ++ content ++ details ++ footer

    stack(:vertical, all)
  end

  defp render_alert(state) do
    if state.partition_alert do
      [text(state.partition_alert, Style.new(bg: :red, fg: :white, attrs: [:bold]))]
    else
      []
    end
  end

  defp render_header(state) do
    connected_count = length(Node.list())
    local = node()

    mode_label =
      case state.view_mode do
        :nodes -> "Nodes"
        :globals -> "Global Names"
        :pg_groups -> "PG Groups"
        :events -> "Events"
      end

    dist_status = if node() == :nonode@nohost, do: " (not distributed)", else: ""

    header_text =
      "Cluster: #{local}#{dist_status} | Connected: #{connected_count} | View: #{mode_label}"

    text(header_text, Style.new(fg: :cyan, attrs: [:bold]))
  end

  defp render_content(state) do
    case state.view_mode do
      :nodes -> render_nodes_view(state)
      :globals -> render_globals_view(state)
      :pg_groups -> render_pg_groups_view(state)
      :events -> render_events_view(state)
    end
  end

  defp render_nodes_view(state) do
    # Header row
    header_line =
      String.pad_trailing("Node", 30) <>
        String.pad_trailing("Status", 12) <>
        String.pad_leading("Processes", 12) <>
        String.pad_leading("Memory", 12)

    header = text(header_line, Style.new(attrs: [:bold, :underline]))

    # Node rows
    visible_nodes =
      state.nodes
      |> Enum.drop(state.scroll_offset)
      |> Enum.take(state.viewport_height)

    rows =
      visible_nodes
      |> Enum.with_index()
      |> Enum.map(fn {node_info, idx} ->
        actual_idx = idx + state.scroll_offset
        render_node_row(node_info, actual_idx, state)
      end)

    # Padding
    padding_count = max(0, state.viewport_height - length(rows))
    padding = List.duplicate(text("", nil), padding_count)

    [header | rows ++ padding]
  end

  defp render_node_row(node_info, idx, state) do
    is_selected = idx == state.selected_idx

    # Format fields
    node_name = truncate(to_string(node_info.node), 29)
    node_str = String.pad_trailing(node_name, 30)

    status_str =
      case node_info.status do
        :local -> String.pad_trailing("[local]", 12)
        :connected -> String.pad_trailing("connected", 12)
        :disconnected -> String.pad_trailing("DOWN", 12)
      end

    {proc_str, mem_str} =
      if node_info.metrics do
        proc = String.pad_leading(Integer.to_string(node_info.metrics.process_count), 12)
        mem = String.pad_leading(format_bytes(node_info.metrics.memory[:total] || 0), 12)
        {proc, mem}
      else
        {String.pad_leading("-", 12), String.pad_leading("-", 12)}
      end

    line = node_str <> status_str <> proc_str <> mem_str

    # Determine style
    style =
      cond do
        is_selected ->
          Style.new(bg: :blue, fg: :white)

        node_info.status == :local ->
          Style.new(fg: :green)

        node_info.status == :disconnected ->
          Style.new(fg: :red)

        true ->
          nil
      end

    text(line, style)
  end

  defp render_globals_view(state) do
    header_line =
      String.pad_trailing("Name", 30) <>
        String.pad_trailing("Node", 25) <>
        String.pad_trailing("PID", 20)

    header = text(header_line, Style.new(attrs: [:bold, :underline]))

    if Enum.empty?(state.global_names) do
      [header, text("  (no global names registered)", Style.new(fg: :yellow))]
    else
      visible =
        state.global_names
        |> Enum.drop(state.scroll_offset)
        |> Enum.take(state.viewport_height)

      rows =
        visible
        |> Enum.with_index()
        |> Enum.map(fn {item, idx} ->
          actual_idx = idx + state.scroll_offset
          is_selected = actual_idx == state.selected_idx

          name_str = String.pad_trailing(truncate(inspect(item.name), 29), 30)
          node_str = String.pad_trailing(truncate(to_string(item.node), 24), 25)
          pid_str = String.pad_trailing(inspect(item.pid), 20)

          line = name_str <> node_str <> pid_str

          style = if is_selected, do: Style.new(bg: :blue, fg: :white), else: nil
          text(line, style)
        end)

      [header | rows]
    end
  end

  defp render_pg_groups_view(state) do
    header_line =
      String.pad_trailing("Group", 30) <>
        String.pad_leading("Members", 10) <>
        String.pad_trailing("  Nodes", 35)

    header = text(header_line, Style.new(attrs: [:bold, :underline]))

    if Enum.empty?(state.pg_groups) do
      [header, text("  (no :pg groups - is :pg started?)", Style.new(fg: :yellow))]
    else
      visible =
        state.pg_groups
        |> Enum.drop(state.scroll_offset)
        |> Enum.take(state.viewport_height)

      rows =
        visible
        |> Enum.with_index()
        |> Enum.map(fn {item, idx} ->
          actual_idx = idx + state.scroll_offset
          is_selected = actual_idx == state.selected_idx

          group_str = String.pad_trailing(truncate(inspect(item.group), 29), 30)
          count_str = String.pad_leading(Integer.to_string(item.member_count), 10)
          nodes_str = Enum.map_join(item.nodes, ", ", &to_string/1)
          nodes_str = "  " <> truncate(nodes_str, 33)

          line = group_str <> count_str <> nodes_str

          style = if is_selected, do: Style.new(bg: :blue, fg: :white), else: nil
          text(line, style)
        end)

      [header | rows]
    end
  end

  defp render_events_view(state) do
    header_line =
      String.pad_trailing("Time", 12) <>
        String.pad_trailing("Event", 12) <>
        String.pad_trailing("Node", 40)

    header = text(header_line, Style.new(attrs: [:bold, :underline]))

    if Enum.empty?(state.events) do
      [header, text("  (no events yet)", Style.new(fg: :yellow))]
    else
      visible =
        state.events
        |> Enum.drop(state.scroll_offset)
        |> Enum.take(state.viewport_height)

      rows =
        visible
        |> Enum.with_index()
        |> Enum.map(fn {event, idx} ->
          actual_idx = idx + state.scroll_offset
          is_selected = actual_idx == state.selected_idx

          time_str = format_time(event.timestamp)
          time_str = String.pad_trailing(time_str, 12)

          event_str =
            case event.event do
              :nodeup -> String.pad_trailing("UP", 12)
              :nodedown -> String.pad_trailing("DOWN", 12)
            end

          node_str = String.pad_trailing(truncate(to_string(event.node), 39), 40)

          line = time_str <> event_str <> node_str

          style =
            cond do
              is_selected -> Style.new(bg: :blue, fg: :white)
              event.event == :nodedown -> Style.new(fg: :red)
              event.event == :nodeup -> Style.new(fg: :green)
              true -> nil
            end

          text(line, style)
        end)

      [header | rows]
    end
  end

  defp render_details(state) do
    border = text(String.duplicate("-", 60), Style.new(fg: :blue))

    case state.view_mode do
      :nodes -> render_node_details(state, border)
      :globals -> render_global_details(state, border)
      :pg_groups -> render_pg_group_details(state, border)
      :events -> render_event_details(state, border)
    end
  end

  defp render_node_details(state, border) do
    node_info = Enum.at(state.nodes, state.selected_idx)

    if node_info && node_info.metrics do
      metrics = node_info.metrics

      uptime_str =
        if metrics.uptime do
          format_duration(metrics.uptime)
        else
          "-"
        end

      otp_str = metrics.otp_release || "-"

      [
        border,
        text("Node: #{node_info.node}", Style.new(attrs: [:bold])),
        text("Status: #{node_info.status}", nil),
        text("Processes: #{metrics.process_count}", nil),
        text("Schedulers: #{metrics.scheduler_count}", nil),
        text("Memory (total): #{format_bytes(metrics.memory[:total] || 0)}", nil),
        text("Memory (processes): #{format_bytes(metrics.memory[:processes] || 0)}", nil),
        text("Uptime: #{uptime_str} | OTP: #{otp_str}", nil),
        border
      ]
    else
      [
        border,
        text("No details available", Style.new(fg: :yellow)),
        text("", nil),
        text("", nil),
        text("", nil),
        text("", nil),
        text("", nil),
        text("", nil),
        border
      ]
    end
  end

  defp render_global_details(state, border) do
    item = Enum.at(state.global_names, state.selected_idx)

    if item do
      [
        border,
        text("Global Name: #{inspect(item.name)}", Style.new(attrs: [:bold])),
        text("PID: #{inspect(item.pid)}", nil),
        text("Node: #{item.node}", nil),
        text("", nil),
        text("", nil),
        text("", nil),
        text("", nil),
        border
      ]
    else
      render_empty_details(border)
    end
  end

  defp render_pg_group_details(state, border) do
    item = Enum.at(state.pg_groups, state.selected_idx)

    if item do
      nodes_str = Enum.map_join(item.nodes, ", ", &to_string/1)

      [
        border,
        text("Group: #{inspect(item.group)}", Style.new(attrs: [:bold])),
        text("Member count: #{item.member_count}", nil),
        text("Nodes: #{nodes_str}", nil),
        text("", nil),
        text("", nil),
        text("", nil),
        text("", nil),
        border
      ]
    else
      render_empty_details(border)
    end
  end

  defp render_event_details(state, border) do
    event = Enum.at(state.events, state.selected_idx)

    if event do
      [
        border,
        text("Event: #{event.event}", Style.new(attrs: [:bold])),
        text("Node: #{event.node}", nil),
        text("Time: #{DateTime.to_string(event.timestamp)}", nil),
        text("", nil),
        text("", nil),
        text("", nil),
        text("", nil),
        border
      ]
    else
      render_empty_details(border)
    end
  end

  defp render_empty_details(border) do
    [
      border,
      text("No item selected", Style.new(fg: :yellow)),
      text("", nil),
      text("", nil),
      text("", nil),
      text("", nil),
      text("", nil),
      text("", nil),
      border
    ]
  end

  defp render_footer(_state) do
    help_text =
      "[↑↓] Select [Enter] Details [n] Nodes [g] Globals [p] PG [e] Events [r] Refresh"

    [text(help_text, Style.new(fg: :white, attrs: [:dim]))]
  end

  # ----------------------------------------------------------------------------
  # Formatting Helpers
  # ----------------------------------------------------------------------------

  defp truncate(str, max_len) do
    if String.length(str) > max_len do
      String.slice(str, 0, max_len - 1) <> "…"
    else
      str
    end
  end

  defp format_bytes(b) when b >= 1024 * 1024 * 1024 do
    "#{Float.round(b / (1024 * 1024 * 1024), 1)}GB"
  end

  defp format_bytes(b) when b >= 1024 * 1024 do
    "#{Float.round(b / (1024 * 1024), 1)}MB"
  end

  defp format_bytes(b) when b >= 1024 do
    "#{Float.round(b / 1024, 1)}KB"
  end

  defp format_bytes(b), do: "#{b}B"

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S")
  end

  defp format_duration(seconds) when seconds >= 86_400 do
    days = div(seconds, 86_400)
    hours = div(rem(seconds, 86_400), 3600)
    "#{days}d #{hours}h"
  end

  defp format_duration(seconds) when seconds >= 3600 do
    hours = div(seconds, 3600)
    mins = div(rem(seconds, 3600), 60)
    "#{hours}h #{mins}m"
  end

  defp format_duration(seconds) when seconds >= 60 do
    mins = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{mins}m #{secs}s"
  end

  defp format_duration(seconds), do: "#{seconds}s"
end
