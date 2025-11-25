defmodule LineChart.App do
  @moduledoc """
  Line Chart Widget Example

  This example demonstrates how to use the TermUI.Widgets.LineChart widget
  for time series visualization using Braille patterns.

  The line chart uses Unicode Braille characters (U+2800-U+28FF) which provide
  2x4 dot resolution per character cell, enabling smooth line rendering.

  Features demonstrated:
  - Single series line chart
  - Multiple series comparison
  - Custom min/max scaling
  - Axis display
  - Dynamic data updates

  Controls:
  - Space: Add new data point
  - R: Reset/randomize data
  - A: Toggle axis display
  - Q: Quit the application
  """

  use TermUI.Elm

  alias TermUI.Widgets.LineChart
  alias TermUI.Event
  alias TermUI.Renderer.Style

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.
  """
  def init(_opts) do
    %{
      # Single series data (simulating CPU usage over time)
      cpu_data: generate_random_series(20),
      # Second series (simulating memory usage)
      memory_data: generate_random_series(20),
      # Display options
      show_axis: true
    }
  end

  defp generate_random_series(count) do
    # Generate semi-realistic looking data with some continuity
    Enum.reduce(1..count, [], fn _, acc ->
      last = List.last(acc) || 50
      # Random walk with bounds
      delta = :rand.uniform(21) - 11
      new_value = max(10, min(90, last + delta))
      acc ++ [new_value]
    end)
  end

  @doc """
  Convert keyboard events to messages.
  """
  def event_to_msg(%Event.Key{key: " "}, _state), do: {:msg, :add_point}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["r", "R"], do: {:msg, :reset}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["a", "A"], do: {:msg, :toggle_axis}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"], do: {:msg, :quit}
  def event_to_msg(_event, _state), do: :ignore

  @doc """
  Update state based on messages.
  """
  def update(:add_point, state) do
    # Add a new point to both series (sliding window)
    cpu_last = List.last(state.cpu_data) || 50
    cpu_new = max(10, min(90, cpu_last + :rand.uniform(21) - 11))
    cpu_data = (state.cpu_data ++ [cpu_new]) |> Enum.take(-25)

    mem_last = List.last(state.memory_data) || 50
    mem_new = max(10, min(90, mem_last + :rand.uniform(15) - 8))
    memory_data = (state.memory_data ++ [mem_new]) |> Enum.take(-25)

    {%{state | cpu_data: cpu_data, memory_data: memory_data}, []}
  end

  def update(:reset, state) do
    {%{state | cpu_data: generate_random_series(20), memory_data: generate_random_series(20)}, []}
  end

  def update(:toggle_axis, state) do
    {%{state | show_axis: not state.show_axis}, []}
  end

  def update(:quit, state) do
    {state, [:quit]}
  end

  @doc """
  Render the current state to a render tree.
  """
  def view(state) do
    stack(:vertical, [
      # Title
      text("Line Chart Widget Example", Style.new(fg: :cyan, attrs: [:bold])),
      text("", nil),

      # Single series chart
      text("Single Series (CPU Usage):", nil),
      LineChart.render(
        data: state.cpu_data,
        width: 40,
        height: 8,
        min: 0,
        max: 100,
        show_axis: state.show_axis,
        style: Style.new(fg: :green)
      ),
      text("", nil),

      # Multi-series chart
      text("Multi Series (CPU + Memory):", nil),
      LineChart.render(
        series: [
          %{data: state.cpu_data, color: Style.new(fg: :cyan)},
          %{data: state.memory_data, color: Style.new(fg: :magenta)}
        ],
        width: 40,
        height: 8,
        min: 0,
        max: 100,
        show_axis: state.show_axis
      ),
      text("  Cyan = CPU, Magenta = Memory", nil),
      text("", nil),

      # Braille pattern demo
      text("Braille characters for line drawing:", nil),
      render_braille_demo(),
      text("", nil),

      # Controls
      text("Controls:", Style.new(fg: :yellow)),
      text("  Space   Add new data point", nil),
      text("  R       Reset/randomize data", nil),
      text("  A       Toggle axis (#{if state.show_axis, do: "ON", else: "OFF"})", nil),
      text("  Q       Quit", nil),
      text("", nil),
      text("Data points: #{length(state.cpu_data)}", nil)
    ])
  end

  # ----------------------------------------------------------------------------
  # Private Helpers
  # ----------------------------------------------------------------------------

  defp render_braille_demo do
    # Show some example Braille patterns
    patterns = [
      LineChart.empty_braille(),
      LineChart.dots_to_braille([{0, 3}]),
      LineChart.dots_to_braille([{0, 2}]),
      LineChart.dots_to_braille([{0, 1}]),
      LineChart.dots_to_braille([{0, 0}]),
      LineChart.dots_to_braille([{0, 0}, {1, 0}]),
      LineChart.dots_to_braille([{0, 0}, {0, 1}]),
      LineChart.full_braille()
    ]

    text("  " <> Enum.join(patterns, " "), nil)
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Run the line chart example application.
  """
  def run do
    TermUI.Runtime.run(root: __MODULE__)
  end
end
