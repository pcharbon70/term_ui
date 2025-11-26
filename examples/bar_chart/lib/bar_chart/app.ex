defmodule BarChart.App do
  @moduledoc """
  Bar Chart Widget Example

  This example demonstrates how to use the TermUI.Widgets.BarChart widget
  for displaying comparative values as horizontal or vertical bars.

  Features demonstrated:
  - Horizontal bar charts
  - Vertical bar charts
  - Custom colors per bar
  - Value and label display options
  - Simple single bar helper

  Controls:
  - D: Toggle chart direction (horizontal/vertical)
  - V: Toggle value display
  - L: Toggle label display
  - R: Randomize data
  - Q: Quit the application
  """

  use TermUI.Elm

  alias TermUI.Widgets.BarChart
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
      data: sample_data(),
      direction: :horizontal,
      show_values: true,
      show_labels: true
    }
  end

  defp sample_data do
    [
      %{label: "Sales", value: 150},
      %{label: "Marketing", value: 85},
      %{label: "Engineering", value: 200},
      %{label: "Support", value: 120},
      %{label: "HR", value: 45}
    ]
  end

  @doc """
  Convert keyboard events to messages.
  """
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["d", "D"], do: {:msg, :toggle_direction}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["v", "V"], do: {:msg, :toggle_values}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["l", "L"], do: {:msg, :toggle_labels}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["r", "R"], do: {:msg, :randomize}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"], do: {:msg, :quit}
  def event_to_msg(_event, _state), do: :ignore

  @doc """
  Update state based on messages.
  """
  def update(:toggle_direction, state) do
    new_direction = if state.direction == :horizontal, do: :vertical, else: :horizontal
    {%{state | direction: new_direction}, []}
  end

  def update(:toggle_values, state) do
    {%{state | show_values: not state.show_values}, []}
  end

  def update(:toggle_labels, state) do
    {%{state | show_labels: not state.show_labels}, []}
  end

  def update(:randomize, state) do
    new_data =
      state.data
      |> Enum.map(fn item ->
        %{item | value: :rand.uniform(200) + 20}
      end)

    {%{state | data: new_data}, []}
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
      text("Bar Chart Widget Example", Style.new(fg: :cyan, attrs: [:bold])),
      text("", nil),

      # Main chart based on current direction
      render_main_chart(state),
      text("", nil),

      # Simple bar example
      text("Simple single bar:", nil),
      BarChart.bar(
        value: 75,
        max: 100,
        width: 30
      ),
      text("", nil),

      # Colored bar chart example
      text("Bar chart with colors:", nil),
      BarChart.render(
        data: [
          %{label: "Red", value: 80},
          %{label: "Green", value: 60},
          %{label: "Blue", value: 90}
        ],
        direction: :horizontal,
        width: 40,
        show_values: true,
        # Colors cycle through this list
        colors: [
          Style.new(fg: :red),
          Style.new(fg: :green),
          Style.new(fg: :blue)
        ]
      ),
      text("", nil),

      # Controls
      render_controls(state)
    ])
  end

  defp render_controls(state) do
    box_width = 50
    inner_width = box_width - 2

    top_border = "┌─ Controls " <> String.duplicate("─", inner_width - 12) <> "─┐"
    bottom_border = "└" <> String.duplicate("─", inner_width) <> "┘"

    stack(:vertical, [
      text("", nil),
      text(top_border, Style.new(fg: :yellow)),
      text("│" <> String.pad_trailing("  D   Toggle direction (#{state.direction})", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  V   Toggle values (#{if state.show_values, do: "ON", else: "OFF"})", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  L   Toggle labels (#{if state.show_labels, do: "ON", else: "OFF"})", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  R   Randomize data", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Q   Quit", inner_width) <> "│", nil),
      text(bottom_border, Style.new(fg: :yellow))
    ])
  end

  # ----------------------------------------------------------------------------
  # Private Helpers
  # ----------------------------------------------------------------------------

  defp render_main_chart(state) do
    case state.direction do
      :horizontal ->
        stack(:vertical, [
          text("Horizontal Bar Chart:", nil),
          BarChart.render(
            data: state.data,
            direction: :horizontal,
            width: 50,
            show_values: state.show_values,
            show_labels: state.show_labels,
            bar_char: "█"
          )
        ])

      :vertical ->
        stack(:vertical, [
          text("Vertical Bar Chart:", nil),
          BarChart.render(
            data: state.data,
            direction: :vertical,
            width: 30,
            height: 8,
            show_values: state.show_values,
            show_labels: state.show_labels,
            bar_char: "█"
          )
        ])
    end
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Run the bar chart example application.
  """
  def run do
    TermUI.Runtime.run(root: __MODULE__)
  end
end
