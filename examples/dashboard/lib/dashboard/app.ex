defmodule Dashboard.App do
  @moduledoc """
  Main dashboard application component.

  Displays system metrics including CPU, memory, network, and processes
  in a terminal-based dashboard layout.
  """

  use TermUI.StatefulComponent

  alias Dashboard.Data.Metrics
  alias TermUI.Event.Key
  alias TermUI.Renderer.Style
  alias TermUI.Widgets.{Gauge, Sparkline}

  @refresh_interval 1000

  @impl true
  def init(_props) do
    state = %{
      metrics: nil,
      theme: :dark,
      selected_process: 0
    }

    # Start refresh timer
    commands = [{:timer, @refresh_interval, :refresh}]

    {:ok, state, commands}
  end

  @impl true
  def handle_event(%Key{key: "q"}, state) do
    {:stop, :normal, state}
  end

  def handle_event(%Key{key: "r"}, state) do
    new_state = %{state | metrics: Metrics.get_metrics()}
    {:ok, new_state}
  end

  def handle_event(%Key{key: "t"}, state) do
    new_theme = if state.theme == :dark, do: :light, else: :dark
    {:ok, %{state | theme: new_theme}}
  end

  def handle_event(%Key{key: :down}, state) do
    process_count = if state.metrics, do: length(state.metrics.processes), else: 0
    new_selected = min(state.selected_process + 1, process_count - 1)
    {:ok, %{state | selected_process: new_selected}}
  end

  def handle_event(%Key{key: :up}, state) do
    new_selected = max(state.selected_process - 1, 0)
    {:ok, %{state | selected_process: new_selected}}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  @impl true
  def handle_info(:refresh, state) do
    new_state = %{state | metrics: Metrics.get_metrics()}
    commands = [{:timer, @refresh_interval, :refresh}]
    {:ok, new_state, commands}
  end

  def handle_info(_msg, state) do
    {:ok, state}
  end

  @impl true
  def render(state, area) do
    theme = get_theme(state.theme)

    if state.metrics == nil do
      render_loading(theme)
    else
      render_dashboard(state, area, theme)
    end
  end

  defp render_loading(theme) do
    text("Loading dashboard...", theme.text)
  end

  defp render_dashboard(state, area, theme) do
    metrics = state.metrics

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
      render_processes(metrics.processes, state.selected_process, area, theme),

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

  defp render_processes(processes, selected, _area, theme) do
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
    text("[q] Quit  [r] Refresh  [t] Theme  [↑/↓] Navigate", theme.help)
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
      label: Style.new(fg: :gray),
      help: Style.new(fg: :dark_gray),
      sparkline_rx: Style.new(fg: :green),
      sparkline_tx: Style.new(fg: :blue),
      table_header: Style.new(fg: :cyan, attrs: [:bold]),
      table_row: Style.new(fg: :white),
      table_selected: Style.new(fg: :black, bg: :cyan)
    }
  end

  defp get_theme(:light) do
    %{
      header: Style.new(fg: :blue, attrs: [:bold]),
      border: Style.new(fg: :blue),
      text: Style.new(fg: :black),
      label: Style.new(fg: :dark_gray),
      help: Style.new(fg: :gray),
      sparkline_rx: Style.new(fg: :green),
      sparkline_tx: Style.new(fg: :blue),
      table_header: Style.new(fg: :blue, attrs: [:bold]),
      table_row: Style.new(fg: :black),
      table_selected: Style.new(fg: :white, bg: :blue)
    }
  end
end
