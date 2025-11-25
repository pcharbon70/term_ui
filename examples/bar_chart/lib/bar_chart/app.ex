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

  @behaviour TermUI.Component

  import TermUI.Component.RenderNode

  alias TermUI.Widgets.BarChart
  alias TermUI.Event
  alias TermUI.Style

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.
  """
  @impl true
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
  @impl true
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["d", "D"], do: {:msg, :toggle_direction}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["v", "V"], do: {:msg, :toggle_values}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["l", "L"], do: {:msg, :toggle_labels}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["r", "R"], do: {:msg, :randomize}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"], do: {:msg, :quit}
  def event_to_msg(_event, _state), do: :ignore

  @doc """
  Update state based on messages.
  """
  @impl true
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
  @impl true
  def view(state) do
    stack(:vertical, [
      # Title
      styled(
        text("Bar Chart Widget Example"),
        Style.new(fg: :cyan, attrs: [:bold])
      ),
      text(""),

      # Main chart based on current direction
      render_main_chart(state),
      text(""),

      # Simple bar example
      text("Simple single bar:"),
      BarChart.bar(
        value: 75,
        max: 100,
        width: 30
      ),
      text(""),

      # Colored bar chart example
      text("Bar chart with colors:"),
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
      text(""),

      # Controls
      styled(
        text("Controls:"),
        Style.new(fg: :yellow)
      ),
      text("  D   Toggle direction (#{state.direction})"),
      text("  V   Toggle values (#{if state.show_values, do: "ON", else: "OFF"})"),
      text("  L   Toggle labels (#{if state.show_labels, do: "ON", else: "OFF"})"),
      text("  R   Randomize data"),
      text("  Q   Quit")
    ])
  end

  # ----------------------------------------------------------------------------
  # Private Helpers
  # ----------------------------------------------------------------------------

  defp render_main_chart(state) do
    case state.direction do
      :horizontal ->
        stack(:vertical, [
          text("Horizontal Bar Chart:"),
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
          text("Vertical Bar Chart:"),
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
    TermUI.run(__MODULE__)
  end
end
