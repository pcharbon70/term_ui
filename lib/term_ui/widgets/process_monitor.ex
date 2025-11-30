defmodule TermUI.Widgets.ProcessMonitor do
  @moduledoc """
  ProcessMonitor widget for live BEAM process inspection.

  ProcessMonitor displays live process information including PID, name,
  reductions, memory, and message queue depth. It provides controls for
  process management and debugging.

  ## Usage

      ProcessMonitor.new(
        update_interval: 1000,
        show_system_processes: false
      )

  ## Features

  - Live process list with PID, name, reductions, memory
  - Configurable update interval
  - Message queue depth display with warnings
  - Process links/monitors visualization
  - Stack trace display
  - Process actions (kill, suspend, resume)
  - Sorting by any field
  - Filtering by name/module

  ## Keyboard Controls

  - Up/Down: Move selection
  - PageUp/PageDown: Scroll by page
  - Enter: Toggle details panel
  - r: Refresh now
  - s: Cycle sort field
  - S: Toggle sort direction
  - /: Start filter input
  - k: Kill selected process (with confirmation)
  - p: Pause/resume selected process
  - l: Show links/monitors
  - t: Show stack trace
  - Escape: Clear filter/close details
  """

  use TermUI.StatefulComponent

  alias TermUI.Event

  @type sort_field :: :pid | :name | :reductions | :memory | :queue | :status
  @type sort_direction :: :asc | :desc

  @type process_info :: %{
          pid: pid(),
          registered_name: atom() | nil,
          initial_call: {module(), atom(), arity()} | nil,
          current_function: {module(), atom(), arity()} | nil,
          reductions: non_neg_integer(),
          memory: non_neg_integer(),
          message_queue_len: non_neg_integer(),
          status: atom(),
          links: [pid()],
          monitors: [term()],
          monitored_by: [pid()],
          stack_trace: [term()] | nil
        }

  @type thresholds :: %{
          queue_warning: non_neg_integer(),
          queue_critical: non_neg_integer(),
          memory_warning: non_neg_integer(),
          memory_critical: non_neg_integer()
        }

  @default_interval 1000
  @page_size 20

  @default_thresholds %{
    queue_warning: 1000,
    queue_critical: 10_000,
    memory_warning: 50 * 1024 * 1024,
    memory_critical: 200 * 1024 * 1024
  }

  @sort_fields [:pid, :name, :reductions, :memory, :queue, :status]

  # System process patterns to optionally hide
  @system_patterns [
    ~r/^:application_controller$/,
    ~r/^:kernel_sup$/,
    ~r/^:code_server$/,
    ~r/^:file_server/,
    ~r/^:init$/,
    ~r/^:logger/,
    ~r/^:erl_prim_loader$/
  ]

  # ----------------------------------------------------------------------------
  # Props
  # ----------------------------------------------------------------------------

  @doc """
  Creates new ProcessMonitor widget props.

  ## Options

  - `:update_interval` - Refresh interval in ms (default: 1000)
  - `:show_system_processes` - Include system processes (default: false)
  - `:thresholds` - Warning thresholds map
  - `:on_select` - Callback when process is selected
  - `:on_action` - Callback when action is performed
  """
  @spec new(keyword()) :: map()
  def new(opts) do
    %{
      update_interval: Keyword.get(opts, :update_interval, @default_interval),
      show_system_processes: Keyword.get(opts, :show_system_processes, false),
      thresholds: Keyword.get(opts, :thresholds, @default_thresholds),
      on_select: Keyword.get(opts, :on_select),
      on_action: Keyword.get(opts, :on_action)
    }
  end

  # ----------------------------------------------------------------------------
  # StatefulComponent Callbacks
  # ----------------------------------------------------------------------------

  @impl true
  def init(props) do
    state = %{
      # Process data
      processes: [],
      selected_idx: 0,
      scroll_offset: 0,

      # Sorting
      sort_field: :reductions,
      sort_direction: :desc,

      # Filtering
      filter: nil,
      filter_input: nil,

      # Display modes
      show_details: false,
      detail_mode: :info,

      # Confirmation
      pending_action: nil,

      # Settings
      update_interval: props.update_interval,
      show_system_processes: props.show_system_processes,
      thresholds: props.thresholds,
      timer_ref: nil,

      # Callbacks
      on_select: props.on_select,
      on_action: props.on_action,

      # Viewport
      viewport_height: 20,
      viewport_width: 80,
      last_area: nil
    }

    # Fetch initial process list
    processes = fetch_processes(state)
    state = %{state | processes: processes}

    {:ok, state}
  end

  @impl true
  def mount(state) do
    # Start refresh timer
    timer_ref = schedule_refresh(state.update_interval)
    {:ok, %{state | timer_ref: timer_ref}}
  end

  @impl true
  def unmount(state) do
    if state.timer_ref do
      Process.cancel_timer(state.timer_ref)
    end

    :ok
  end

  # ----------------------------------------------------------------------------
  # Event Handling
  # ----------------------------------------------------------------------------

  @impl true
  def handle_event(%Event.Key{key: :up}, state) when state.filter_input == nil do
    move_selection(state, -1)
  end

  def handle_event(%Event.Key{key: :down}, state) when state.filter_input == nil do
    move_selection(state, 1)
  end

  def handle_event(%Event.Key{key: :page_up}, state) when state.filter_input == nil do
    move_selection(state, -@page_size)
  end

  def handle_event(%Event.Key{key: :page_down}, state) when state.filter_input == nil do
    move_selection(state, @page_size)
  end

  def handle_event(%Event.Key{key: :home}, state) when state.filter_input == nil do
    {:ok, %{state | selected_idx: 0, scroll_offset: 0}}
  end

  def handle_event(%Event.Key{key: :end}, state) when state.filter_input == nil do
    last = max(0, length(state.processes) - 1)
    scroll = max(0, length(state.processes) - state.viewport_height)
    {:ok, %{state | selected_idx: last, scroll_offset: scroll}}
  end

  # Enter - toggle details
  def handle_event(%Event.Key{key: :enter}, state)
      when state.filter_input == nil and state.pending_action == nil do
    {:ok, %{state | show_details: not state.show_details, detail_mode: :info}}
  end

  # r - refresh
  def handle_event(%Event.Key{char: "r"}, state) when state.filter_input == nil do
    refresh(state)
  end

  # s - cycle sort field
  def handle_event(%Event.Key{char: "s"}, state) when state.filter_input == nil do
    current_idx = Enum.find_index(@sort_fields, &(&1 == state.sort_field))
    next_idx = rem(current_idx + 1, length(@sort_fields))
    next_field = Enum.at(@sort_fields, next_idx)
    processes = sort_processes(state.processes, next_field, state.sort_direction)
    {:ok, %{state | sort_field: next_field, processes: processes}}
  end

  # S - toggle sort direction
  def handle_event(%Event.Key{char: "S"}, state) when state.filter_input == nil do
    new_dir = if state.sort_direction == :asc, do: :desc, else: :asc
    processes = sort_processes(state.processes, state.sort_field, new_dir)
    {:ok, %{state | sort_direction: new_dir, processes: processes}}
  end

  # / - start filter
  def handle_event(%Event.Key{char: "/"}, state) when state.filter_input == nil do
    {:ok, %{state | filter_input: ""}}
  end

  # k - kill process
  def handle_event(%Event.Key{char: "k"}, state)
      when state.filter_input == nil and state.pending_action == nil do
    if length(state.processes) > 0 do
      {:ok, %{state | pending_action: :kill}}
    else
      {:ok, state}
    end
  end

  # p - pause/suspend process
  def handle_event(%Event.Key{char: "p"}, state)
      when state.filter_input == nil and state.pending_action == nil do
    if length(state.processes) > 0 do
      process = Enum.at(state.processes, state.selected_idx)

      if process do
        if process.status == :suspended do
          resume_process(state, process.pid)
        else
          {:ok, %{state | pending_action: :suspend}}
        end
      else
        {:ok, state}
      end
    else
      {:ok, state}
    end
  end

  # l - show links
  def handle_event(%Event.Key{char: "l"}, state) when state.filter_input == nil do
    {:ok, %{state | show_details: true, detail_mode: :links}}
  end

  # t - show stack trace
  def handle_event(%Event.Key{char: "t"}, state) when state.filter_input == nil do
    {:ok, %{state | show_details: true, detail_mode: :trace}}
  end

  # Escape - clear filter or close details
  def handle_event(%Event.Key{key: :escape}, state) do
    cond do
      state.pending_action != nil ->
        {:ok, %{state | pending_action: nil}}

      state.filter_input != nil ->
        {:ok, %{state | filter_input: nil}}

      state.show_details ->
        {:ok, %{state | show_details: false}}

      state.filter != nil ->
        processes = fetch_processes(%{state | filter: nil})
        {:ok, %{state | filter: nil, processes: processes, selected_idx: 0, scroll_offset: 0}}

      true ->
        {:ok, state}
    end
  end

  # Confirmation: y = yes
  def handle_event(%Event.Key{char: "y"}, state) when state.pending_action != nil do
    process = Enum.at(state.processes, state.selected_idx)

    if process do
      case state.pending_action do
        :kill -> kill_process(state, process.pid)
        :suspend -> suspend_process(state, process.pid)
        _ -> {:ok, %{state | pending_action: nil}}
      end
    else
      {:ok, %{state | pending_action: nil}}
    end
  end

  # Confirmation: n = no
  def handle_event(%Event.Key{char: "n"}, state) when state.pending_action != nil do
    {:ok, %{state | pending_action: nil}}
  end

  # Filter input mode
  def handle_event(%Event.Key{key: :enter}, state) when state.filter_input != nil do
    filter = if state.filter_input == "", do: nil, else: state.filter_input
    processes = fetch_processes(%{state | filter: filter})

    {:ok,
     %{
       state
       | filter: filter,
         filter_input: nil,
         processes: processes,
         selected_idx: 0,
         scroll_offset: 0
     }}
  end

  def handle_event(%Event.Key{key: :backspace}, state) when state.filter_input != nil do
    input = String.slice(state.filter_input, 0..-2//1)
    {:ok, %{state | filter_input: input}}
  end

  def handle_event(%Event.Key{char: char}, state)
      when state.filter_input != nil and char != nil do
    {:ok, %{state | filter_input: state.filter_input <> char}}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  # ----------------------------------------------------------------------------
  # Message Handling
  # ----------------------------------------------------------------------------

  @impl true
  def handle_info(:refresh, state) do
    processes = fetch_processes(state)
    timer_ref = schedule_refresh(state.update_interval)
    {:ok, %{state | processes: processes, timer_ref: timer_ref}}
  end

  def handle_info(_msg, state) do
    {:ok, state}
  end

  # ----------------------------------------------------------------------------
  # Process Fetching
  # ----------------------------------------------------------------------------

  defp fetch_processes(state) do
    Process.list()
    |> Enum.map(&get_process_info/1)
    |> Enum.reject(&is_nil/1)
    |> maybe_filter_system(state.show_system_processes)
    |> maybe_apply_filter(state.filter)
    |> sort_processes(state.sort_field, state.sort_direction)
  end

  defp get_process_info(pid) do
    try do
      info =
        Process.info(pid, [
          :registered_name,
          :initial_call,
          :current_function,
          :reductions,
          :memory,
          :message_queue_len,
          :status,
          :links,
          :monitors,
          :monitored_by
        ])

      if info do
        %{
          pid: pid,
          registered_name: info[:registered_name],
          initial_call: info[:initial_call],
          current_function: info[:current_function],
          reductions: info[:reductions] || 0,
          memory: info[:memory] || 0,
          message_queue_len: info[:message_queue_len] || 0,
          status: info[:status] || :unknown,
          links: info[:links] || [],
          monitors: info[:monitors] || [],
          monitored_by: info[:monitored_by] || [],
          stack_trace: nil
        }
      else
        nil
      end
    rescue
      _ -> nil
    catch
      _, _ -> nil
    end
  end

  defp maybe_filter_system(processes, true), do: processes

  defp maybe_filter_system(processes, false) do
    Enum.reject(processes, fn p ->
      name = process_name(p)
      Enum.any?(@system_patterns, &Regex.match?(&1, name))
    end)
  end

  defp maybe_apply_filter(processes, nil), do: processes

  defp maybe_apply_filter(processes, filter) do
    pattern =
      case Regex.compile(filter, [:caseless]) do
        {:ok, regex} -> regex
        _ -> nil
      end

    if pattern do
      Enum.filter(processes, fn p ->
        name = process_name(p)
        Regex.match?(pattern, name)
      end)
    else
      Enum.filter(processes, fn p ->
        name = process_name(p)
        String.contains?(String.downcase(name), String.downcase(filter))
      end)
    end
  end

  defp process_name(process) do
    cond do
      process.registered_name ->
        inspect(process.registered_name)

      process.initial_call ->
        {m, f, a} = process.initial_call
        "#{inspect(m)}.#{f}/#{a}"

      true ->
        inspect(process.pid)
    end
  end

  # ----------------------------------------------------------------------------
  # Sorting
  # ----------------------------------------------------------------------------

  defp sort_processes(processes, field, direction) do
    sorted =
      case field do
        :pid ->
          Enum.sort_by(processes, & &1.pid, fn a, b ->
            :erlang.pid_to_list(a) <= :erlang.pid_to_list(b)
          end)

        :name ->
          Enum.sort_by(processes, &process_name/1)

        :reductions ->
          Enum.sort_by(processes, & &1.reductions)

        :memory ->
          Enum.sort_by(processes, & &1.memory)

        :queue ->
          Enum.sort_by(processes, & &1.message_queue_len)

        :status ->
          Enum.sort_by(processes, & &1.status)
      end

    if direction == :desc, do: Enum.reverse(sorted), else: sorted
  end

  # ----------------------------------------------------------------------------
  # Navigation
  # ----------------------------------------------------------------------------

  defp move_selection(state, delta) do
    count = length(state.processes)

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

      # Call on_select callback
      if state.on_select && new_idx != state.selected_idx do
        process = Enum.at(state.processes, new_idx)
        if process, do: state.on_select.(process)
      end

      {:ok, new_state}
    end
  end

  # ----------------------------------------------------------------------------
  # Process Actions
  # ----------------------------------------------------------------------------

  defp kill_process(state, pid) do
    try do
      Process.exit(pid, :kill)

      if state.on_action do
        state.on_action.({:killed, pid})
      end

      # Refresh after action
      processes = fetch_processes(state)
      new_idx = min(state.selected_idx, max(0, length(processes) - 1))
      {:ok, %{state | pending_action: nil, processes: processes, selected_idx: new_idx}}
    rescue
      _ -> {:ok, %{state | pending_action: nil}}
    end
  end

  defp suspend_process(state, pid) do
    try do
      :erlang.suspend_process(pid)

      if state.on_action do
        state.on_action.({:suspended, pid})
      end

      processes = fetch_processes(state)
      {:ok, %{state | pending_action: nil, processes: processes}}
    rescue
      _ -> {:ok, %{state | pending_action: nil}}
    end
  end

  defp resume_process(state, pid) do
    try do
      :erlang.resume_process(pid)

      if state.on_action do
        state.on_action.({:resumed, pid})
      end

      processes = fetch_processes(state)
      {:ok, %{state | processes: processes}}
    rescue
      _ -> {:ok, state}
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
  Force refresh the process list.
  """
  @spec refresh(map()) :: {:ok, map()}
  def refresh(state) do
    processes = fetch_processes(state)
    {:ok, %{state | processes: processes}}
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
  Set sorting options.
  """
  @spec set_sort(map(), sort_field(), sort_direction()) :: {:ok, map()}
  def set_sort(state, field, direction)
      when field in @sort_fields and direction in [:asc, :desc] do
    processes = sort_processes(state.processes, field, direction)
    {:ok, %{state | sort_field: field, sort_direction: direction, processes: processes}}
  end

  @doc """
  Set filter pattern.
  """
  @spec set_filter(map(), String.t() | nil) :: {:ok, map()}
  def set_filter(state, filter) do
    processes = fetch_processes(%{state | filter: filter})
    {:ok, %{state | filter: filter, processes: processes, selected_idx: 0, scroll_offset: 0}}
  end

  @doc """
  Get currently selected process.
  """
  @spec get_selected(map()) :: process_info() | nil
  def get_selected(state) do
    Enum.at(state.processes, state.selected_idx)
  end

  @doc """
  Get process count.
  """
  @spec process_count(map()) :: non_neg_integer()
  def process_count(state), do: length(state.processes)

  @doc """
  Get stack trace for a process.
  """
  @spec get_stack_trace(pid()) :: [term()] | nil
  def get_stack_trace(pid) do
    try do
      case Process.info(pid, :current_stacktrace) do
        {:current_stacktrace, trace} -> trace
        _ -> nil
      end
    rescue
      _ -> nil
    catch
      _, _ -> nil
    end
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
      | viewport_height: area.height - 4 - detail_height,
        viewport_width: area.width,
        last_area: area
    }

    # Build render tree
    header = render_header(state)
    process_list = render_process_list(state)
    details = if state.show_details, do: render_details(state), else: []
    footer = render_footer(state)
    confirmation = render_confirmation(state)

    content = [header] ++ process_list ++ details ++ footer ++ confirmation

    stack(:vertical, content)
  end

  defp render_header(state) do
    sort_indicator = if state.sort_direction == :asc, do: "▲", else: "▼"
    sort_label = "#{state.sort_field}#{sort_indicator}"

    filter_label =
      if state.filter do
        " | Filter: #{state.filter}"
      else
        ""
      end

    header_text = "Processes: #{length(state.processes)} | Sort: #{sort_label}#{filter_label}"

    text(header_text, Style.new(fg: :cyan, attrs: [:bold]))
  end

  defp render_process_list(state) do
    # Column widths
    pid_w = 15
    name_w = 30
    red_w = 12
    mem_w = 10
    queue_w = 8
    status_w = 10

    # Header row
    header_line =
      String.pad_trailing("PID", pid_w) <>
        String.pad_trailing("Name", name_w) <>
        String.pad_leading("Reductions", red_w) <>
        String.pad_leading("Memory", mem_w) <>
        String.pad_leading("Queue", queue_w) <>
        String.pad_trailing("  Status", status_w)

    header = text(header_line, Style.new(attrs: [:bold, :underline]))

    # Process rows
    visible_processes =
      state.processes
      |> Enum.drop(state.scroll_offset)
      |> Enum.take(state.viewport_height)

    rows =
      visible_processes
      |> Enum.with_index()
      |> Enum.map(fn {process, idx} ->
        actual_idx = idx + state.scroll_offset

        render_process_row(
          process,
          actual_idx,
          state,
          {pid_w, name_w, red_w, mem_w, queue_w, status_w}
        )
      end)

    # Pad with empty lines
    padding_count = max(0, state.viewport_height - length(rows))
    padding = List.duplicate(text("", nil), padding_count)

    [header | rows ++ padding]
  end

  defp render_process_row(process, idx, state, {pid_w, name_w, red_w, mem_w, queue_w, status_w}) do
    is_selected = idx == state.selected_idx

    # Format fields
    pid_str = String.pad_trailing(inspect(process.pid), pid_w)
    name_str = String.pad_trailing(truncate(process_name(process), name_w - 1), name_w)
    red_str = String.pad_leading(format_number(process.reductions), red_w)
    mem_str = String.pad_leading(format_bytes(process.memory), mem_w)
    queue_str = String.pad_leading(Integer.to_string(process.message_queue_len), queue_w)
    status_str = String.pad_trailing("  #{process.status}", status_w)

    line = pid_str <> name_str <> red_str <> mem_str <> queue_str <> status_str

    # Determine style
    style =
      cond do
        is_selected ->
          Style.new(bg: :blue, fg: :white)

        process.message_queue_len >= state.thresholds.queue_critical ->
          Style.new(fg: :red, attrs: [:bold])

        process.message_queue_len >= state.thresholds.queue_warning ->
          Style.new(fg: :yellow)

        process.memory >= state.thresholds.memory_critical ->
          Style.new(fg: :red, attrs: [:bold])

        process.memory >= state.thresholds.memory_warning ->
          Style.new(fg: :yellow)

        process.status == :suspended ->
          Style.new(fg: :magenta)

        true ->
          nil
      end

    text(line, style)
  end

  defp render_details(state) do
    process = Enum.at(state.processes, state.selected_idx)

    if process do
      case state.detail_mode do
        :info -> render_info_details(process, state)
        :links -> render_links_details(process)
        :trace -> render_trace_details(process)
      end
    else
      [text("No process selected", Style.new(fg: :yellow))]
    end
  end

  defp render_info_details(process, _state) do
    border = text(String.duplicate("-", 60), Style.new(fg: :blue))

    lines = [
      border,
      text("PID: #{inspect(process.pid)}", nil),
      text("Name: #{process_name(process)}", nil),
      text("Current: #{format_mfa(process.current_function)}", nil),
      text("Initial: #{format_mfa(process.initial_call)}", nil),
      text("Status: #{process.status}", nil),
      text(
        "Links: #{length(process.links)} | Monitors: #{length(process.monitors)} | Monitored by: #{length(process.monitored_by)}",
        nil
      ),
      border
    ]

    lines
  end

  defp render_links_details(process) do
    border = text(String.duplicate("-", 60), Style.new(fg: :blue))

    links_text =
      if length(process.links) > 0 do
        process.links
        |> Enum.take(5)
        |> Enum.map_join(", ", &inspect/1)
      else
        "(none)"
      end

    monitors_text =
      if length(process.monitors) > 0 do
        process.monitors
        |> Enum.take(5)
        |> Enum.map_join(", ", &inspect/1)
      else
        "(none)"
      end

    monitored_by_text =
      if length(process.monitored_by) > 0 do
        process.monitored_by
        |> Enum.take(5)
        |> Enum.map_join(", ", &inspect/1)
      else
        "(none)"
      end

    [
      border,
      text("Links: #{links_text}", nil),
      text("Monitors: #{monitors_text}", nil),
      text("Monitored by: #{monitored_by_text}", nil),
      text("", nil),
      text("", nil),
      text("", nil),
      border
    ]
  end

  defp render_trace_details(process) do
    border = text(String.duplicate("-", 60), Style.new(fg: :blue))

    trace = get_stack_trace(process.pid)

    trace_lines =
      if trace && length(trace) > 0 do
        trace
        |> Enum.take(6)
        |> Enum.map(fn {m, f, a, loc} ->
          file = Keyword.get(loc, :file, "?")
          line = Keyword.get(loc, :line, "?")
          text("  #{m}.#{f}/#{a} (#{file}:#{line})", nil)
        end)
      else
        [text("  (no stack trace available)", Style.new(fg: :yellow))]
      end

    [border, text("Stack Trace:", Style.new(attrs: [:bold]))] ++ trace_lines ++ [border]
  end

  defp render_footer(state) do
    input_line =
      if state.filter_input != nil do
        [text("Filter: #{state.filter_input}_", Style.new(fg: :yellow))]
      else
        []
      end

    help_text =
      "[↑↓] Select [Enter] Details [s/S] Sort [/] Filter [k] Kill [p] Pause [l] Links [t] Trace [r] Refresh"

    input_line ++ [text(help_text, Style.new(fg: :white, attrs: [:dim]))]
  end

  defp render_confirmation(state) do
    if state.pending_action do
      process = Enum.at(state.processes, state.selected_idx)

      action_text =
        case state.pending_action do
          :kill -> "Kill"
          :suspend -> "Suspend"
          _ -> "Perform action on"
        end

      if process do
        [
          text("", nil),
          text(
            "#{action_text} #{inspect(process.pid)} (#{process_name(process)})? [y/n]",
            Style.new(fg: :red, attrs: [:bold])
          )
        ]
      else
        []
      end
    else
      []
    end
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

  defp format_number(n) when n >= 1_000_000_000 do
    "#{Float.round(n / 1_000_000_000, 1)}B"
  end

  defp format_number(n) when n >= 1_000_000 do
    "#{Float.round(n / 1_000_000, 1)}M"
  end

  defp format_number(n) when n >= 1_000 do
    "#{Float.round(n / 1_000, 1)}K"
  end

  defp format_number(n), do: Integer.to_string(n)

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

  defp format_mfa(nil), do: "-"
  defp format_mfa({m, f, a}), do: "#{inspect(m)}.#{f}/#{a}"
end
