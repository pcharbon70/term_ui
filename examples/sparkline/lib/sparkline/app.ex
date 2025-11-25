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

  @behaviour TermUI.Component

  import TermUI.Component.RenderNode

  alias TermUI.Widgets.Sparkline
  alias TermUI.Event
  alias TermUI.Style

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.

  We maintain:
  - values: List of data points for the sparkline
  - colored: Whether to show color-coded sparkline
  """
  @impl true
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
  @impl true
  def event_to_msg(%Event.Key{key: " "}, _state), do: {:msg, :add_point}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["r", "R"], do: {:msg, :reset}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["c", "C"], do: {:msg, :toggle_color}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"], do: {:msg, :quit}
  def event_to_msg(_event, _state), do: :ignore

  @doc """
  Update state based on messages.
  """
  @impl true
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
  @impl true
  def view(state) do
    stack(:vertical, [
      # Title
      styled(
        text("Sparkline Widget Example"),
        Style.new(fg: :cyan, attrs: [:bold])
      ),
      text(""),

      # Basic sparkline
      # The simplest usage - just pass a list of values
      text("Basic Sparkline:"),
      Sparkline.render(values: state.values),
      text(""),

      # Sparkline with explicit min/max
      # Useful when you want consistent scaling across multiple sparklines
      text("Sparkline with fixed scale (0-100):"),
      Sparkline.render(
        values: state.values,
        min: 0,
        max: 100
      ),
      text(""),

      # Labeled sparkline
      # Shows label and min/max values alongside the sparkline
      text("Labeled Sparkline:"),
      Sparkline.render_labeled(
        values: state.values,
        label: "CPU",
        show_range: true
      ),
      text(""),

      # Styled sparkline
      # Apply a color to the entire sparkline
      text("Styled Sparkline:"),
      Sparkline.render(
        values: state.values,
        style: Style.new(fg: :green)
      ),
      text(""),

      # Color-coded sparkline (when enabled)
      # Different colors based on value thresholds
      render_colored_sparkline(state),
      text(""),

      # Show the bar characters used
      text("Sparkline bar characters:"),
      text(Enum.join(Sparkline.bar_characters(), " ")),
      text(""),

      # Controls
      styled(
        text("Controls:"),
        Style.new(fg: :yellow)
      ),
      text("  Space   Add random data point"),
      text("  R       Reset data"),
      text("  C       Toggle color mode (#{if state.colored, do: "ON", else: "OFF"})"),
      text("  Q       Quit"),
      text(""),
      text("Data points: #{length(state.values)}")
    ])
  end

  # ----------------------------------------------------------------------------
  # Private Helpers
  # ----------------------------------------------------------------------------

  defp render_colored_sparkline(state) do
    if state.colored do
      stack(:vertical, [
        text("Color-coded Sparkline (green < 50 < yellow < 75 < red):"),
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
        text("Color-coded Sparkline (press C to enable):"),
        text("(disabled)")
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
