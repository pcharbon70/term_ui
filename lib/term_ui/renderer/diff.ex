defmodule TermUI.Renderer.Diff do
  @moduledoc """
  Differential rendering algorithm for terminal UI.

  Compares current and previous buffers to produce minimal render operations.
  The algorithm identifies changed cells, groups them into spans, and generates
  operations for cursor movement, style changes, and text output.

  ## Usage

      operations = Diff.diff(current_buffer, previous_buffer)
      # => [{:move, 1, 5}, {:style, style}, {:text, "Hello"}, ...]

  ## Operation Types

    * `{:move, row, col}` - Move cursor to position
    * `{:style, style}` - Set text style (colors, attributes)
    * `{:text, string}` - Output text at current cursor position
    * `:reset` - Reset all style attributes

  ## Algorithm

  1. Iterate rows in order (row-major for efficient terminal output)
  2. For each row, find spans of changed cells
  3. Optimize spans by merging small gaps
  4. Generate render operations for each span
  5. Track style to emit deltas only
  """

  alias TermUI.Renderer.Buffer
  alias TermUI.Renderer.Cell
  alias TermUI.Renderer.DisplayWidth
  alias TermUI.Renderer.Style

  @type operation ::
          {:move, pos_integer(), pos_integer()}
          | {:style, Style.t()}
          | {:text, String.t()}
          | :reset

  @type span :: %{
          row: pos_integer(),
          start_col: pos_integer(),
          end_col: pos_integer(),
          cells: [Cell.t()]
        }

  # Minimum gap size (in columns) to merge spans
  # If gap is smaller than cursor move cost, include unchanged cells
  @merge_gap_threshold 3

  @doc """
  Compares two buffers and returns a list of render operations.

  The current buffer contains the new frame to render, and the previous
  buffer contains the last rendered frame. Only differences are output.

  ## Examples

      {:ok, current} = Buffer.new(24, 80)
      {:ok, previous} = Buffer.new(24, 80)
      Buffer.write_string(current, 1, 1, "Hello")

      operations = Diff.diff(current, previous)
      # => [{:move, 1, 1}, {:style, %Style{}}, {:text, "Hello"}]
  """
  @spec diff(Buffer.t(), Buffer.t()) :: [operation()]
  def diff(current, previous) do
    {rows, cols} = Buffer.dimensions(current)

    1..rows
    |> Enum.flat_map(fn row ->
      diff_row(current, previous, row, cols)
    end)
    |> optimize_operations()
  end

  @doc """
  Compares a single row and returns render operations for changed spans.
  """
  @spec diff_row(Buffer.t(), Buffer.t(), pos_integer(), pos_integer()) :: [operation()]
  def diff_row(current, previous, row, _cols) do
    # Get all cells for the row using optimized batch lookup
    current_row = Buffer.get_row(current, row)
    previous_row = Buffer.get_row(previous, row)

    # Convert to indexed format for find_changed_spans
    current_cells = current_row |> Enum.with_index(1) |> Enum.map(fn {cell, col} -> {col, cell} end)
    previous_cells = previous_row |> Enum.with_index(1) |> Enum.map(fn {cell, col} -> {col, cell} end)

    # Find changed spans
    spans = find_changed_spans(current_cells, previous_cells, row)

    # Merge small gaps between spans
    merged_spans = merge_spans(spans)

    # Generate operations for each span
    Enum.flat_map(merged_spans, &span_to_operations/1)
  end

  @doc """
  Finds spans of changed cells within a row.

  Returns a list of spans, where each span contains contiguous changed cells.
  """
  @spec find_changed_spans(
          [{pos_integer(), Cell.t()}],
          [{pos_integer(), Cell.t()}],
          pos_integer()
        ) :: [span()]
  def find_changed_spans(current_cells, previous_cells, row) do
    current_cells
    |> Enum.zip(previous_cells)
    |> Enum.reduce({[], nil}, fn {{col, curr}, {_col, prev}}, acc ->
      process_cell_pair(acc, col, curr, prev, row)
    end)
    |> finalize_last_span()
    |> Enum.reverse()
  end

  defp process_cell_pair({spans, current_span}, col, curr, prev, row) do
    if Cell.equal?(curr, prev) do
      close_span_if_any(spans, current_span)
    else
      extend_or_start_span(spans, current_span, col, curr, row)
    end
  end

  defp close_span_if_any(spans, nil), do: {spans, nil}
  defp close_span_if_any(spans, span), do: {[finalize_span(span) | spans], nil}

  defp extend_or_start_span(spans, nil, col, curr, row) do
    new_span = %{row: row, start_col: col, end_col: col, cells: [curr]}
    {spans, new_span}
  end

  defp extend_or_start_span(spans, span, col, curr, _row) do
    # Prepend for O(1) instead of append O(n) - reversed in finalize_span
    extended = %{span | end_col: col, cells: [curr | span.cells]}
    {spans, extended}
  end

  @doc """
  Merges adjacent spans when the gap is smaller than cursor move cost.

  This reduces cursor movements by including unchanged cells in the output
  when it's cheaper than moving the cursor around them.
  """
  @spec merge_spans([span()]) :: [span()]
  def merge_spans([]), do: []
  def merge_spans([span]), do: [span]

  def merge_spans(spans) do
    spans
    |> Enum.reduce([], fn span, acc -> merge_span_into_acc(span, acc) end)
    |> Enum.reverse()
  end

  defp merge_span_into_acc(span, []), do: [span]

  defp merge_span_into_acc(span, [prev | rest]) do
    gap = span.start_col - prev.end_col - 1

    if gap <= @merge_gap_threshold and gap >= 0 do
      merged = create_merged_span(prev, span, gap)
      [merged | rest]
    else
      [span, prev | rest]
    end
  end

  defp create_merged_span(prev, span, gap) do
    %{
      row: prev.row,
      start_col: prev.start_col,
      end_col: span.end_col,
      cells: prev.cells ++ List.duplicate(Cell.empty(), gap) ++ span.cells
    }
  end

  @doc """
  Converts a span to render operations.

  Generates move, style, and text operations for the span.
  Splits on style changes to minimize SGR sequence overhead.
  """
  @spec span_to_operations(span()) :: [operation()]
  def span_to_operations(%{row: row, start_col: start_col, cells: cells}) do
    # Split cells by style for efficient SGR output
    style_groups = group_by_style(cells)

    # Generate operations
    [{:move, row, start_col} | style_groups_to_operations(style_groups, start_col)]
  end

  @doc """
  Checks if a cell contains a wide character (display width > 1).
  """
  @spec wide_char?(Cell.t()) :: boolean()
  def wide_char?(%Cell{char: char}) do
    DisplayWidth.width(char) > 1
  end

  # Private functions

  defp finalize_span(span) do
    # Reverse cells (they were prepended for O(1) performance)
    # then handle wide characters - ensure pairs stay together
    cells = span.cells |> Enum.reverse() |> handle_wide_chars()
    %{span | cells: cells}
  end

  defp finalize_last_span({spans, nil}), do: spans
  defp finalize_last_span({spans, span}), do: [finalize_span(span) | spans]

  defp handle_wide_chars(cells) do
    # For now, just return cells as-is
    # Wide character handling will ensure both cells are included
    cells
  end

  defp group_by_style(cells) do
    cells
    |> Enum.reduce([], fn cell, acc -> add_cell_to_style_groups(cell, acc) end)
    |> Enum.reverse()
  end

  defp add_cell_to_style_groups(cell, []) do
    style = cell_to_style(cell)
    [{style, [cell]}]
  end

  defp add_cell_to_style_groups(cell, [{prev_style, prev_cells} | rest]) do
    style = cell_to_style(cell)

    if Style.equal?(style, prev_style) do
      # Prepend for O(1) instead of append O(n) - reversed in style_groups_to_operations
      [{prev_style, [cell | prev_cells]} | rest]
    else
      [{style, [cell]}, {prev_style, prev_cells} | rest]
    end
  end

  defp cell_to_style(%Cell{fg: fg, bg: bg, attrs: attrs}) do
    %Style{fg: fg, bg: bg, attrs: attrs}
  end

  defp style_groups_to_operations(groups, _start_col) do
    Enum.flat_map(groups, fn {style, cells} ->
      # Reverse cells (they were prepended for O(1) performance)
      text = cells |> Enum.reverse() |> Enum.map_join("", & &1.char)
      [{:style, style}, {:text, text}]
    end)
  end

  defp optimize_operations(operations) do
    operations
    |> merge_adjacent_text()
    |> remove_redundant_styles()
  end

  defp merge_adjacent_text(operations) do
    operations
    |> Enum.reduce([], fn op, acc ->
      case {op, acc} do
        {{:text, text1}, [{:text, text2} | rest]} ->
          [{:text, text2 <> text1} | rest]

        _ ->
          [op | acc]
      end
    end)
    |> Enum.reverse()
  end

  defp remove_redundant_styles(operations) do
    {result, _last_style} =
      Enum.reduce(operations, {[], nil}, fn op, acc -> filter_redundant_style(op, acc) end)

    Enum.reverse(result)
  end

  defp filter_redundant_style({:style, style}, {acc, last_style}) do
    if last_style && Style.equal?(style, last_style) do
      {acc, last_style}
    else
      {[{:style, style} | acc], style}
    end
  end

  defp filter_redundant_style(op, {acc, last_style}) do
    {[op | acc], last_style}
  end
end
