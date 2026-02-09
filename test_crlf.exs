#!/usr/bin/env elixir
# Run: cd examples/gauge && mix run ../../test_crlf.exs
#
# Diagnostics for the staircase rendering issue.
# Tests the FULL rendering pipeline end-to-end.

defmodule CRLFDiag do
  alias TermUI.Renderer.{Buffer, BufferManager, Cell}
  alias TermUI.Runtime.NodeRenderer

  def run do
    IO.puts("=== CRLF Diagnostic v5 ===\n")

    # --- Test A: Platform info ---
    IO.puts("--- Test A: Platform ---")
    IO.puts("WSL detected (needs_hard_reset?): #{TermUI.TerminalOutput.needs_hard_reset?()}")
    IO.puts("ONLCR active: #{TermUI.TerminalOutput.onlcr?()}")
    IO.puts("")

    # --- Test B: What cells does the gauge produce? ---
    IO.puts("--- Test B: Gauge render cell positions ---")
    test_gauge_cell_positions()
    IO.puts("")

    # --- Test C: What bytes does draw_cells emit? ---
    IO.puts("--- Test C: draw_cells byte analysis ---")
    test_draw_cells_bytes()
    IO.puts("")

    # --- Test D: Visual positioning test ---
    IO.puts("--- Test D: Visual test ---")
    IO.puts("Starting visual test in 2 seconds...")
    IO.puts("You should see lines at column 1 and ABCDEF at col 10.")
    IO.puts("If lines staircase right, the issue is in Raw.draw_cells / IO path.")
    IO.puts("If lines are correct, the issue is in the render pipeline.")
    Process.sleep(2000)
    test_visual_positioning()
  end

  defp test_gauge_cell_positions do
    # Create a buffer and render the gauge view into it
    {:ok, buffer} = Buffer.new(24, 80)
    view_tree = Gauge.App.view(%{value: 50, gauge_type: :bar})
    NodeRenderer.render_to_buffer_direct(view_tree, buffer)

    # Examine cells row by row
    for row <- 1..20 do
      cells_in_row =
        for col <- 1..80 do
          cell = Buffer.get_cell(buffer, row, col)
          {col, cell}
        end

      # Find first and last non-space cell
      non_space =
        cells_in_row
        |> Enum.filter(fn {_col, cell} -> cell.char != " " end)

      if non_space != [] do
        {first_col, _} = List.first(non_space)
        {last_col, _} = List.last(non_space)
        text = non_space |> Enum.map(fn {_, cell} -> cell.char end) |> Enum.join()
        # Truncate long text
        display = if String.length(text) > 50, do: String.slice(text, 0, 50) <> "...", else: text

        IO.puts(
          "  Row #{String.pad_leading(to_string(row), 2)}: cols #{first_col}-#{last_col} \"#{display}\""
        )
      else
        IO.puts("  Row #{String.pad_leading(to_string(row), 2)}: (empty)")
      end
    end

    # Now simulate the diff: create previous (empty) buffer and get changed cells
    {:ok, prev_buffer} = Buffer.new(24, 80)

    # Use the same logic as Runtime.get_changed_cells
    {rows, _cols} = Buffer.dimensions(buffer)

    changed_cells =
      for row <- 1..rows, reduce: [] do
        acc ->
          current_row = Buffer.get_row(buffer, row)
          previous_row = Buffer.get_row(prev_buffer, row)

          changed_in_row =
            current_row
            |> Enum.with_index(1)
            |> Enum.filter(fn {cell, col} ->
              prev_cell = Enum.at(previous_row, col - 1, Cell.empty())
              cell != prev_cell
            end)
            |> Enum.map(fn {cell, col} ->
              {{row, col}, {cell.char, cell.fg, cell.bg, MapSet.to_list(cell.attrs)}}
            end)

          changed_in_row ++ acc
      end

    sorted = Enum.sort_by(changed_cells, fn {{row, col}, _} -> {row, col} end)

    IO.puts("\n  Total changed cells: #{length(sorted)}")

    # Check: are all row 1 cells at column positions 1..N?
    row1_cells = Enum.filter(sorted, fn {{row, _}, _} -> row == 1 end)
    row1_cols = Enum.map(row1_cells, fn {{_, col}, _} -> col end)

    IO.puts(
      "  Row 1 cell columns: #{inspect(Enum.take(row1_cols, 30))}#{if length(row1_cols) > 30, do: "...", else: ""}"
    )

    # Check rows 2-5
    for row <- 2..5 do
      row_cells = Enum.filter(sorted, fn {{r, _}, _} -> r == row end)
      row_cols = Enum.map(row_cells, fn {{_, col}, _} -> col end)

      IO.puts(
        "  Row #{row} cell columns: #{inspect(Enum.take(row_cols, 30))}#{if length(row_cols) > 30, do: "...", else: ""}"
      )
    end

    Buffer.destroy(buffer)
    Buffer.destroy(prev_buffer)
  end

  defp test_draw_cells_bytes do
    # Create a minimal set of cells at known positions
    test_cells = [
      # Row 1: "AB" at col 1-2
      {{1, 1}, {"A", :default, :default, []}},
      {{1, 2}, {"B", :default, :default, []}},
      # Row 2: "CD" at col 1-2  (new row, should emit cursor position)
      {{2, 1}, {"C", :default, :default, []}},
      {{2, 2}, {"D", :default, :default, []}},
      # Row 3: "EF" at col 5-6  (new row + column offset)
      {{3, 5}, {"E", :default, :default, []}},
      {{3, 6}, {"F", :default, :default, []}}
    ]

    {:ok, state} =
      TermUI.Backend.Raw.init(
        size: {24, 80},
        alternate_screen: false,
        hide_cursor: false,
        mouse_tracking: :none
      )

    output =
      ExUnit.CaptureIO.capture_io(fn ->
        TermUI.Backend.Raw.draw_cells(state, test_cells)
      end)

    binary = IO.iodata_to_binary(output)
    bytes = :binary.bin_to_list(binary)

    IO.puts("  draw_cells output (#{byte_size(binary)} bytes): #{inspect(binary)}")
    IO.puts("  Hex: #{bytes |> Enum.map(&Integer.to_string(&1, 16)) |> Enum.join(" ")}")

    # Check for \n (0x0A) and \r (0x0D)
    lf_count = Enum.count(bytes, &(&1 == 0x0A))
    cr_count = Enum.count(bytes, &(&1 == 0x0D))
    IO.puts("  LF (0x0A) count: #{lf_count}")
    IO.puts("  CR (0x0D) count: #{cr_count}")

    # Parse out the cursor position sequences
    IO.puts("  Cursor position sequences found:")
    regex = ~r/\e\[(\d+);(\d+)H/

    Regex.scan(regex, binary)
    |> Enum.each(fn [full, row, col] ->
      IO.puts("    #{inspect(full)} → row=#{row}, col=#{col}")
    end)
  end

  defp test_visual_positioning do
    :shell.start_interactive({:noshell, :raw})

    {:ok, state} =
      TermUI.Backend.Raw.init(
        size: {24, 80},
        alternate_screen: true,
        hide_cursor: true,
        mouse_tracking: :none
      )

    cells = [
      # Row 1: "Line 1" at col 1
      {{1, 1}, {"L", :default, :default, []}},
      {{1, 2}, {"i", :default, :default, []}},
      {{1, 3}, {"n", :default, :default, []}},
      {{1, 4}, {"e", :default, :default, []}},
      {{1, 5}, {" ", :default, :default, []}},
      {{1, 6}, {"1", :default, :default, []}},
      # Row 2: "Line 2" at col 1
      {{2, 1}, {"L", :default, :default, []}},
      {{2, 2}, {"i", :default, :default, []}},
      {{2, 3}, {"n", :default, :default, []}},
      {{2, 4}, {"e", :default, :default, []}},
      {{2, 5}, {" ", :default, :default, []}},
      {{2, 6}, {"2", :default, :default, []}},
      # Row 3: "Line 3" at col 1
      {{3, 1}, {"L", :default, :default, []}},
      {{3, 2}, {"i", :default, :default, []}},
      {{3, 3}, {"n", :default, :default, []}},
      {{3, 4}, {"e", :default, :default, []}},
      {{3, 5}, {" ", :default, :default, []}},
      {{3, 6}, {"3", :default, :default, []}},
      # Row 5 (skip row 4): "Line 5" at col 1
      {{5, 1}, {"L", :default, :default, []}},
      {{5, 2}, {"i", :default, :default, []}},
      {{5, 3}, {"n", :default, :default, []}},
      {{5, 4}, {"e", :default, :default, []}},
      {{5, 5}, {" ", :default, :default, []}},
      {{5, 6}, {"5", :default, :default, []}},
      # Row 7: "ABCDEF" at col 10
      {{7, 10}, {"A", :default, :default, []}},
      {{7, 11}, {"B", :default, :default, []}},
      {{7, 12}, {"C", :default, :default, []}},
      {{7, 13}, {"D", :default, :default, []}},
      {{7, 14}, {"E", :default, :default, []}},
      {{7, 15}, {"F", :default, :default, []}},
      # Row 9: "All at col 1, backend is OK"
      {{9, 1}, {"A", :default, :default, []}},
      {{9, 2}, {"l", :default, :default, []}},
      {{9, 3}, {"l", :default, :default, []}},
      {{9, 4}, {" ", :default, :default, []}},
      {{9, 5}, {"a", :default, :default, []}},
      {{9, 6}, {"t", :default, :default, []}},
      {{9, 7}, {" ", :default, :default, []}},
      {{9, 8}, {"c", :default, :default, []}},
      {{9, 9}, {"o", :default, :default, []}},
      {{9, 10}, {"l", :default, :default, []}},
      {{9, 11}, {" ", :default, :default, []}},
      {{9, 12}, {"1", :default, :default, []}},
      # Row 11: "Press Enter"
      {{11, 1}, {"P", :default, :default, []}},
      {{11, 2}, {"r", :default, :default, []}},
      {{11, 3}, {"e", :default, :default, []}},
      {{11, 4}, {"s", :default, :default, []}},
      {{11, 5}, {"s", :default, :default, []}},
      {{11, 6}, {" ", :default, :default, []}},
      {{11, 7}, {"E", :default, :default, []}},
      {{11, 8}, {"n", :default, :default, []}},
      {{11, 9}, {"t", :default, :default, []}},
      {{11, 10}, {"e", :default, :default, []}},
      {{11, 11}, {"r", :default, :default, []}}
    ]

    TermUI.Backend.Raw.draw_cells(state, cells)

    # Wait for any keypress
    IO.read(:stdio, 1)
    TermUI.Backend.Raw.shutdown(state)
    :shell.start_interactive({:noshell, :cooked})
  end
end

CRLFDiag.run()
