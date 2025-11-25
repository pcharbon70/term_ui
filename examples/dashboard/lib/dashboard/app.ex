defmodule Dashboard.App do
  @moduledoc """
  Main dashboard application component.

  Displays system metrics including CPU, memory, network, and processes
  in a terminal-based dashboard layout.
  """

  use TermUI.Elm

  alias Dashboard.Data.Metrics
  alias TermUI.Event
  alias TermUI.Renderer.Style
  alias TermUI.Widgets.{Gauge, Sparkline}

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

  defp render_header(theme) do
    text("═══ System Dashboard ═══", theme.header)
  end

  defp render_cpu_gauge(cpu_value, theme) do
    stack(:vertical, [
      text("┌─ CPU ─┐", theme.border),
      text(" #{format_percent(cpu_value)} ", theme.text),
      Gauge.render(
        value: cpu_value,
        width: 12,
        zones: cpu_zones(),
        show_value: false,
        show_range: false
      ),
      text("└───────┘", theme.border)
    ])
  end

  defp render_memory_gauge(memory_value, theme) do
    stack(:vertical, [
      text("┌─ Memory ─┐", theme.border),
      text(" #{format_percent(memory_value)} ", theme.text),
      Gauge.render(
        value: memory_value,
        width: 12,
        zones: memory_zones(),
        show_value: false,
        show_range: false
      ),
      text("└──────────┘", theme.border)
    ])
  end

  defp render_system_info(theme) do
    info = Metrics.get_system_info()
    {load1, load2, load3} = info.load_avg

    stack(:vertical, [
      text("┌─ System Info ─┐", theme.border),
      text(" Host: #{info.hostname}", theme.text),
      text(" Up: #{info.uptime}", theme.text),
      text(" Load: #{load1} #{load2} #{load3}", theme.text),
      text("└───────────────┘", theme.border)
    ])
  end

  defp render_network(metrics, theme) do
    stack(:vertical, [
      text("┌─ Network ─┐", theme.border),
      stack(:horizontal, [
        text(" RX: ", theme.label),
        Sparkline.render(
          values: Enum.reverse(metrics.network_rx),
          min: 0,
          max: 100,
          style: theme.sparkline_rx
        )
      ]),
      stack(:horizontal, [
        text(" TX: ", theme.label),
        Sparkline.render(
          values: Enum.reverse(metrics.network_tx),
          min: 0,
          max: 100,
          style: theme.sparkline_tx
        )
      ]),
      text("└───────────┘", theme.border)
    ])
  end

  defp render_processes(processes, selected, theme) do
    header = "  PID      Name                  CPU%      Memory"
    separator = "  ───────  ────────────────────  ────────  ────────────"

    rows =
      processes
      |> Enum.with_index()
      |> Enum.map(fn {proc, idx} ->
        row_text =
          "  #{String.pad_trailing(to_string(proc.pid), 7)} " <>
            "#{String.pad_trailing(proc.name, 20)} " <>
            "#{String.pad_leading(format_cpu(proc.cpu), 8)} " <>
            "#{String.pad_leading(format_memory(proc.memory), 12)}"

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

  defp render_help(theme) do
    text("[Q] Quit  [R] Refresh  [T] Theme  [↑/↓] Navigate", theme.help)
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
    cond do
      mb >= 1024 -> "#{Float.round(mb / 1024, 1)} GB"
      true -> "#{mb} MB"
    end
  end

  # Color zones

  defp cpu_zones do
    [
      {0, Style.new(fg: :green)},
      {60, Style.new(fg: :yellow)},
      {80, Style.new(fg: :red)}
    ]
  end

  defp memory_zones do
    [
      {0, Style.new(fg: :green)},
      {70, Style.new(fg: :yellow)},
      {85, Style.new(fg: :red)}
    ]
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
