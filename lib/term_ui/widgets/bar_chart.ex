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
  - `:width` - Chart width in characters (max: #{TermUI.Widgets.VisualizationHelper.max_width()})
  - `:height` - Chart height for vertical charts (max: #{TermUI.Widgets.VisualizationHelper.max_height()})
  - `:show_values` - Display value labels (default: true)
  - `:show_labels` - Display bar labels (default: true)
  - `:bar_char` - Character for bars (default: "█")
  - `:empty_char` - Character for empty space (default: " ")
  - `:colors` - List of colors for series
  """

  import TermUI.Component.RenderNode
  alias TermUI.Widgets.VisualizationHelper, as: VizHelper

  @bar_char "█"
  @empty_char " "
  @max_label_length 50

  @doc """
  Renders a bar chart.

  ## Options

  - `:data` - List of `%{label: String.t(), value: number()}` (required)
  - `:direction` - :horizontal or :vertical (default: :horizontal)
  - `:width` - Chart width (default: 40, max: #{VizHelper.max_width()})
  - `:height` - Chart height for vertical (default: 10, max: #{VizHelper.max_height()})
  - `:show_values` - Show value labels (default: true)
  - `:show_labels` - Show bar labels (default: true)
  - `:bar_char` - Bar character (default: "█")
  - `:colors` - List of colors for bars
  - `:style` - Style for the chart
  """
  @spec render(keyword()) :: TermUI.Component.RenderNode.t()
  def render(opts) do
    data = Keyword.get(opts, :data, [])

    case VizHelper.validate_bar_data(data) do
      :ok when data == [] ->
        empty()

      :ok ->
        direction = Keyword.get(opts, :direction, :horizontal)
        width = opts |> Keyword.get(:width, 40) |> VizHelper.clamp_width()
        height = opts |> Keyword.get(:height, 10) |> VizHelper.clamp_height()
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

          _ ->
            render_horizontal(data, width, show_values, show_labels, bar_char, colors, style)
        end

      {:error, _msg} ->
        # Return empty for invalid data rather than crashing
        empty()
    end
  end

  defp render_horizontal(data, width, show_values, show_labels, bar_char, colors, style) do
    values = Enum.map(data, & &1.value)
    max_value = Enum.max(values, fn -> 0 end)

    max_label_len =
      if show_labels do
        data
        |> Enum.map(&String.length(&1.label))
        |> Enum.max(fn -> 0 end)
        |> min(@max_label_length)
      else
        0
      end

    # Calculate bar width with bounds checking
    value_width = if show_values, do: 8, else: 0
    bar_width = max(1, width - max_label_len - value_width - 2)

    rows =
      data
      |> Enum.with_index()
      |> Enum.map(fn {item, index} ->
        # Label (truncated if needed)
        label =
          if show_labels do
            truncated = String.slice(item.label, 0, @max_label_length)
            String.pad_trailing(truncated, max_label_len) <> " "
          else
            ""
          end

        # Bar
        bar_length = VizHelper.normalize_and_scale(item.value, 0, max_value, bar_width)
        bar_length = min(bar_length, bar_width)

        bar = VizHelper.safe_duplicate(bar_char, bar_length)
        empty_part = VizHelper.safe_duplicate(@empty_char, bar_width - bar_length)

        # Value
        value_str =
          if show_values do
            " " <> VizHelper.format_number(item.value)
          else
            ""
          end

        line = label <> bar <> empty_part <> value_str

        # Apply color if specified
        color = VizHelper.cycle_color(colors, index)
        node = text(line)
        VizHelper.maybe_style(node, color)
      end)

    result = stack(:vertical, rows)
    VizHelper.maybe_style(result, style)
  end

  defp render_vertical(data, _width, height, show_values, show_labels, bar_char, colors, style) do
    values = Enum.map(data, & &1.value)
    max_value = Enum.max(values, fn -> 0 end)

    # Calculate bar heights
    bar_heights =
      Enum.map(data, fn item ->
        VizHelper.normalize_and_scale(item.value, 0, max_value, height)
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
        value_strs =
          Enum.map(data, fn item ->
            VizHelper.format_number(item.value) |> String.pad_leading(3)
          end)

        [text(Enum.join(value_strs, " "))]
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
    VizHelper.maybe_style(result, style)
  end

  defp build_bar_char(row, bar_height, index, bar_char, colors) when row < bar_height do
    color = VizHelper.cycle_color(colors, index)
    {bar_char, color}
  end

  defp build_bar_char(_row, _bar_height, _index, _bar_char, _colors) do
    {@empty_char, nil}
  end

  defp style_bar_char({char, color}) do
    padded = " " <> char <> " "
    node = text(padded)
    VizHelper.maybe_style(node, color)
  end

  @doc """
  Creates a simple horizontal bar for a single value.

  ## Options

  - `:value` - Current value (required)
  - `:max` - Maximum value (required)
  - `:width` - Bar width (default: 20, max: #{VizHelper.max_width()})
  - `:bar_char` - Bar character (default: "█")
  - `:empty_char` - Empty character (default: "░")
  """
  @spec bar(keyword()) :: TermUI.Component.RenderNode.t()
  def bar(opts) do
    value = Keyword.get(opts, :value, 0)
    max = Keyword.get(opts, :max, 100)
    width = opts |> Keyword.get(:width, 20) |> VizHelper.clamp_width()
    bar_char = Keyword.get(opts, :bar_char, @bar_char)
    empty_char = Keyword.get(opts, :empty_char, "░")

    case {VizHelper.validate_number(value), VizHelper.validate_number(max)} do
      {:ok, :ok} ->
        filled = VizHelper.normalize_and_scale(value, 0, max, width)
        filled = min(filled, width)
        empty_count = width - filled

        text(VizHelper.safe_duplicate(bar_char, filled) <> VizHelper.safe_duplicate(empty_char, empty_count))

      _ ->
        # Invalid input, return empty bar
        text(VizHelper.safe_duplicate(empty_char, width))
    end
  end
end
