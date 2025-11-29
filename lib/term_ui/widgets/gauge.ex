defmodule TermUI.Widgets.Gauge do
  @moduledoc """
  Gauge widget for displaying a single value within a range.

  Shows value as a bar or arc with min/max labels and optional
  color zones for visual feedback.

  ## Usage

      Gauge.render(
        value: 75,
        min: 0,
        max: 100,
        width: 30,
        zones: [
          {0, :green},
          {60, :yellow},
          {80, :red}
        ]
      )

  ## Display Types

  - `:bar` - Horizontal bar (default)
  - `:arc` - Semi-circular arc using block characters
  """

  import TermUI.Component.RenderNode
  alias TermUI.Widgets.VisualizationHelper, as: VizHelper

  @bar_char "█"
  @empty_char "░"

  @doc """
  Renders a gauge.

  ## Options

  - `:value` - Current value (required)
  - `:min` - Minimum value (default: 0)
  - `:max` - Maximum value (default: 100)
  - `:width` - Gauge width (default: 40, max: #{VizHelper.max_width()})
  - `:type` - :bar or :arc (default: :bar)
  - `:show_value` - Show numeric value (default: true)
  - `:show_range` - Show min/max labels (default: true)
  - `:zones` - List of {threshold, style} for color zones
  - `:label` - Label for the gauge
  - `:bar_char` - Character for filled portion
  - `:empty_char` - Character for empty portion
  """
  @spec render(keyword()) :: TermUI.Component.RenderNode.t()
  def render(opts) do
    value = Keyword.get(opts, :value, 0)

    case VizHelper.validate_number(value) do
      :ok ->
        do_render(value, opts)

      {:error, _msg} ->
        empty()
    end
  end

  defp do_render(value, opts) do
    min = Keyword.get(opts, :min, 0)
    max = Keyword.get(opts, :max, 100)
    width = opts |> Keyword.get(:width, 40) |> VizHelper.clamp_width()
    # Support both :type and :style_type for backward compatibility
    gauge_type = Keyword.get(opts, :type, Keyword.get(opts, :style_type, :bar))
    show_value = Keyword.get(opts, :show_value, true)
    show_range = Keyword.get(opts, :show_range, true)
    zones = Keyword.get(opts, :zones, [])
    label = Keyword.get(opts, :label)
    bar_char = Keyword.get(opts, :bar_char, @bar_char)
    empty_char = Keyword.get(opts, :empty_char, @empty_char)

    case gauge_type do
      :bar ->
        bar_opts = %{
          value: value,
          min: min,
          max: max,
          width: width,
          show_value: show_value,
          show_range: show_range,
          zones: zones,
          label: label,
          bar_char: bar_char,
          empty_char: empty_char
        }

        render_bar(bar_opts)

      :arc ->
        render_arc(value, min, max, width, show_value, zones, label)

      _ ->
        # Default to bar for unknown types
        bar_opts = %{
          value: value,
          min: min,
          max: max,
          width: width,
          show_value: show_value,
          show_range: show_range,
          zones: zones,
          label: label,
          bar_char: bar_char,
          empty_char: empty_char
        }

        render_bar(bar_opts)
    end
  end

  defp render_bar(opts) do
    value = opts.value
    min = opts.min
    max = opts.max
    width = opts.width
    show_value = opts.show_value
    show_range = opts.show_range
    zones = opts.zones
    label = opts.label
    bar_char = opts.bar_char
    empty_char = opts.empty_char

    # Calculate fill
    normalized = VizHelper.normalize(value, min, max)
    filled_width = round(normalized * width)
    empty_width = width - filled_width

    # Build bar with safe duplicate
    filled = VizHelper.safe_duplicate(bar_char, filled_width)
    empty_part = VizHelper.safe_duplicate(empty_char, empty_width)

    # Apply zone color
    zone_style = VizHelper.find_zone(value, zones)

    bar =
      text(filled)
      |> VizHelper.maybe_style(zone_style)

    # Build components
    parts = []

    # Label row
    parts =
      if label do
        [text(label) | parts]
      else
        parts
      end

    # Bar row
    bar_row = stack(:horizontal, [bar, text(empty_part)])
    parts = [bar_row | parts]

    # Range/value row
    bottom_parts = []

    bottom_parts =
      if show_range do
        [text(VizHelper.format_number(min)) | bottom_parts]
      else
        bottom_parts
      end

    bottom_parts =
      if show_value do
        value_str = VizHelper.format_number(value)
        # Center the value
        padding =
          if show_range do
            max(0, div(width - String.length(value_str), 2))
          else
            0
          end

        [text(VizHelper.safe_duplicate(" ", padding) <> value_str) | bottom_parts]
      else
        bottom_parts
      end

    bottom_parts =
      if show_range do
        max_str = VizHelper.format_number(max)
        padding = width - String.length(max_str)
        padding = if show_value, do: div(padding, 2), else: padding
        [text(VizHelper.safe_duplicate(" ", max(0, padding)) <> max_str) | bottom_parts]
      else
        bottom_parts
      end

    parts =
      if Enum.empty?(bottom_parts) do
        parts
      else
        bottom_row = stack(:horizontal, Enum.reverse(bottom_parts))
        [bottom_row | parts]
      end

    stack(:vertical, Enum.reverse(parts))
  end

  defp render_arc(value, min, max, width, show_value, _zones, label) do
    # Simple arc using block characters
    normalized = VizHelper.normalize(value, min, max)

    # Calculate position on arc with bounds checking
    arc_position = round(normalized * (width - 2))
    arc_position = max(0, min(arc_position, width - 3))

    # Build arc visualization with safe duplicate
    top = "╭" <> VizHelper.safe_duplicate("─", width - 2) <> "╮"

    # Middle shows value position
    right_padding = max(0, width - arc_position - 3)
    indicator_line =
      VizHelper.safe_duplicate(" ", arc_position) <>
        "▼" <>
        VizHelper.safe_duplicate(" ", right_padding)

    middle = "│" <> indicator_line <> "│"

    bottom = "╰" <> VizHelper.safe_duplicate("─", width - 2) <> "╯"

    parts = [text(top), text(middle), text(bottom)]

    # Add value display
    parts =
      if show_value do
        value_str = VizHelper.format_number(value)
        padding = max(0, div(width - String.length(value_str), 2))
        value_row = text(VizHelper.safe_duplicate(" ", padding) <> value_str)
        parts ++ [value_row]
      else
        parts
      end

    # Add label
    parts =
      if label do
        label_row = text(label)
        [label_row | parts]
      else
        parts
      end

    stack(:vertical, parts)
  end

  @doc """
  Creates a simple percentage gauge.

  ## Examples

      Gauge.percentage(75, width: 20)
  """
  @spec percentage(number(), keyword()) :: TermUI.Component.RenderNode.t()
  def percentage(value, opts \\ []) do
    opts =
      Keyword.merge(
        [
          value: value,
          min: 0,
          max: 100,
          show_value: true,
          show_range: false
        ],
        opts
      )

    render(opts)
  end

  @doc """
  Creates a gauge with traffic light colors (green/yellow/red).

  ## Options

  - `:value` - Current value (required)
  - `:warning` - Yellow zone threshold (default: 60)
  - `:danger` - Red zone threshold (default: 80)

  Note: You need to provide actual Style structs for the zones to be visible.
  """
  @spec traffic_light(keyword()) :: TermUI.Component.RenderNode.t()
  def traffic_light(opts) do
    value = Keyword.get(opts, :value, 0)
    warning = Keyword.get(opts, :warning, 60)
    danger = Keyword.get(opts, :danger, 80)

    # Create zones - users should provide actual Style structs
    # These nil values mean no styling will be applied by default
    zones = [
      # green zone (default)
      {0, nil},
      # yellow zone
      {warning, nil},
      # red zone
      {danger, nil}
    ]

    opts = opts |> Keyword.put(:value, value) |> Keyword.merge(zones: zones)
    render(opts)
  end
end
