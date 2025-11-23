defmodule TermUI.Widgets.BarChart do
  @moduledoc """
  Bar chart widget for displaying comparative values.

  Renders horizontal or vertical bars proportional to data values.
  Supports multiple series, labels, and color coding.

  ## Usage

      BarChart.render(
        data: [
          %{label: "Sales", value: 150},
          %{label: "Revenue", value: 200},
          %{label: "Profit", value: 75}
        ],
        direction: :horizontal,
        width: 40,
        show_values: true
      )

  ## Options

  - `:data` - List of data points with label and value
  - `:direction` - :horizontal or :vertical (default: :horizontal)
  - `:width` - Chart width in characters
  - `:height` - Chart height (for vertical charts)
  - `:show_values` - Display value labels (default: true)
  - `:show_labels` - Display bar labels (default: true)
  - `:bar_char` - Character for bars (default: "█")
  - `:empty_char` - Character for empty space (default: " ")
  - `:colors` - List of colors for series
  """

  import TermUI.Component.RenderNode

  @bar_char "█"
  @empty_char " "

  @doc """
  Renders a bar chart.

  ## Options

  - `:data` - List of `%{label: String.t(), value: number()}` (required)
  - `:direction` - :horizontal or :vertical (default: :horizontal)
  - `:width` - Chart width (default: 40)
  - `:height` - Chart height for vertical (default: 10)
  - `:show_values` - Show value labels (default: true)
  - `:show_labels` - Show bar labels (default: true)
  - `:bar_char` - Bar character (default: "█")
  - `:colors` - List of colors for bars
  - `:style` - Style for the chart
  """
  @spec render(keyword()) :: TermUI.Component.RenderNode.t()
  def render(opts) do
    data = Keyword.fetch!(opts, :data)
    direction = Keyword.get(opts, :direction, :horizontal)
    width = Keyword.get(opts, :width, 40)
    height = Keyword.get(opts, :height, 10)
    show_values = Keyword.get(opts, :show_values, true)
    show_labels = Keyword.get(opts, :show_labels, true)
    bar_char = Keyword.get(opts, :bar_char, @bar_char)
    colors = Keyword.get(opts, :colors, [])
    style = Keyword.get(opts, :style)

    case direction do
      :horizontal ->
        render_horizontal(data, width, show_values, show_labels, bar_char, colors, style)

      :vertical ->
        render_vertical(data, width, height, show_values, show_labels, bar_char, colors, style)
    end
  end

  defp render_horizontal(data, width, show_values, show_labels, bar_char, colors, style) do
    return_empty_if_no_data(data) ||
      do_render_horizontal(data, width, show_values, show_labels, bar_char, colors, style)
  end

  defp do_render_horizontal(data, width, show_values, show_labels, bar_char, colors, style) do
    max_value = data |> Enum.map(& &1.value) |> Enum.max()

    max_label_len =
      if show_labels do
        data |> Enum.map(&String.length(&1.label)) |> Enum.max()
      else
        0
      end

    # Calculate bar width
    value_width = if show_values, do: 8, else: 0
    bar_width = width - max_label_len - value_width - 2

    rows =
      data
      |> Enum.with_index()
      |> Enum.map(fn {item, index} ->
        # Label
        label =
          if show_labels do
            String.pad_trailing(item.label, max_label_len) <> " "
          else
            ""
          end

        # Bar
        bar_length =
          if max_value > 0 do
            round(item.value / max_value * bar_width)
          else
            0
          end

        bar = String.duplicate(bar_char, bar_length)
        empty = String.duplicate(@empty_char, bar_width - bar_length)

        # Value
        value_str =
          if show_values do
            " " <> format_value(item.value)
          else
            ""
          end

        line = label <> bar <> empty <> value_str

        # Apply color if specified
        color = Enum.at(colors, rem(index, max(1, length(colors))))

        if color do
          styled(text(line), color)
        else
          text(line)
        end
      end)

    result = stack(:vertical, rows)

    if style do
      styled(result, style)
    else
      result
    end
  end

  defp render_vertical(data, width, height, show_values, show_labels, bar_char, colors, style) do
    return_empty_if_no_data(data) ||
      do_render_vertical(data, width, height, show_values, show_labels, bar_char, colors, style)
  end

  defp do_render_vertical(data, _width, height, show_values, show_labels, bar_char, colors, style) do
    max_value = data |> Enum.map(& &1.value) |> Enum.max()

    # Calculate bar heights
    bar_heights =
      Enum.map(data, fn item ->
        if max_value > 0 do
          round(item.value / max_value * height)
        else
          0
        end
      end)

    # Build rows from top to bottom
    rows =
      for row <- (height - 1)..0//-1 do
        chars =
          data
          |> Enum.with_index()
          |> Enum.map(fn {_item, index} ->
            bar_height = Enum.at(bar_heights, index)
            build_bar_char(row, bar_height, index, bar_char, colors)
          end)

        # Join chars with spacing
        line_parts = Enum.map(chars, &style_bar_char/1)

        stack(:horizontal, line_parts)
      end

    # Add value labels
    value_row =
      if show_values do
        values =
          Enum.map(data, fn item ->
            format_value(item.value) |> String.pad_leading(3)
          end)

        [text(Enum.join(values, " "))]
      else
        []
      end

    # Add labels
    label_row =
      if show_labels do
        labels =
          Enum.map(data, fn item ->
            String.slice(item.label, 0, 3) |> String.pad_leading(3)
          end)

        [text(Enum.join(labels, " "))]
      else
        []
      end

    result = stack(:vertical, rows ++ value_row ++ label_row)

    if style do
      styled(result, style)
    else
      result
    end
  end

  defp return_empty_if_no_data([]), do: empty()
  defp return_empty_if_no_data(_), do: nil

  defp format_value(value) when is_float(value) do
    :erlang.float_to_binary(value, decimals: 1)
  end

  defp format_value(value) when is_integer(value) do
    Integer.to_string(value)
  end

  defp format_value(value), do: inspect(value)

  defp build_bar_char(row, bar_height, index, bar_char, colors) when row < bar_height do
    color = Enum.at(colors, rem(index, max(1, length(colors))))
    {bar_char, color}
  end

  defp build_bar_char(_row, _bar_height, _index, _bar_char, _colors) do
    {@empty_char, nil}
  end

  defp style_bar_char({char, color}) do
    padded = " " <> char <> " "

    if color do
      styled(text(padded), color)
    else
      text(padded)
    end
  end

  @doc """
  Creates a simple horizontal bar for a single value.

  ## Options

  - `:value` - Current value (required)
  - `:max` - Maximum value (required)
  - `:width` - Bar width (default: 20)
  - `:bar_char` - Bar character (default: "█")
  - `:empty_char` - Empty character (default: "░")
  """
  @spec bar(keyword()) :: TermUI.Component.RenderNode.t()
  def bar(opts) do
    value = Keyword.fetch!(opts, :value)
    max = Keyword.fetch!(opts, :max)
    width = Keyword.get(opts, :width, 20)
    bar_char = Keyword.get(opts, :bar_char, @bar_char)
    empty_char = Keyword.get(opts, :empty_char, "░")

    filled =
      if max > 0 do
        round(value / max * width)
      else
        0
      end

    filled = min(filled, width)
    empty = width - filled

    text(String.duplicate(bar_char, filled) <> String.duplicate(empty_char, empty))
  end
end
