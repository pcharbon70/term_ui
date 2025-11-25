defmodule Gauge.App do
  @moduledoc """
  Gauge Widget Example

  This example demonstrates how to use the TermUI.Widgets.Gauge widget
  for displaying values within a range. The gauge supports:

  - Bar style (horizontal bar)
  - Arc style (semi-circular arc)
  - Color zones for visual feedback
  - Custom characters for the bar

  Controls:
  - Up/Down arrows: Increase/decrease value
  - Left/Right arrows: Adjust by larger increments
  - S: Toggle between bar and arc styles
  - Q: Quit the application
  """

  @behaviour TermUI.Component

  # Import view helpers for building render trees
  import TermUI.Component.RenderNode

  # Import the Gauge widget
  alias TermUI.Widgets.Gauge
  alias TermUI.Event
  alias TermUI.Style

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.

  We store:
  - value: Current gauge value (0-100)
  - style_type: :bar or :arc display style
  """
  @impl true
  def init(_opts) do
    %{
      value: 50,
      style_type: :bar
    }
  end

  @doc """
  Convert keyboard events to messages.

  This is where we map user input to application messages.
  """
  @impl true
  def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, {:change_value, 5}}
  def event_to_msg(%Event.Key{key: :down}, _state), do: {:msg, {:change_value, -5}}
  def event_to_msg(%Event.Key{key: :right}, _state), do: {:msg, {:change_value, 10}}
  def event_to_msg(%Event.Key{key: :left}, _state), do: {:msg, {:change_value, -10}}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["s", "S"], do: {:msg, :toggle_style}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"], do: {:msg, :quit}
  def event_to_msg(_event, _state), do: :ignore

  @doc """
  Update state based on messages.

  Returns {new_state, commands} where commands is a list of side effects.
  """
  @impl true
  def update({:change_value, delta}, state) do
    # Clamp value between 0 and 100
    new_value = max(0, min(100, state.value + delta))
    {%{state | value: new_value}, []}
  end

  def update(:toggle_style, state) do
    # Toggle between :bar and :arc styles
    new_style = if state.style_type == :bar, do: :arc, else: :bar
    {%{state | style_type: new_style}, []}
  end

  def update(:quit, state) do
    # Return :quit command to exit the application
    {state, [:quit]}
  end

  @doc """
  Render the current state to a render tree.

  This is called every frame to produce the UI.
  """
  @impl true
  def view(state) do
    stack(:vertical, [
      # Title
      styled(
        text("Gauge Widget Example"),
        Style.new(fg: :cyan, attrs: [:bold])
      ),
      text(""),

      # Simple percentage gauge
      # The Gauge.percentage/2 helper creates a 0-100 gauge with value display
      text("Simple Percentage Gauge:"),
      Gauge.percentage(state.value, width: 30),
      text(""),

      # Gauge with color zones
      # Zones are {threshold, style} tuples - the color applies when value >= threshold
      text("Gauge with Color Zones:"),
      Gauge.render(
        value: state.value,
        min: 0,
        max: 100,
        width: 30,
        style_type: state.style_type,
        show_value: true,
        show_range: true,
        # Define color zones: green (0-59), yellow (60-79), red (80-100)
        zones: [
          {0, Style.new(fg: :green)},
          {60, Style.new(fg: :yellow)},
          {80, Style.new(fg: :red)}
        ],
        label: "CPU Usage"
      ),
      text(""),

      # Gauge with custom characters
      text("Gauge with Custom Characters:"),
      Gauge.render(
        value: state.value,
        min: 0,
        max: 100,
        width: 30,
        # Use custom characters instead of default █ and ░
        bar_char: "▓",
        empty_char: "░",
        show_value: true,
        show_range: false
      ),
      text(""),

      # Controls help
      styled(
        text("Controls:"),
        Style.new(fg: :yellow)
      ),
      text("  ↑/↓     Adjust value by 5"),
      text("  ←/→     Adjust value by 10"),
      text("  S       Toggle bar/arc style"),
      text("  Q       Quit"),
      text(""),
      text("Current style: #{state.style_type}")
    ])
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Run the gauge example application.
  """
  def run do
    TermUI.run(__MODULE__)
  end
end
