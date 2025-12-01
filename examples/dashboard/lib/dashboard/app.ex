defmodule Dashboard.App do
  @moduledoc """
  Main dashboard application component.

  Displays system metrics including CPU, memory, network, and processes
  in a terminal-based dashboard layout.
  """

  use TermUI.Elm

  alias Dashboard.Data.Metrics
  alias TermUI.Event
  alias TermUI.Layout.Constraint
  alias TermUI.Renderer.Style
  alias TermUI.Widgets.Gauge
  alias TermUI.Widgets.Sparkline
  alias TermUI.Widgets.Table.Column

  # Elm callbacks

  def init(_opts) do
    %{
      theme: :dark,
      selected_process: 0
    }
  end

  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"], do: {:msg, :quit}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["r", "R"], do: {:msg, :refresh}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["t", "T"], do: {:msg, :toggle_theme}
  def event_to_msg(%Event.Key{key: :down}, _state), do: {:msg, :select_next}
  def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :select_prev}
  def event_to_msg(_, _state), do: :ignore

  def update(:quit, state) do
    # Return :quit command to trigger runtime shutdown
    {state, [:quit]}
  end

  def update(:refresh, state) do
    # Manual refresh just triggers a re-render
    {state, []}
  end

  def update(:toggle_theme, state) do
    new_theme = if state.theme == :dark, do: :light, else: :dark
    {%{state | theme: new_theme}, []}
  end

  def update(:select_next, state) do
    metrics = Metrics.get_metrics()
    process_count = length(metrics.processes)
    new_selected = min(state.selected_process + 1, max(0, process_count - 1))
    {%{state | selected_process: new_selected}, []}
  end

  def update(:select_prev, state) do
    new_selected = max(state.selected_process - 1, 0)
    {%{state | selected_process: new_selected}, []}
  end

  def update(_msg, state), do: {state, []}

  def view(state) do
    theme = get_theme(state.theme)
    # Fetch fresh metrics on each render
    metrics = Metrics.get_metrics()
    render_dashboard(state, metrics, theme)
  end

  # Render helpers

  defp render_dashboard(state, metrics, theme) do

    # Build dashboard as vertical stack
    stack(:vertical, [
      # Header
      render_header(theme),

      # Top row with gauges and system info
      stack(:horizontal, [
        render_cpu_gauge(metrics.cpu, theme),
        render_memory_gauge(metrics.memory, theme),
        render_system_info(theme)
      ]),

      # Network section
      render_network(metrics, theme),

      # Process table
      render_processes(metrics.processes, state.selected_process, theme),

      # Help bar
      render_help(theme)
    ])
  end

  @dashboard_width 58

  defp render_header(theme) do
    title = " System Dashboard "
    title_len = String.length(title)
    total_padding = @dashboard_width - title_len
    left_padding = div(total_padding, 2)
    right_padding = total_padding - left_padding

    line = String.duplicate("═", left_padding) <> title <> String.duplicate("═", right_padding)
    text(line, theme.header)
  end

  defp render_cpu_gauge(cpu_value, theme) do
    gauge_width = 12
    inner_width = gauge_width + 2

    top_border = "┌─ CPU " <> String.duplicate("─", inner_width - 7) <> "─┐"
    bottom_border = "└" <> String.duplicate("─", inner_width) <> "┘"

    stack(:vertical, [
      text(top_border, theme.border),
      stack(:horizontal, [
        text("│ ", theme.border),
        Gauge.render(
          value: cpu_value,
          min: 0,
          max: 100,
          width: gauge_width,
          show_value: false,
          show_range: false,
          zones: [
            {0, Style.new(fg: :green)},
            {60, Style.new(fg: :yellow)},
            {80, Style.new(fg: :red)}
          ]
        ),
        text(" │", theme.border)
      ]),
      text("│" <> String.pad_trailing(format_percent(cpu_value), inner_width) <> "│", theme.text),
      text(bottom_border, theme.border)
    ])
  end

  defp render_memory_gauge(memory_value, theme) do
    gauge_width = 12
    inner_width = gauge_width + 2

    top_border = "┌─ Memory " <> String.duplicate("─", inner_width - 10) <> "─┐"
    bottom_border = "└" <> String.duplicate("─", inner_width) <> "┘"

    stack(:vertical, [
      text(top_border, theme.border),
      stack(:horizontal, [
        text("│ ", theme.border),
        Gauge.render(
          value: memory_value,
          min: 0,
          max: 100,
          width: gauge_width,
          show_value: false,
          show_range: false,
          zones: [
            {0, Style.new(fg: :green)},
            {70, Style.new(fg: :yellow)},
            {85, Style.new(fg: :red)}
          ]
        ),
        text(" │", theme.border)
      ]),
      text("│" <> String.pad_trailing(format_percent(memory_value), inner_width) <> "│", theme.text),
      text(bottom_border, theme.border)
    ])
  end

  defp render_system_info(theme) do
    info = Metrics.get_system_info()
    {load1, load2, load3} = info.load_avg

    # Calculate content to determine box width
    host_line = " Host: #{info.hostname}"
    up_line = " Up: #{info.uptime}"
    load_line = " Load: #{load1} #{load2} #{load3}"

    # Find the widest content line and add padding
    content_width = Enum.max([String.length(host_line), String.length(up_line), String.length(load_line)]) + 1

    # Box width includes the border characters
    box_width = content_width + 2

    # Build the box
    title = "─ System Info ─"
    top_padding = box_width - String.length(title) - 2
    top_border = "┌" <> title <> String.duplicate("─", top_padding) <> "┐"
    bottom_border = "└" <> String.duplicate("─", box_width - 2) <> "┘"

    stack(:vertical, [
      text(top_border, theme.border),
      text(String.pad_trailing(host_line, content_width), theme.text),
      text(String.pad_trailing(up_line, content_width), theme.text),
      text(String.pad_trailing(load_line, content_width), theme.text),
      text(bottom_border, theme.border)
    ])
  end

  defp render_network(metrics, theme) do
    # Match process table width
    label_width = 6  # " RX: " or " TX: "
    sparkline_width = @dashboard_width - label_width - 4  # 4 for borders and padding

    top_border = "┌─ Network " <> String.duplicate("─", @dashboard_width - 12) <> "┐"
    bottom_border = "└" <> String.duplicate("─", @dashboard_width - 2) <> "┘"

    stack(:vertical, [
      text(top_border, theme.border),
      stack(:horizontal, [
        text(" RX: ", theme.label),
        Sparkline.render(
          values: Enum.reverse(metrics.network_rx),
          min: 0,
          max: 100,
          width: sparkline_width,
          style: theme.sparkline_rx
        ),
        text(" ", nil)
      ]),
      stack(:horizontal, [
        text(" TX: ", theme.label),
        Sparkline.render(
          values: Enum.reverse(metrics.network_tx),
          min: 0,
          max: 100,
          width: sparkline_width,
          style: theme.sparkline_tx
        ),
        text(" ", nil)
      ]),
      text(bottom_border, theme.border)
    ])
  end

  defp render_processes(processes, selected, theme) do
    # Define columns using the Table.Column helpers
    columns = [
      Column.new(:pid, "PID", width: Constraint.length(7)),
      Column.new(:name, "Name", width: Constraint.length(20)),
      Column.new(:cpu, "CPU%", width: Constraint.length(8), align: :right, render: &format_cpu/1),
      Column.new(:memory, "Memory", width: Constraint.length(12), align: :right, render: &format_memory/1)
    ]

    # Render header using Column alignment
    header_text =
      Enum.map_join(columns, "  ", fn col ->
        Column.align_text(col.header, get_column_width(col), col.align)
      end)

    header = "  " <> header_text

    # Build separator based on column widths
    separator =
      "  " <>
        Enum.map_join(columns, "  ", fn col ->
          String.duplicate("─", get_column_width(col))
        end)

    # Render rows using Column.render_cell
    rows =
      processes
      |> Enum.with_index()
      |> Enum.map(fn {proc, idx} ->
        row_text =
          "  " <>
            Enum.map_join(columns, "  ", fn col ->
              cell_value = Column.render_cell(col, proc)
              Column.align_text(cell_value, get_column_width(col), col.align)
            end)

        if idx == selected do
          text(row_text, theme.table_selected)
        else
          text(row_text, theme.table_row)
        end
      end)

    stack(:vertical, [
      text("┌─ Processes ────────────────────────────────────────────┐", theme.border),
      text(header, theme.table_header),
      text(separator, theme.border)
      | rows
    ] ++ [text("└────────────────────────────────────────────────────────┘", theme.border)])
  end

  # Helper to extract column width from constraint
  defp get_column_width(%Column{width: %Constraint.Length{value: v}}), do: v
  defp get_column_width(_), do: 10

  defp render_help(theme) do
    controls = " [Q] Quit  [R] Refresh  [T] Theme  [↑/↓] Navigate"
    inner_width = @dashboard_width - 2

    top_border = "┌─ Controls " <> String.duplicate("─", inner_width - 12) <> "─┐"
    bottom_border = "└" <> String.duplicate("─", inner_width) <> "┘"

    stack(:vertical, [
      text("", nil),
      text(top_border, theme.border),
      text("│" <> String.pad_trailing(controls, inner_width) <> "│", theme.help),
      text(bottom_border, theme.border)
    ])
  end

  # Formatting helpers

  defp format_percent(value) do
    value
    |> Float.round(1)
    |> to_string()
    |> String.pad_leading(5)
    |> Kernel.<>("%")
  end

  defp format_cpu(value) do
    "#{Float.round(value, 1)}%"
  end

  defp format_memory(mb) do
    if mb >= 1024 do
      "#{Float.round(mb / 1024, 1)} GB"
    else
      "#{mb} MB"
    end
  end

  # Themes

  defp get_theme(:dark) do
    %{
      header: Style.new(fg: :cyan, attrs: [:bold]),
      border: Style.new(fg: :cyan),
      text: Style.new(fg: :white),
      label: Style.new(fg: :bright_black),
      help: Style.new(fg: :bright_black),
      sparkline_rx: Style.new(fg: :green),
      sparkline_tx: Style.new(fg: :blue),
      table_header: Style.new(fg: :cyan, attrs: [:bold]),
      table_row: Style.new(fg: :white),
      table_selected: Style.new(fg: :black, bg: :cyan)
    }
  end

  defp get_theme(:light) do
    %{
      header: Style.new(fg: :yellow, attrs: [:bold]),
      border: Style.new(fg: :yellow),
      text: Style.new(fg: :bright_white),
      label: Style.new(fg: :bright_black),
      help: Style.new(fg: :bright_black),
      sparkline_rx: Style.new(fg: :bright_green),
      sparkline_tx: Style.new(fg: :bright_cyan),
      table_header: Style.new(fg: :yellow, attrs: [:bold]),
      table_row: Style.new(fg: :bright_white),
      table_selected: Style.new(fg: :black, bg: :yellow)
    }
  end
end
