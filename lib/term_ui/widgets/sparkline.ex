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
  alias TermUI.Widgets.VisualizationHelper, as: VizHelper

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
    values = Keyword.get(opts, :values, [])

    case VizHelper.validate_number_list(values) do
      :ok when values == [] ->
        empty()

      :ok ->
        do_render(values, opts)

      {:error, _msg} ->
        # Return empty for invalid data
        empty()
    end
  end

  defp do_render(values, opts) do
    {min, max} = VizHelper.calculate_range(values, opts)
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

    VizHelper.maybe_style(result, style)
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
    color = VizHelper.find_zone(value, color_ranges)
    node = text(char)
    VizHelper.maybe_style(node, color)
  end

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
  def value_to_bar(value, min, max) when is_number(value) and is_number(min) and is_number(max) do
    if max > min do
      # Normalize value to 0-1 range
      normalized = VizHelper.normalize(value, min, max)

      # Map to bar index (0 to @bar_count - 1)
      index = round(normalized * (@bar_count - 1))
      Enum.at(@bars, index)
    else
      # When min == max, return middle bar
      Enum.at(@bars, div(@bar_count, 2))
    end
  end

  def value_to_bar(_value, _min, _max) do
    # Invalid input, return middle bar
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
  @spec to_sparkline([number()], keyword()) :: String.t()
  def to_sparkline(values, opts \\ [])

  def to_sparkline([], _opts), do: ""

  def to_sparkline(values, opts) when is_list(values) do
    case VizHelper.validate_number_list(values) do
      :ok ->
        {min, max} = VizHelper.calculate_range(values, opts)
        Enum.map_join(values, "", &value_to_bar(&1, min, max))

      {:error, _} ->
        ""
    end
  end

  def to_sparkline(_, _), do: ""

  # Keep old name for backward compatibility
  @doc false
  @spec to_string([number()], keyword()) :: String.t()
  def to_string(values, opts \\ []), do: to_sparkline(values, opts)

  @doc """
  Renders a labeled sparkline with min/max indicators.

  ## Options

  - `:values` - List of numeric values (required)
  - `:label` - Label for the sparkline
  - `:show_range` - Show min/max values (default: true)
  """
  @spec render_labeled(keyword()) :: TermUI.Component.RenderNode.t()
  def render_labeled(opts) do
    values = Keyword.get(opts, :values, [])
    label = Keyword.get(opts, :label, "")
    show_range = Keyword.get(opts, :show_range, true)

    case VizHelper.validate_number_list(values) do
      :ok when values == [] ->
        empty()

      :ok ->
        {min, max} = VizHelper.calculate_range(values)
        sparkline = to_sparkline(values, min: min, max: max)

        parts = []

        parts =
          if label != "" do
            [text(label <> " ") | parts]
          else
            parts
          end

        parts =
          if show_range do
            [text(VizHelper.format_number(min) <> " ") | parts]
          else
            parts
          end

        parts = [text(sparkline) | parts]

        parts =
          if show_range do
            [text(" " <> VizHelper.format_number(max)) | parts]
          else
            parts
          end

        stack(:horizontal, Enum.reverse(parts))

      {:error, _} ->
        empty()
    end
  end
end
