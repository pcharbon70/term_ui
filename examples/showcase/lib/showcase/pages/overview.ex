defmodule Showcase.Pages.Overview do
  @moduledoc false

  @behaviour Showcase.Page

  alias Showcase.Layout
  alias TermUI.{Frame, Style}
  alias TermUI.Widget.{BarChart, Gauge, Progress, Sparkline, Table}
  alias TermUI.Widget.Table.Column

  @impl true
  def init do
    %{
      tick: 0,
      cpu: Gauge.init(label: "CPU", value: 38),
      memory: Gauge.init(label: "Memory", value: 61),
      jobs: Progress.init(label: "Jobs", value: 42),
      history:
        Sparkline.init(
          label: "Load",
          values: [28, 35, 31, 42, 48, 44, 53, 49, 57, 52],
          min: 0,
          max: 100,
          style: Style.new(fg: :cyan)
        ),
      bars:
        BarChart.init(
          data: [
            %{label: "API", value: 74, color: :cyan},
            %{label: "Jobs", value: 51, color: :green},
            %{label: "Cache", value: 33, color: :yellow}
          ],
          min: 0,
          max: 100
        ),
      table: Table.init(columns: columns(), rows: process_rows(0), page_size: 8)
    }
  end

  @impl true
  def update(:tick, state) do
    tick = state.tick + 1
    cpu = wave(tick, 48, 31, 5)
    memory = wave(tick, 62, 17, 8)
    jobs = rem(tick * 7, 101)

    next = %{
      state
      | tick: tick,
        cpu: Gauge.set_value(state.cpu, cpu),
        memory: Gauge.set_value(state.memory, memory),
        jobs: Progress.set_value(state.jobs, jobs),
        history: Sparkline.push(state.history, cpu, 80),
        bars: %{state.bars | data: service_bars(tick)},
        table: Table.set_rows(state.table, process_rows(tick))
    }

    {next, []}
  end

  def update(event, state) do
    {table, messages} = Table.update(event, state.table)
    {%{state | table: table}, messages}
  end

  @impl true
  def view(state, {width, height} = dimensions, theme) do
    if width >= 72 and height >= 12 do
      wide_view(state, dimensions, theme)
    else
      compact_view(state, dimensions, theme)
    end
  end

  @impl true
  def help, do: "Live pure widgets. Use Up and Down to move in the process table."

  defp wide_view(state, {width, height}, theme) do
    {left_width, right_width} = Layout.split_widths(width)
    top_height = min(max(div(height, 2), 7), 9)
    table_height = max(height - top_height - 1, 2)

    metrics =
      state
      |> metrics_frame({left_width - 2, top_height - 2})
      |> Layout.panel("Live metrics", {left_width, top_height}, active: true, theme: theme)

    trends =
      state
      |> trends_frame({right_width - 2, top_height - 2})
      |> Layout.panel("Workload", {right_width, top_height}, theme: theme)

    table =
      state.table
      |> Table.view({width - 2, table_height - 2})
      |> Layout.panel("Process snapshot", {width, table_height}, theme: theme)

    Frame.new(width, height)
    |> Frame.overlay(metrics, 1, 1)
    |> Frame.overlay(trends, left_width + 2, 1)
    |> Frame.overlay(table, 1, top_height + 2)
  end

  defp compact_view(state, {width, height}, theme) do
    metrics_height = min(6, max(height, 2))
    table_height = max(height - metrics_height, 2)

    metrics =
      state
      |> metrics_frame({max(width - 2, 1), max(metrics_height - 2, 1)})
      |> Layout.panel("Live metrics", {width, metrics_height}, active: true, theme: theme)

    table =
      state.table
      |> Table.view({max(width - 2, 1), max(table_height - 2, 1)})
      |> Layout.panel("Processes", {width, table_height}, theme: theme)

    Frame.new(width, height)
    |> Frame.overlay(metrics, 1, 1)
    |> Frame.overlay(table, 1, metrics_height + 1)
  end

  defp metrics_frame(state, {width, height}) do
    Frame.new(max(width, 1), max(height, 1))
    |> Frame.overlay(Gauge.view(state.cpu, {max(width, 1), 1}), 1, 1)
    |> Frame.overlay(Gauge.view(state.memory, {max(width, 1), 1}), 1, min(2, max(height, 1)))
    |> Frame.overlay(Progress.view(state.jobs, {max(width, 1), 1}), 1, min(3, max(height, 1)))
  end

  defp trends_frame(state, {width, height}) do
    width = max(width, 1)
    height = max(height, 1)
    bar_height = max(height - 2, 1)

    Frame.new(width, height)
    |> Frame.overlay(Sparkline.view(state.history, {width, 1}), 1, 1)
    |> Frame.overlay(BarChart.view(state.bars, {width, bar_height}), 1, min(3, height))
  end

  defp columns do
    [
      Column.new(:name, "Process"),
      Column.new(:memory, "Memory", width: 10, align: :right),
      Column.new(:queue, "Queue", width: 7, align: :right),
      Column.new(:status, "Status", width: 10)
    ]
  end

  defp process_rows(tick) do
    [
      %{name: "term_ui", memory: "12.4 MB", queue: rem(tick, 4), status: "running"},
      %{name: "assistant", memory: "48.1 MB", queue: rem(tick + 2, 7), status: "working"},
      %{name: "telemetry", memory: "5.7 MB", queue: 0, status: "idle"},
      %{name: "publisher", memory: "9.3 MB", queue: rem(tick + 1, 3), status: "running"}
    ]
  end

  defp service_bars(tick) do
    [
      %{label: "API", value: wave(tick, 68, 20, 5), color: :cyan},
      %{label: "Jobs", value: wave(tick, 48, 28, 7), color: :green},
      %{label: "Cache", value: wave(tick, 35, 15, 4), color: :yellow}
    ]
  end

  defp wave(tick, center, amplitude, period) do
    center + round(:math.sin(tick / period) * amplitude)
  end
end
