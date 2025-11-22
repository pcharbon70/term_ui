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

  ## Display Styles

  - `:bar` - Horizontal bar (default)
  - `:arc` - Semi-circular arc using block characters
  """

  import TermUI.Component.RenderNode

  @bar_char "█"
  @empty_char "░"

  @doc """
  Renders a gauge.

  ## Options

  - `:value` - Current value (required)
  - `:min` - Minimum value (default: 0)
  - `:max` - Maximum value (default: 100)
  - `:width` - Gauge width (default: 20)
  - `:style_type` - :bar or :arc (default: :bar)
  - `:show_value` - Show numeric value (default: true)
  - `:show_range` - Show min/max labels (default: true)
  - `:zones` - List of {threshold, style} for color zones
  - `:label` - Label for the gauge
  - `:bar_char` - Character for filled portion
  - `:empty_char` - Character for empty portion
  """
  @spec render(keyword()) :: TermUI.Component.RenderNode.t()
  def render(opts) do
    value = Keyword.fetch!(opts, :value)
    min = Keyword.get(opts, :min, 0)
    max = Keyword.get(opts, :max, 100)
    width = Keyword.get(opts, :width, 20)
    style_type = Keyword.get(opts, :style_type, :bar)
    show_value = Keyword.get(opts, :show_value, true)
    show_range = Keyword.get(opts, :show_range, true)
    zones = Keyword.get(opts, :zones, [])
    label = Keyword.get(opts, :label)
    bar_char = Keyword.get(opts, :bar_char, @bar_char)
    empty_char = Keyword.get(opts, :empty_char, @empty_char)

    case style_type do
      :bar ->
        render_bar(value, min, max, width, show_value, show_range, zones, label, bar_char, empty_char)

      :arc ->
        render_arc(value, min, max, width, show_value, zones, label)
    end
  end

  defp render_bar(value, min, max, width, show_value, show_range, zones, label, bar_char, empty_char) do
    # Calculate fill
    normalized = normalize_value(value, min, max)
    filled_width = round(normalized * width)
    empty_width = width - filled_width

    # Build bar
    filled = String.duplicate(bar_char, filled_width)
    empty = String.duplicate(empty_char, empty_width)

    # Apply zone color
    zone_style = find_zone_style(value, zones)

    bar = if zone_style do
      styled(text(filled), zone_style)
    else
      text(filled)
    end

    # Build components
    parts = []

    # Label row
    parts = if label do
      [text(label) | parts]
    else
      parts
    end

    # Bar row
    bar_row = stack(:horizontal, [bar, text(empty)])
    parts = [bar_row | parts]

    # Range/value row
    bottom_parts = []

    bottom_parts = if show_range do
      [text(format_number(min)) | bottom_parts]
    else
      bottom_parts
    end

    bottom_parts = if show_value do
      value_str = format_number(value)
      # Center the value
      padding = if show_range do
        div(width - String.length(value_str), 2)
      else
        0
      end
      [text(String.duplicate(" ", padding) <> value_str) | bottom_parts]
    else
      bottom_parts
    end

    bottom_parts = if show_range do
      max_str = format_number(max)
      padding = width - String.length(max_str)
      padding = if show_value, do: div(padding, 2), else: padding
      [text(String.duplicate(" ", max(0, padding)) <> max_str) | bottom_parts]
    else
      bottom_parts
    end

    parts = if Enum.empty?(bottom_parts) do
      parts
    else
      bottom_row = stack(:horizontal, Enum.reverse(bottom_parts))
      [bottom_row | parts]
    end

    stack(:vertical, Enum.reverse(parts))
  end

  defp render_arc(value, min, max, width, show_value, _zones, label) do
    # Simple arc using block characters
    normalized = normalize_value(value, min, max)

    # Calculate position on arc
    arc_position = round(normalized * (width - 2))

    # Build arc visualization
    top = "╭" <> String.duplicate("─", width - 2) <> "╮"

    # Middle shows value position
    indicator_line = String.duplicate(" ", arc_position) <> "▼" <>
                     String.duplicate(" ", width - arc_position - 3)
    middle = "│" <> indicator_line <> "│"

    bottom = "╰" <> String.duplicate("─", width - 2) <> "╯"

    parts = [text(top), text(middle), text(bottom)]

    # Add value display
    parts = if show_value do
      value_str = format_number(value)
      padding = div(width - String.length(value_str), 2)
      value_row = text(String.duplicate(" ", padding) <> value_str)
      parts ++ [value_row]
    else
      parts
    end

    # Add label
    parts = if label do
      label_row = text(label)
      [label_row | parts]
    else
      parts
    end

    stack(:vertical, parts)
  end

  defp normalize_value(value, min, max) when max > min do
    normalized = (value - min) / (max - min)
    max(0, min(1, normalized))
  end

  defp normalize_value(_value, _min, _max), do: 0.5

  defp find_zone_style(value, zones) do
    zones
    |> Enum.sort_by(fn {threshold, _style} -> -threshold end)
    |> Enum.find_value(fn {threshold, style} ->
      if value >= threshold, do: style
    end)
  end

  defp format_number(value) when is_float(value) do
    :erlang.float_to_binary(value, decimals: 1)
  end

  defp format_number(value) when is_integer(value) do
    Integer.to_string(value)
  end

  defp format_number(value), do: inspect(value)

  @doc """
  Creates a simple percentage gauge.

  ## Examples

      Gauge.percentage(75, width: 20)
  """
  @spec percentage(number(), keyword()) :: TermUI.Component.RenderNode.t()
  def percentage(value, opts \\ []) do
    opts = Keyword.merge([
      value: value,
      min: 0,
      max: 100,
      show_value: true,
      show_range: false
    ], opts)

    render(opts)
  end

  @doc """
  Creates a gauge with traffic light colors (green/yellow/red).

  ## Options

  - `:value` - Current value (required)
  - `:warning` - Yellow zone threshold (default: 60)
  - `:danger` - Red zone threshold (default: 80)
  """
  @spec traffic_light(keyword()) :: TermUI.Component.RenderNode.t()
  def traffic_light(opts) do
    _value = Keyword.fetch!(opts, :value)
    warning = Keyword.get(opts, :warning, 60)
    danger = Keyword.get(opts, :danger, 80)

    # Note: These would need actual Style structs in real usage
    zones = [
      {0, nil},       # green zone (default)
      {warning, nil}, # yellow zone
      {danger, nil}   # red zone
    ]

    opts = Keyword.merge(opts, zones: zones)
    render(opts)
  end
end
