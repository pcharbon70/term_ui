defmodule Sparkline.App do
  @moduledoc """
  Sparkline Widget Example

  This example demonstrates how to use the TermUI.Widgets.Sparkline widget
  for compact inline trend visualization. Sparklines use vertical bar
  characters (▁▂▃▄▅▆▇█) to display values in minimal space.

  Features demonstrated:
  - Basic sparkline rendering
  - Labeled sparklines with min/max values
  - Color-coded sparklines based on value ranges
  - Auto-updating data simulation

  Controls:
  - Space: Add a new random data point
  - R: Reset data to initial values
  - C: Toggle color mode
  - Q: Quit the application
  """

  use TermUI.Elm

  alias TermUI.Widgets.Sparkline
  alias TermUI.Event
  alias TermUI.Renderer.Style

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.

  We maintain:
  - values: List of data points for the sparkline
  - colored: Whether to show color-coded sparkline
  """
  def init(_opts) do
    %{
      # Initial sample data simulating CPU usage over time
      values: [35, 42, 38, 55, 48, 62, 58, 71, 65, 78, 72, 85, 79, 68, 55],
      colored: false
    }
  end

  @doc """
  Convert keyboard events to messages.
  """
  def event_to_msg(%Event.Key{key: " "}, _state), do: {:msg, :add_point}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["r", "R"], do: {:msg, :reset}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["c", "C"], do: {:msg, :toggle_color}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"], do: {:msg, :quit}
  def event_to_msg(_event, _state), do: :ignore

  @doc """
  Update state based on messages.
  """
  def update(:add_point, state) do
    # Add a random value between 10 and 100
    new_value = :rand.uniform(90) + 10

    # Keep only the last 20 values (sliding window)
    new_values =
      (state.values ++ [new_value])
      |> Enum.take(-20)

    {%{state | values: new_values}, []}
  end

  def update(:reset, state) do
    # Reset to initial data
    initial = [35, 42, 38, 55, 48, 62, 58, 71, 65, 78, 72, 85, 79, 68, 55]
    {%{state | values: initial}, []}
  end

  def update(:toggle_color, state) do
    {%{state | colored: not state.colored}, []}
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
      text("Sparkline Widget Example", Style.new(fg: :cyan, attrs: [:bold])),
      text("", nil),

      # Basic sparkline
      # The simplest usage - just pass a list of values
      text("Basic Sparkline:", nil),
      Sparkline.render(values: state.values),
      text("", nil),

      # Sparkline with explicit min/max
      # Useful when you want consistent scaling across multiple sparklines
      text("Sparkline with fixed scale (0-100):", nil),
      Sparkline.render(
        values: state.values,
        min: 0,
        max: 100
      ),
      text("", nil),

      # Labeled sparkline
      # Shows label and min/max values alongside the sparkline
      text("Labeled Sparkline:", nil),
      Sparkline.render_labeled(
        values: state.values,
        label: "CPU",
        show_range: true
      ),
      text("", nil),

      # Styled sparkline
      # Apply a color to the entire sparkline
      text("Styled Sparkline:", nil),
      Sparkline.render(
        values: state.values,
        style: Style.new(fg: :green)
      ),
      text("", nil),

      # Color-coded sparkline (when enabled)
      # Different colors based on value thresholds
      render_colored_sparkline(state),
      text("", nil),

      # Show the bar characters used
      text("Sparkline bar characters:", nil),
      text(Enum.join(Sparkline.bar_characters(), " "), nil),
      text("", nil),

      # Controls
      render_controls(state)
    ])
  end

  defp render_controls(state) do
    box_width = 56
    inner_width = box_width - 2

    top_border = "┌─ Controls " <> String.duplicate("─", inner_width - 12) <> "─┐"
    bottom_border = "└" <> String.duplicate("─", inner_width) <> "┘"

    stack(:vertical, [
      text("", nil),
      text(top_border, Style.new(fg: :yellow)),
      text("│" <> String.pad_trailing("  Space   Add random data point", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  R       Reset data", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  C       Toggle color mode (#{if state.colored, do: "ON", else: "OFF"})", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Q       Quit", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("", inner_width) <> "│", nil),
      text("│" <> String.pad_trailing("  Data points: #{length(state.values)}", inner_width) <> "│", nil),
      text(bottom_border, Style.new(fg: :yellow))
    ])
  end

  # ----------------------------------------------------------------------------
  # Private Helpers
  # ----------------------------------------------------------------------------

  defp render_colored_sparkline(state) do
    if state.colored do
      stack(:vertical, [
        text("Color-coded Sparkline (green < 50 < yellow < 75 < red):", nil),
        Sparkline.render(
          values: state.values,
          # Color ranges: {threshold, color}
          # Colors apply when value >= threshold
          color_ranges: [
            {0, Style.new(fg: :green)},
            {50, Style.new(fg: :yellow)},
            {75, Style.new(fg: :red)}
          ]
        )
      ])
    else
      stack(:vertical, [
        text("Color-coded Sparkline (press C to enable):", nil),
        text("(disabled)", nil)
      ])
    end
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Run the sparkline example application.
  """
  def run do
    TermUI.Runtime.run(root: __MODULE__)
  end
end
