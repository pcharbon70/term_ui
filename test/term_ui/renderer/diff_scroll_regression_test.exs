defmodule TermUI.Renderer.DiffScrollRegressionTest do
  @moduledoc """
  Regression tests for the wide-terminal scroll corruption bug (GitHub issue #12).

  ## Root Cause

  **The diff algorithm is correct. The bug is: `previous_buffer ≠ what's actually on screen`.**

  The terminal can scroll/shift without TermUI knowing:
  - Newlines at bottom cause implicit terminal scroll
  - Autowrap at last column triggers scroll/wrap
  - Terminal resize invalidates screen contents
  - Viewport widgets scroll content without terminal awareness

  When this happens, `previous_buffer` becomes a "lie" about what's on the terminal.
  The diff correctly skips cells that match between buffers, but since the terminal
  has different content, those "skipped" cells show stale/wrong content → corruption.

  ## Test Structure

  - **"mechanism" tests**: Document HOW buffer desync causes visible corruption.
    These test correct diff behavior - the diff SHOULD skip matching cells.

  - **"bug reproduction" tests**: Simulate the actual desync scenario where
    terminal state differs from previous_buffer.

  - **"fix: dirty regions" tests**: Verify the dirty region mechanism works.
    Callers can pass `dirty_regions: [{start_row, end_row}]` to `Diff.diff/3`
    to force full row redraws, fixing the desync issue.

  See: MISSION.md, DEBUG_ESCAPE_CAPTURE.md
  """

  use ExUnit.Case, async: true

  alias TermUI.Renderer.Buffer
  alias TermUI.Renderer.Diff

  # =============================================================================
  # MECHANISM TESTS
  #
  # These tests document WHY buffer desync causes visible corruption. They test
  # CORRECT diff behavior - the diff is supposed to skip matching cells. These
  # tests will continue to pass after the fix because the fix won't change the
  # diff algorithm itself.
  # =============================================================================

  describe "mechanism: positional diff skips matching cells (correct behavior)" do
    test "diff skips cells that match between buffers" do
      # This is CORRECT behavior. The diff algorithm optimizes by only updating
      # cells that differ. When previous_buffer accurately reflects terminal
      # state, this optimization is perfect.
      #
      # The bug occurs when previous_buffer is WRONG about terminal state.
      {:ok, previous} = Buffer.new(1, 20)
      {:ok, current} = Buffer.new(1, 20)

      # Both buffers have "MATCH" in the same position
      Buffer.write_string(previous, 1, 1, "AAA MATCH BBB")
      Buffer.write_string(current, 1, 1, "XXX MATCH YYY")

      operations = Diff.diff(current, previous)

      # Extract text operations
      text_ops = Enum.filter(operations, fn {:text, _} -> true; _ -> false end)
      chars_updated = text_ops |> Enum.map(fn {:text, t} -> String.length(t) end) |> Enum.sum()

      # Diff correctly skips " MATCH " (7 chars) - this is EXPECTED
      # 13 total chars - 7 matching = 6 updated
      assert chars_updated < 13,
             "Diff should skip matching cells. Got #{chars_updated} updated, expected < 13."

      Buffer.destroy(previous)
      Buffer.destroy(current)
    end

    test "wide terminals increase probability of coincidental matches" do
      # On wide terminals (200+ columns), there are more cells, so the
      # probability of coincidental character matches increases. This makes
      # buffer desync MORE visible, not because the diff is wrong, but because
      # more cells get incorrectly skipped when previous_buffer is stale.
      {:ok, previous} = Buffer.new(1, 200)
      {:ok, current} = Buffer.new(1, 200)

      # Patterns with common substrings (spaces, "Item", ":", etc.)
      line_a =
        "Item 1: The first item in list  |Item 2: The second item here |Item 3: The third item here  |Item 4: The fourth item here|"
        |> String.pad_trailing(200)

      line_b =
        "Item 2: The second item here |Item 3: The third item here  |Item 4: The fourth item here|Item 5: The fifth item here |"
        |> String.pad_trailing(200)

      Buffer.write_string(previous, 1, 1, line_a)
      Buffer.write_string(current, 1, 1, line_b)

      operations = Diff.diff(current, previous)
      text_ops = Enum.filter(operations, fn {:text, _} -> true; _ -> false end)
      chars_updated = text_ops |> Enum.map(fn {:text, t} -> String.length(t) end) |> Enum.sum()

      chars_skipped = 200 - chars_updated

      # Many chars skipped due to coincidental matches - this is CORRECT diff behavior
      assert chars_skipped > 0,
             "Wide terminals with similar patterns should have coincidental matches. " <>
               "Got #{chars_skipped} skipped chars."

      Buffer.destroy(previous)
      Buffer.destroy(current)
    end

    test "scrolled content produces fragmented diff output" do
      # When content scrolls by one line, the diff sees different content at
      # each row position but with matching substrings. This causes fragmented
      # updates - multiple small spans instead of full row rewrites.
      {:ok, previous} = Buffer.new(3, 30)
      {:ok, current} = Buffer.new(3, 30)

      # Before scroll: rows have "AA:", "BB:", "CC:" prefixes
      Buffer.write_string(previous, 1, 1, "AA: Hello world message AA")
      Buffer.write_string(previous, 2, 1, "BB: Hello world message BB")
      Buffer.write_string(previous, 3, 1, "CC: Hello world message CC")

      # After scroll: content moved up, new line at bottom
      # ": Hello world message " matches at same positions
      Buffer.write_string(current, 1, 1, "BB: Hello world message BB")
      Buffer.write_string(current, 2, 1, "CC: Hello world message CC")
      Buffer.write_string(current, 3, 1, "DD: Hello world message DD")

      operations = Diff.diff(current, previous)

      # Count move operations (each move = start of new span)
      move_ops = Enum.filter(operations, fn {:move, _, _} -> true; _ -> false end)
      num_moves = length(move_ops)

      # Fragmented output: multiple moves per row due to gaps at matching sections
      # If we had 3 rows with no matches, we'd have exactly 3 moves
      assert num_moves > 3,
             "Scrolled content should produce fragmented diff (>3 moves for 3 rows). " <>
               "Got #{num_moves} moves."

      Buffer.destroy(previous)
      Buffer.destroy(current)
    end

    test "gap pattern matches DEBUG_ESCAPE_CAPTURE.md evidence" do
      # This recreates the escape sequence pattern from the bug report:
      # [61;6Hny[0m[61;15H unable to attend
      # Shows cursor jumping over "matching" cells (cols 8-14)
      {:ok, previous} = Buffer.new(1, 30)
      {:ok, current} = Buffer.new(1, 30)

      Buffer.write_string(previous, 1, 1, "XXX MATCH SECTION HERE YYY")
      Buffer.write_string(current, 1, 1, "AAA MATCH SECTION HERE BBB")

      operations = Diff.diff(current, previous)

      row1_moves =
        operations
        |> Enum.filter(fn {:move, 1, _col} -> true; _ -> false end)
        |> Enum.map(fn {:move, 1, col} -> col end)
        |> Enum.sort()

      # Multiple moves = gaps in output (cursor jumps over "matching" cells)
      has_gaps = length(row1_moves) > 1

      assert has_gaps,
             "Should have multiple moves (gaps) due to matching middle section. " <>
               "Move positions: #{inspect(row1_moves)}"

      Buffer.destroy(previous)
      Buffer.destroy(current)
    end
  end

  describe "mechanism: real-world patterns that expose the bug" do
    test "chat/viewport content shift" do
      # Simulates a chat viewport scrolling down by one message
      {:ok, previous} = Buffer.new(5, 30)
      {:ok, current} = Buffer.new(5, 30)

      # Frame N: messages 1-5
      Buffer.write_string(previous, 1, 1, "User A: Hello everyone!      ")
      Buffer.write_string(previous, 2, 1, "User B: How are you today?   ")
      Buffer.write_string(previous, 3, 1, "User A: I'm doing great!     ")
      Buffer.write_string(previous, 4, 1, "User C: Anyone up for games? ")
      Buffer.write_string(previous, 5, 1, "User B: Sure, count me in!   ")

      # Frame N+1: scrolled down, now messages 2-6
      Buffer.write_string(current, 1, 1, "User B: How are you today?   ")
      Buffer.write_string(current, 2, 1, "User A: I'm doing great!     ")
      Buffer.write_string(current, 3, 1, "User C: Anyone up for games? ")
      Buffer.write_string(current, 4, 1, "User B: Sure, count me in!   ")
      Buffer.write_string(current, 5, 1, "User D: What game shall we?  ")

      operations = Diff.diff(current, previous)
      text_ops = Enum.filter(operations, fn {:text, _} -> true; _ -> false end)
      chars_updated = text_ops |> Enum.map(fn {:text, t} -> String.length(t) end) |> Enum.sum()

      # Common patterns like "User ", ": ", spaces cause matches
      # Total: 5 * 30 = 150 chars, but many will be skipped
      assert chars_updated < 150,
             "Chat content should have coincidental matches. " <>
               "Updated #{chars_updated}/150 chars."

      Buffer.destroy(previous)
      Buffer.destroy(current)
    end

    test "log entries with common prefixes" do
      # Log entries have highly repetitive prefixes: timestamp, level, module
      {:ok, previous} = Buffer.new(3, 50)
      {:ok, current} = Buffer.new(3, 50)

      Buffer.write_string(previous, 1, 1, "INFO  | 2024-01-05 | Auth   | User logged in   ")
      Buffer.write_string(previous, 2, 1, "INFO  | 2024-01-05 | Auth   | Session created  ")
      Buffer.write_string(previous, 3, 1, "INFO  | 2024-01-05 | DB     | Query executed   ")

      # Scrolled: "INFO  | 2024-01-05 | " matches at positions 1-21
      Buffer.write_string(current, 1, 1, "INFO  | 2024-01-05 | Auth   | Session created  ")
      Buffer.write_string(current, 2, 1, "INFO  | 2024-01-05 | DB     | Query executed   ")
      Buffer.write_string(current, 3, 1, "INFO  | 2024-01-05 | Cache  | Entry invalidated")

      operations = Diff.diff(current, previous)
      text_ops = Enum.filter(operations, fn {:text, _} -> true; _ -> false end)

      # Many small text ops due to matching prefixes causing fragmentation
      assert length(text_ops) > 3,
             "Log entries should produce fragmented updates. " <>
               "Got #{length(text_ops)} text ops for 3 rows."

      Buffer.destroy(previous)
      Buffer.destroy(current)
    end
  end

  # =============================================================================
  # BUG REPRODUCTION
  #
  # This test simulates the ACTUAL bug scenario: terminal state differs from
  # previous_buffer. The diff operates on incorrect assumptions, producing
  # partial updates that corrupt the display.
  # =============================================================================

  describe "bug reproduction: buffer desync causes visual corruption" do
    test "diff produces corrupt output when previous_buffer doesn't match terminal" do
      # This is the REAL bug scenario:
      # 1. previous_buffer says terminal has "AAA the application menu BBB"
      # 2. We want to render "XXX the application menu YYY"
      # 3. BUT: Terminal actually has "CCC different line entirely DDD"
      #    (e.g., because it scrolled without our knowledge)
      # 4. Diff skips " the application menu " (matches between buffers)
      # 5. Result: "XXX different line YYY" - corruption!
      {:ok, previous_buffer} = Buffer.new(1, 40)
      {:ok, current_buffer} = Buffer.new(1, 40)

      # What previous_buffer THINKS is on screen
      Buffer.write_string(previous_buffer, 1, 1, "AAA the application menu BBB")

      # What we want to render
      Buffer.write_string(current_buffer, 1, 1, "XXX the application menu YYY")

      # What's ACTUALLY on the terminal (unknown to us)
      actual_terminal = "CCC different line entirely DDD" |> String.pad_trailing(40)

      operations = Diff.diff(current_buffer, previous_buffer)

      # Apply diff ops to actual terminal (simulating real render)
      {final_result, _col} =
        Enum.reduce(operations, {String.to_charlist(actual_terminal), 0}, fn op, {res, col} ->
          case op do
            {:move, _row, new_col} ->
              {res, new_col - 1}

            {:text, text} ->
              chars = String.to_charlist(text)

              new_res =
                Enum.reduce(Enum.with_index(chars), res, fn {c, i}, acc ->
                  pos = col + i
                  if pos < 40, do: List.replace_at(acc, pos, c), else: acc
                end)

              {new_res, col + length(chars)}

            _ ->
              {res, col}
          end
        end)

      displayed = List.to_string(final_result)
      expected = "XXX the application menu YYY" |> String.pad_trailing(40)

      # The diff correctly updated "XXX" and "YYY" but skipped the middle
      # because it matched between current and previous buffers.
      # But the middle of actual_terminal was DIFFERENT, so we get corruption.
      refute displayed == expected,
             "Buffer desync should cause corruption. " <>
               "Got: #{inspect(displayed)}, Expected: #{inspect(expected)}"

      Buffer.destroy(previous_buffer)
      Buffer.destroy(current_buffer)
    end
  end

  # =============================================================================
  # FIX VERIFICATION: DIRTY REGIONS
  #
  # These tests verify the dirty region fix mechanism.
  #
  # The fix: Diff.diff/3 accepts an optional dirty_regions parameter. Rows in
  # dirty regions are always fully redrawn, skipping cell-by-cell comparison.
  # =============================================================================

  describe "fix: dirty regions force full redraw" do
    test "dirty rows are fully redrawn regardless of content matches" do
      {:ok, previous} = Buffer.new(3, 30)
      {:ok, current} = Buffer.new(3, 30)

      # Content with matching middle section
      Buffer.write_string(previous, 1, 1, "AAA MATCHING CONTENT BBB")
      Buffer.write_string(current, 1, 1, "XXX MATCHING CONTENT YYY")

      # Mark row 1 as dirty - should force full redraw
      dirty_regions = [{1, 1}]

      operations = Diff.diff(current, previous, dirty_regions: dirty_regions)

      text_ops = Enum.filter(operations, fn {:text, _} -> true; _ -> false end)
      chars_updated = text_ops |> Enum.map(fn {:text, t} -> String.length(t) end) |> Enum.sum()

      # With dirty region: entire row should be updated (30 cols = full row width)
      # Without: only "AAA" and "BBB" → "XXX" and "YYY" (6 chars)
      assert chars_updated == 30,
             "Dirty row should be fully redrawn. " <>
               "Expected 30 chars (full row), got #{chars_updated}."

      Buffer.destroy(previous)
      Buffer.destroy(current)
    end

    test "non-dirty rows still use optimized diff" do
      {:ok, previous} = Buffer.new(3, 30)
      {:ok, current} = Buffer.new(3, 30)

      # Row 1: identical - should produce no ops
      Buffer.write_string(previous, 1, 1, "Unchanged content here")
      Buffer.write_string(current, 1, 1, "Unchanged content here")

      # Row 2: different - should produce ops
      Buffer.write_string(previous, 2, 1, "Old text")
      Buffer.write_string(current, 2, 1, "New text")

      # Only row 2 dirty - but row 1 is identical so should have no ops regardless
      dirty_regions = [{2, 2}]

      operations = Diff.diff(current, previous, dirty_regions: dirty_regions)

      # Row 1 should have no moves (identical, not dirty)
      row1_ops = Enum.filter(operations, fn {:move, 1, _} -> true; _ -> false end)

      assert row1_ops == [],
             "Identical non-dirty row should have no operations. " <>
               "Got: #{inspect(row1_ops)}"

      Buffer.destroy(previous)
      Buffer.destroy(current)
    end

    test "viewport scroll marks entire viewport dirty" do
      # When a viewport scrolls, all rows in the viewport should be marked dirty
      {:ok, previous} = Buffer.new(5, 30)
      {:ok, current} = Buffer.new(5, 30)

      # Simulate viewport scroll - content shifts but has matching patterns
      Buffer.write_string(previous, 1, 1, "Line 1: Some content here  ")
      Buffer.write_string(previous, 2, 1, "Line 2: Some content here  ")
      Buffer.write_string(previous, 3, 1, "Line 3: Some content here  ")

      Buffer.write_string(current, 1, 1, "Line 2: Some content here  ")
      Buffer.write_string(current, 2, 1, "Line 3: Some content here  ")
      Buffer.write_string(current, 3, 1, "Line 4: Some content here  ")

      # Viewport occupies rows 1-3, all should be dirty
      dirty_regions = [{1, 3}]

      operations = Diff.diff(current, previous, dirty_regions: dirty_regions)

      text_ops = Enum.filter(operations, fn {:text, _} -> true; _ -> false end)
      total_text = text_ops |> Enum.map(fn {:text, t} -> t end) |> Enum.join()

      # All 3 rows * ~27 chars should be output
      # " content here  " (15 chars) matches in each row, but dirty forces full redraw
      assert String.length(total_text) >= 75,
             "All dirty viewport rows should be fully redrawn. " <>
               "Expected >= 75 chars, got #{String.length(total_text)}."

      Buffer.destroy(previous)
      Buffer.destroy(current)
    end
  end

  # =============================================================================
  # FIX VERIFICATION: SCROLL OPERATIONS
  #
  # These tests verify scroll-aware buffer updates. When content scrolls, the
  # renderer should shift previous_buffer to match, keeping it synchronized
  # with terminal state.
  #
  # Note: This is a higher-level fix at BufferManager/Runtime, not Diff.
  # =============================================================================

  describe "fix: scroll operations synchronize previous_buffer" do
    test "scroll-up shifts previous_buffer content" do
      # When viewport scrolls up by 1 line:
      # 1. Emit terminal scroll command
      # 2. Shift previous_buffer rows up by 1
      # 3. Clear newly exposed bottom row
      # 4. Diff will now see correct previous state
      {:ok, buffer} = Buffer.new(3, 20)

      Buffer.write_string(buffer, 1, 1, "Line 1")
      Buffer.write_string(buffer, 2, 1, "Line 2")
      Buffer.write_string(buffer, 3, 1, "Line 3")

      # Scroll up by 1 line
      Buffer.scroll_region(buffer, 1, 3, -1)

      # After scroll: row 1 = old row 2, row 2 = old row 3, row 3 = cleared
      row1 = Buffer.get_row(buffer, 1) |> Enum.map(& &1.char) |> Enum.join()
      row3 = Buffer.get_row(buffer, 3) |> Enum.map(& &1.char) |> Enum.join()

      assert String.starts_with?(row1, "Line 2"),
             "After scroll up, row 1 should contain old row 2 content"

      assert String.trim(row3) == "",
             "After scroll up, row 3 should be cleared"

      Buffer.destroy(buffer)
    end

    test "scroll detection via row hashing" do
      # Detect scroll by comparing row hashes between frames
      # If hash_current[r] == hash_previous[r - k], content scrolled by k
      {:ok, previous} = Buffer.new(5, 20)
      {:ok, current} = Buffer.new(5, 20)

      # Previous frame
      Buffer.write_string(previous, 1, 1, "Alpha content")
      Buffer.write_string(previous, 2, 1, "Beta content")
      Buffer.write_string(previous, 3, 1, "Gamma content")
      Buffer.write_string(previous, 4, 1, "Delta content")
      Buffer.write_string(previous, 5, 1, "Epsilon content")

      # Current frame: scrolled up by 2
      Buffer.write_string(current, 1, 1, "Gamma content")
      Buffer.write_string(current, 2, 1, "Delta content")
      Buffer.write_string(current, 3, 1, "Epsilon content")
      Buffer.write_string(current, 4, 1, "Zeta content")
      Buffer.write_string(current, 5, 1, "Eta content")

      # Detect scroll using row hashing
      {scroll_amount, confidence} = Diff.detect_scroll(current, previous)

      assert scroll_amount == -2,
             "Should detect scroll up by 2 lines. Got: #{scroll_amount}"

      assert confidence > 0.5,
             "Scroll detection confidence should be > 50%. Got: #{confidence}"

      Buffer.destroy(previous)
      Buffer.destroy(current)
    end
  end
end
