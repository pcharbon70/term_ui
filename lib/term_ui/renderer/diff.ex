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

  ## Options

    * `:dirty_regions` - List of row ranges to force full redraw. Each element
      can be a single row number or a `{start_row, end_row}` tuple. Rows in
      dirty regions bypass cell-by-cell comparison and output the entire row.
      This is useful when `previous_buffer` may not match actual terminal state
      (e.g., after viewport scrolls).

  ## Examples

      {:ok, current} = Buffer.new(24, 80)
      {:ok, previous} = Buffer.new(24, 80)
      Buffer.write_string(current, 1, 1, "Hello")

      operations = Diff.diff(current, previous)
      # => [{:move, 1, 1}, {:style, %Style{}}, {:text, "Hello"}]

      # Force rows 1-5 to fully redraw (useful after scroll):
      operations = Diff.diff(current, previous, dirty_regions: [{1, 5}])
  """
  @spec diff(Buffer.t(), Buffer.t(), keyword()) :: [operation()]
  def diff(current, previous, opts \\ []) do
    dirty_regions = Keyword.get(opts, :dirty_regions, [])
    {rows, cols} = Buffer.dimensions(current)

    1..rows
    |> Enum.flat_map(fn row ->
      force_redraw = row_in_dirty_region?(row, dirty_regions)
      diff_row(current, previous, row, cols, force_redraw)
    end)
    |> optimize_operations()
  end

  # Check if a row falls within any dirty region
  defp row_in_dirty_region?(_row, []), do: false

  defp row_in_dirty_region?(row, dirty_regions) do
    Enum.any?(dirty_regions, fn
      {start_row, end_row} -> row >= start_row and row <= end_row
      single_row when is_integer(single_row) -> row == single_row
    end)
  end

  @doc """
  Detects if content scrolled between two buffer frames using row hashing.

  Compares row hashes between buffers to find the scroll offset with the best
  match ratio. This enables scroll-aware buffer synchronization without
  requiring widget cooperation.

  ## Returns

  A tuple `{scroll_amount, confidence}` where:
    * `scroll_amount` - Negative = scrolled up, positive = scrolled down, 0 = no scroll
    * `confidence` - Float 0.0-1.0 based on row match ratio

  ## Algorithm

  1. Compute a hash for each row in both buffers
  2. For each possible scroll offset k in range [-rows, +rows]:
     - Count how many rows match: `hash_current[r] == hash_previous[r - k]`
  3. Find the offset with the most matches
  4. Return `{best_offset, matches / total_rows}`

  ## Examples

      # Detect a 2-line scroll up
      {scroll_amount, confidence} = Diff.detect_scroll(current, previous)
      # => {-2, 0.6}  (60% of rows matched with offset -2)
  """
  @spec detect_scroll(Buffer.t(), Buffer.t()) :: {integer(), float()}
  def detect_scroll(current, previous) do
    {rows, _cols} = Buffer.dimensions(current)

    # Compute row hashes for both buffers
    current_hashes = compute_row_hashes(current, rows)
    previous_hashes = compute_row_hashes(previous, rows)

    # Test all possible scroll offsets and find the best match
    # Offset range: -rows to +rows (content could have shifted entirely)
    best_result =
      -rows..rows
      |> Enum.map(fn offset ->
        matches = count_matching_rows(current_hashes, previous_hashes, offset, rows)
        {offset, matches}
      end)
      |> Enum.max_by(fn {_offset, matches} -> matches end)

    {best_offset, best_matches} = best_result
    confidence = if rows > 0, do: best_matches / rows, else: 0.0

    # Only report scroll if there's meaningful confidence and offset != 0
    # Offset 0 means "no scroll detected" - if that's the best match, report it
    if best_offset == 0 do
      {0, confidence}
    else
      {best_offset, confidence}
    end
  end

  @doc """
  Computes a hash for a buffer row based on cell content and styles.

  Uses `:erlang.phash2/1` for fast, deterministic hashing.
  """
  @spec row_hash(Buffer.t(), pos_integer()) :: non_neg_integer()
  def row_hash(buffer, row) do
    cells = Buffer.get_row(buffer, row)

    # Hash the content that matters: char, fg, bg, attrs
    hash_data =
      Enum.map(cells, fn cell ->
        {cell.char, cell.fg, cell.bg, cell.attrs}
      end)

    :erlang.phash2(hash_data)
  end

  # Compute hashes for all rows, returning a map of row => hash
  defp compute_row_hashes(buffer, rows) do
    for row <- 1..rows, into: %{} do
      {row, row_hash(buffer, row)}
    end
  end

  # Count how many rows match between current and previous with given offset
  # offset < 0: content scrolled up (current row r matches previous row r - offset)
  # offset > 0: content scrolled down (current row r matches previous row r - offset)
  defp count_matching_rows(current_hashes, previous_hashes, offset, rows) do
    1..rows
    |> Enum.count(fn row ->
      prev_row = row - offset

      if prev_row >= 1 and prev_row <= rows do
        Map.get(current_hashes, row) == Map.get(previous_hashes, prev_row)
      else
        false
      end
    end)
  end

  @doc """
  Compares a single row and returns render operations for changed spans.

  When `force_redraw` is true, outputs the entire row as a single span,
  bypassing cell-by-cell comparison. This is used for dirty regions where
  the previous buffer may not accurately reflect terminal state.
  """
  @spec diff_row(Buffer.t(), Buffer.t(), pos_integer(), pos_integer(), boolean()) :: [operation()]
  def diff_row(current, previous, row, cols, force_redraw \\ false)

  # Force full row redraw - output entire row as single span
  def diff_row(current, _previous, row, cols, true = _force_redraw) do
    current_row = Buffer.get_row(current, row)

    # Skip entirely empty rows (all spaces with default style)
    if row_is_empty?(current_row) do
      []
    else
      span = %{row: row, start_col: 1, end_col: cols, cells: current_row}
      span_to_operations(span)
    end
  end

  # Normal diff - compare cells and output only changes
  def diff_row(current, previous, row, _cols, false = _force_redraw) do
    # Get all cells for the row using optimized batch lookup
    current_row = Buffer.get_row(current, row)
    previous_row = Buffer.get_row(previous, row)

    # Convert to indexed format for find_changed_spans
    current_cells =
      current_row |> Enum.with_index(1) |> Enum.map(fn {cell, col} -> {col, cell} end)

    # Build a map for quick lookup of current cells by column
    current_cells_map = Map.new(current_cells)

    previous_cells =
      previous_row |> Enum.with_index(1) |> Enum.map(fn {cell, col} -> {col, cell} end)

    # Find changed spans
    spans = find_changed_spans(current_cells, previous_cells, row)

    # Merge small gaps between spans, using actual cells from current buffer for gaps
    merged_spans = merge_spans(spans, current_cells_map)

    # Generate operations for each span
    Enum.flat_map(merged_spans, &span_to_operations/1)
  end

  # Check if a row contains only empty cells (spaces with default style)
  defp row_is_empty?(cells) do
    # Note: Cell.empty() uses fg: :default, bg: :default, NOT nil
    # Style.new() returns nil for colors, so we must match what cells actually have
    default_style = %Style{fg: :default, bg: :default, attrs: MapSet.new()}
    Enum.all?(cells, fn cell -> cell.char == " " and Style.equal?(cell_to_style(cell), default_style) end)
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

  The current_cells_map is used to fill gaps with actual cell content from
  the current buffer, rather than empty cells.
  """
  @spec merge_spans([span()], map()) :: [span()]
  def merge_spans([], _current_cells_map), do: []
  def merge_spans([span], _current_cells_map), do: [span]

  def merge_spans(spans, current_cells_map) do
    spans
    |> Enum.reduce([], fn span, acc -> merge_span_into_acc(span, acc, current_cells_map) end)
    |> Enum.reverse()
  end

  defp merge_span_into_acc(span, [], _current_cells_map), do: [span]

  defp merge_span_into_acc(span, [prev | rest], current_cells_map) do
    gap = span.start_col - prev.end_col - 1

    if gap <= @merge_gap_threshold and gap >= 0 do
      merged = create_merged_span(prev, span, gap, current_cells_map)
      [merged | rest]
    else
      [span, prev | rest]
    end
  end

  defp create_merged_span(prev, span, _gap, current_cells_map) do
    # Get actual cells from current buffer for the gap positions
    gap_cells =
      for col <- (prev.end_col + 1)..(span.start_col - 1) do
        Map.get(current_cells_map, col, Cell.empty())
      end

    %{
      row: prev.row,
      start_col: prev.start_col,
      end_col: span.end_col,
      cells: prev.cells ++ gap_cells ++ span.cells
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
    # Reset style before move to prevent style bleeding from previous position
    [:reset, {:move, row, start_col} | style_groups_to_operations(style_groups, start_col)]
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
