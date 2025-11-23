defmodule TermUI.Widgets.Sparkline do
  @moduledoc """
  Sparkline widget for compact inline trend visualization.

  Uses vertical bar characters (▁▂▃▄▅▆▇█) to display values in minimal space.
  Perfect for inline data display within text.

  ## Usage

      Sparkline.render(
        values: [1, 3, 5, 2, 8, 4, 6],
        min: 0,
        max: 10
      )

  ## Bar Characters

  The sparkline uses 8 levels of vertical bar characters:
  ▁ (1/8), ▂ (2/8), ▃ (3/8), ▄ (4/8), ▅ (5/8), ▆ (6/8), ▇ (7/8), █ (8/8)
  """

  import TermUI.Component.RenderNode

  # Unicode block elements for sparkline (bottom to top)
  @bars ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
  @bar_count length(@bars)

  @doc """
  Renders a sparkline from values.

  ## Options

  - `:values` - List of numeric values (required)
  - `:min` - Minimum value for scaling (default: auto)
  - `:max` - Maximum value for scaling (default: auto)
  - `:style` - Style for the sparkline
  - `:color_ranges` - List of {threshold, color} for value-based coloring
  """
  @spec render(keyword()) :: TermUI.Component.RenderNode.t()
  def render(opts) do
    values = Keyword.fetch!(opts, :values)

    if Enum.empty?(values) do
      empty()
    else
      do_render(values, opts)
    end
  end

  defp do_render(values, opts) do
    min = Keyword.get(opts, :min, Enum.min(values))
    max = Keyword.get(opts, :max, Enum.max(values))
    style = Keyword.get(opts, :style)
    color_ranges = Keyword.get(opts, :color_ranges, [])

    chars =
      values
      |> Enum.map(fn value ->
        {value_to_bar(value, min, max), value}
      end)

    result =
      if Enum.empty?(color_ranges) do
        render_simple(chars)
      else
        render_colored(chars, color_ranges)
      end

    apply_style(result, style)
  end

  defp render_simple(chars) do
    char_list = Enum.map(chars, &elem(&1, 0))
    line = Enum.join(char_list)
    text(line)
  end

  defp render_colored(chars, color_ranges) do
    parts =
      Enum.map(chars, fn {char, value} ->
        style_char_with_color(char, value, color_ranges)
      end)

    stack(:horizontal, parts)
  end

  defp style_char_with_color(char, value, color_ranges) do
    case find_color_for_value(value, color_ranges) do
      nil -> text(char)
      color -> styled(text(char), color)
    end
  end

  defp apply_style(result, nil), do: result
  defp apply_style(result, style), do: styled(result, style)

  @doc """
  Converts a single value to its sparkline bar character.

  ## Examples

      iex> Sparkline.value_to_bar(5, 0, 10)
      "▄"

      iex> Sparkline.value_to_bar(10, 0, 10)
      "█"

      iex> Sparkline.value_to_bar(0, 0, 10)
      "▁"
  """
  @spec value_to_bar(number(), number(), number()) :: String.t()
  def value_to_bar(value, min, max) when max > min do
    # Normalize value to 0-1 range
    normalized = (value - min) / (max - min)
    normalized = max(0, min(1, normalized))

    # Map to bar index (0 to @bar_count - 1)
    index = round(normalized * (@bar_count - 1))
    Enum.at(@bars, index)
  end

  def value_to_bar(_value, _min, _max) do
    # When min == max, return middle bar
    Enum.at(@bars, div(@bar_count, 2))
  end

  @doc """
  Returns the list of bar characters used by sparklines.
  """
  @spec bar_characters() :: [String.t()]
  def bar_characters do
    @bars
  end

  @doc """
  Creates a sparkline string from values (returns string, not render node).

  ## Options

  - `:min` - Minimum value (default: auto)
  - `:max` - Maximum value (default: auto)
  """
  @spec to_string([number()], keyword()) :: String.t()
  def to_string(values, opts \\ [])

  def to_string([], _opts), do: ""

  def to_string(values, opts) do
    min = Keyword.get(opts, :min, Enum.min(values))
    max = Keyword.get(opts, :max, Enum.max(values))

    Enum.map_join(values, "", &value_to_bar(&1, min, max))
  end

  defp find_color_for_value(value, color_ranges) do
    # Find the first range where value >= threshold
    color_ranges
    |> Enum.sort_by(fn {threshold, _color} -> -threshold end)
    |> Enum.find_value(fn {threshold, color} ->
      if value >= threshold, do: color
    end)
  end

  @doc """
  Renders a labeled sparkline with min/max indicators.

  ## Options

  - `:values` - List of numeric values (required)
  - `:label` - Label for the sparkline
  - `:show_range` - Show min/max values (default: true)
  """
  @spec render_labeled(keyword()) :: TermUI.Component.RenderNode.t()
  def render_labeled(opts) do
    values = Keyword.fetch!(opts, :values)
    label = Keyword.get(opts, :label, "")
    show_range = Keyword.get(opts, :show_range, true)

    if Enum.empty?(values) do
      empty()
    else
      min = Enum.min(values)
      max = Enum.max(values)

      sparkline = to_string(values, min: min, max: max)

      parts = []

      parts =
        if label != "" do
          [text(label <> " ") | parts]
        else
          parts
        end

      parts =
        if show_range do
          [text("#{min} ") | parts]
        else
          parts
        end

      parts = [text(sparkline) | parts]

      parts =
        if show_range do
          [text(" #{max}") | parts]
        else
          parts
        end

      stack(:horizontal, Enum.reverse(parts))
    end
  end
end
