defmodule TermUI.Widget.Progress do
  @moduledoc """
  A widget for displaying progress bars and spinners.

  Progress supports two modes:
  - Bar mode: Shows a filled bar proportional to progress value
  - Spinner mode: Shows an animated indicator for indeterminate progress

  ## Usage

      # Bar mode
      Progress.render(%{value: 0.5}, state, area)

      # With percentage
      Progress.render(%{value: 0.75, show_percentage: true}, state, area)

      # Spinner mode
      Progress.render(%{mode: :spinner}, state, area)

  ## Props

  - `:value` - Progress value 0.0 to 1.0 (default: 0.0)
  - `:mode` - `:bar` or `:spinner` (default: `:bar`)
  - `:show_percentage` - Show percentage text (default: `false`)
  - `:filled_char` - Character for filled portion (default: `"█"`)
  - `:empty_char` - Character for empty portion (default: `"░"`)
  - `:style` - Style options for the bar
  """

  use TermUI.StatefulComponent

  alias TermUI.Renderer.Style
  alias TermUI.Component.RenderNode

  @spinner_frames ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

  @doc """
  Initializes the progress widget state.
  """
  @impl true
  def init(props) do
    state = %{
      value: Map.get(props, :value, 0.0),
      mode: Map.get(props, :mode, :bar),
      spinner_frame: 0,
      props: props
    }

    {:ok, state}
  end

  @doc """
  Handles events for the progress widget.
  """
  @impl true
  def handle_event({:set_value, value}, state) do
    {:ok, %{state | value: clamp(value, 0.0, 1.0)}}
  end

  def handle_event(:tick, state) do
    # Advance spinner frame
    next_frame = rem(state.spinner_frame + 1, length(@spinner_frames))
    {:ok, %{state | spinner_frame: next_frame}}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  @doc """
  Renders the progress indicator.
  """
  @impl true
  def render(state, area) do
    props = state.props
    mode = Map.get(props, :mode, :bar)
    style_opts = Map.get(props, :style, %{})
    style = build_style(style_opts)

    cells =
      case mode do
        :bar -> render_bar(props, state, area, style)
        :spinner -> render_spinner(state, area, style)
      end

    RenderNode.cells(cells)
  end

  # Private Functions

  defp render_bar(props, state, area, style) do
    value = state.value
    show_percentage = Map.get(props, :show_percentage, false)
    filled_char = Map.get(props, :filled_char, "█")
    empty_char = Map.get(props, :empty_char, "░")

    # Calculate bar width (reserve space for percentage if shown)
    bar_width =
      if show_percentage do
        max(1, area.width - 5)  # " 100%"
      else
        area.width
      end

    filled_width = round(value * bar_width)
    empty_width = bar_width - filled_width

    # Build bar string
    bar =
      String.duplicate(filled_char, filled_width) <>
        String.duplicate(empty_char, empty_width)

    # Add percentage if requested
    display =
      if show_percentage do
        percentage = round(value * 100)
        bar <> " #{percentage}%"
      else
        bar
      end

    # Create cells
    display
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.filter(fn {_char, x} -> x < area.width end)
    |> Enum.map(fn {char, x} ->
      positioned_cell(x, 0, char, style)
    end)
  end

  defp render_spinner(state, area, style) do
    frame = Enum.at(@spinner_frames, state.spinner_frame)

    if area.width > 0 do
      [positioned_cell(0, 0, frame, style)]
    else
      []
    end
  end

  defp build_style(opts) when is_map(opts) do
    style_list =
      opts
      |> Enum.map(fn
        {:fg, color} -> {:fg, color}
        {:bg, color} -> {:bg, color}
        {:bold, true} -> {:attrs, [:bold]}
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)

    Style.new(style_list)
  end

  defp build_style(_), do: Style.new()

  defp clamp(value, min, max) do
    value |> max(min) |> min(max)
  end
end
