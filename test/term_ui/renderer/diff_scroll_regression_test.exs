defmodule TermUI.Renderer.DiffScrollRegressionTest do
  @moduledoc """
  Regression tests for the wide-terminal scroll corruption bug (GitHub issue #12).

  ## Root Cause (Revised Understanding)

  **The diff algorithm is correct. The bug is: `previous_buffer ≠ what's actually on screen`.**

  The terminal can scroll/shift without TermUI knowing:
  - Newlines at bottom cause implicit terminal scroll
  - Autowrap at last column triggers scroll/wrap
  - Terminal resize invalidates screen contents

  When this happens, `previous_buffer` becomes a "lie" about what's on the terminal.
  The diff correctly skips cells that match between buffers, but since the terminal
  has different content, those "skipped" cells show stale/wrong content → corruption.

  ## What These Tests Demonstrate

  These tests simulate scenarios where `previous_buffer` and `current_buffer` have
  matching cells that the diff skips. In the real bug, these matches occur because:
  1. Terminal scrolled (changing what's on screen)
  2. `previous_buffer` wasn't updated to match
  3. `current_buffer` has new content that coincidentally matches old `previous_buffer` cells

  The fix should ensure `previous_buffer` always matches actual terminal state, OR
  detect desync and force full redraw.

  See: MISSION.md, DEBUG_ESCAPE_CAPTURE.md
  """

  use ExUnit.Case, async: true

  alias TermUI.Renderer.Buffer
  alias TermUI.Renderer.Diff

  describe "regression: scroll corruption bug (GitHub issue #12)" do
    test "cells with coincidentally matching characters after scroll are not updated" do
      {:ok, previous} = Buffer.new(3, 20)
      {:ok, current} = Buffer.new(3, 20)

      # Simulate BEFORE scroll - row 1 has "Any member unable..."
      Buffer.write_string(previous, 1, 1, "Any member unable...")

      # Simulate AFTER scroll - row 1 now has DIFFERENT logical content
      # but some characters happen to match at same positions
      # (e.g., spaces, common letters)
      Buffer.write_string(current, 1, 1, "  - member of Ereal")
      #                                    ^^ spaces and "member" match positions

      operations = Diff.diff(current, previous)

      # Extract what gets updated on row 1
      text_ops = Enum.filter(operations, fn {:text, _} -> true; _ -> false end)
      chars_updated = text_ops |> Enum.map(fn {:text, t} -> String.length(t) end) |> Enum.sum()

      # BUG: Only some chars updated (the ones that differ character-by-character)
      # EXPECTED: All 19 chars should be updated (it's a different logical line)
      #
      # This test PASSES with buggy code (documenting current behavior)
      # After fix, change to: assert chars_updated == 19
      assert chars_updated < 19,
             "If this fails, the scroll corruption bug may be fixed! " <>
               "Update this test to verify correct behavior."

      Buffer.destroy(previous)
      Buffer.destroy(current)
    end

    test "wide terminal increases probability of accidental matches" do
      # Wide terminals (200+ cols) have more cells = more chance of matches
      {:ok, previous} = Buffer.new(1, 200)
      {:ok, current} = Buffer.new(1, 200)

      # Design strings that INTENTIONALLY share characters at same positions
      # This simulates what happens when content scrolls - different logical
      # lines that happen to have same chars at same columns
      #
      # Pattern: "Item X: description here..." where X changes but surrounding matches
      line_a =
        "Item 1: The first item in list  |Item 2: The second item here |Item 3: The third item here  |Item 4: The fourth item here|"
        |> String.pad_trailing(200)

      line_b =
        "Item 2: The second item here |Item 3: The third item here  |Item 4: The fourth item here|Item 5: The fifth item here |"
        |> String.pad_trailing(200)

      # Many characters match: "Item ", ": The ", "item ", "here", "|", spaces
      Buffer.write_string(previous, 1, 1, line_a)
      Buffer.write_string(current, 1, 1, line_b)

      operations = Diff.diff(current, previous)
      text_ops = Enum.filter(operations, fn {:text, _} -> true; _ -> false end)
      chars_updated = text_ops |> Enum.map(fn {:text, t} -> String.length(t) end) |> Enum.sum()

      # Count how many chars are skipped (accidental matches)
      chars_skipped = 200 - chars_updated

      # On wide terminals with similar content patterns, we expect accidental matches
      # These skipped chars = visual corruption (old content remains visible)
      #
      # After fix, change to: assert chars_skipped == 0
      assert chars_skipped > 0,
             "If this fails, the wide terminal corruption bug may be fixed! " <>
               "Expected some accidental matches, got #{chars_skipped} skipped chars. " <>
               "Update this test to verify correct behavior."

      Buffer.destroy(previous)
      Buffer.destroy(current)
    end

    test "scrolling content by one line causes partial updates" do
      # Simulates the exact scenario from DEBUG_ESCAPE_CAPTURE.md
      {:ok, previous} = Buffer.new(3, 30)
      {:ok, current} = Buffer.new(3, 30)

      # Design content where scrolling causes character matches at same positions
      # Use identical prefixes that will match after scroll
      #
      # Before scroll:
      # Row 1: "AA: Hello world message AA"
      # Row 2: "BB: Hello world message BB"
      # Row 3: "CC: Hello world message CC"
      Buffer.write_string(previous, 1, 1, "AA: Hello world message AA")
      Buffer.write_string(previous, 2, 1, "BB: Hello world message BB")
      Buffer.write_string(previous, 3, 1, "CC: Hello world message CC")

      # After scroll (content moved up by 1):
      # Row 1: "BB: Hello world message BB" (was row 2)
      # Row 2: "CC: Hello world message CC" (was row 3)
      # Row 3: "DD: Hello world message DD" (new)
      #
      # Positions 4-25 (": Hello world message ") are IDENTICAL
      # Only positions 1-2 and 26-27 differ
      Buffer.write_string(current, 1, 1, "BB: Hello world message BB")
      Buffer.write_string(current, 2, 1, "CC: Hello world message CC")
      Buffer.write_string(current, 3, 1, "DD: Hello world message DD")

      operations = Diff.diff(current, previous)

      # Count move operations (each move = start of a new span to update)
      move_ops = Enum.filter(operations, fn {:move, _, _} -> true; _ -> false end)

      # With the bug: Multiple small spans per row (gaps where chars matched)
      # Each row should have 2 moves: one for "XX" prefix, one for "XX" suffix
      # So 3 rows * 2 spans = 6 moves minimum
      #
      # Expected after fix: One span per row (full row updates) = 3 moves
      num_moves = length(move_ops)

      # BUG: More moves than rows indicates fragmented updates
      # After fix, change to: assert num_moves == 3
      assert num_moves > 3,
             "If this fails with num_moves <= 3, the bug may be fixed! " <>
               "Got #{num_moves} move operations for 3 rows. " <>
               "Update this test to verify correct behavior."

      Buffer.destroy(previous)
      Buffer.destroy(current)
    end

    test "escape sequence gap pattern from DEBUG_ESCAPE_CAPTURE.md" do
      # Reproduces the exact pattern: [61;6Hny[0m[61;15H unable to attend
      # This showed "ny" at col 6, then jump to col 15 for " unable to attend"
      # Columns 8-14 were SKIPPED (showed old content)

      {:ok, previous} = Buffer.new(1, 30)
      {:ok, current} = Buffer.new(1, 30)

      # Design strings where middle section matches exactly
      # Previous: "XXX MATCH SECTION YYY"
      # Current:  "AAA MATCH SECTION BBB"
      # The " MATCH SECTION " part is identical, causing a gap

      Buffer.write_string(previous, 1, 1, "XXX MATCH SECTION HERE YYY")
      Buffer.write_string(current, 1, 1, "AAA MATCH SECTION HERE BBB")
      #                                   123456789012345678901234567
      #                                      ^                   ^
      #                                   Positions 4-22 match exactly

      operations = Diff.diff(current, previous)

      # Find all move operations for row 1
      row1_moves =
        operations
        |> Enum.filter(fn
          {:move, 1, _col} -> true
          _ -> false
        end)
        |> Enum.map(fn {:move, 1, col} -> col end)
        |> Enum.sort()

      # BUG: Multiple moves indicate gaps (cursor jumping over "matching" cells)
      # Expected: Move to col 1 for "AAA", then jump to col 24 for "BBB"
      # After fix: Should be single move to col 1 (full line update)
      has_gaps = length(row1_moves) > 1

      assert has_gaps,
             "If this fails, the gap pattern bug may be fixed! " <>
               "Move positions: #{inspect(row1_moves)}. " <>
               "Expected multiple moves (gaps), got single continuous update."

      Buffer.destroy(previous)
      Buffer.destroy(current)
    end
  end

  describe "viewport scroll scenario" do
    test "simulates viewport content shift causing fragmented diff" do
      # This test simulates what happens in a real Viewport widget:
      # - Frame N: Viewport shows lines 1-5 of content
      # - Frame N+1: User scrolls, viewport shows lines 2-6
      # - Content at each row position is different, but characters may match

      {:ok, previous} = Buffer.new(5, 30)
      {:ok, current} = Buffer.new(5, 30)

      # Frame N: Viewport shows messages 1-5
      # Each message has format "User X: message text here"
      Buffer.write_string(previous, 1, 1, "User A: Hello everyone!      ")
      Buffer.write_string(previous, 2, 1, "User B: How are you today?   ")
      Buffer.write_string(previous, 3, 1, "User A: I'm doing great!     ")
      Buffer.write_string(previous, 4, 1, "User C: Anyone up for games? ")
      Buffer.write_string(previous, 5, 1, "User B: Sure, count me in!   ")

      # Frame N+1: User scrolled down by 1, now showing messages 2-6
      # Row 1 now has what was row 2, etc.
      Buffer.write_string(current, 1, 1, "User B: How are you today?   ")
      Buffer.write_string(current, 2, 1, "User A: I'm doing great!     ")
      Buffer.write_string(current, 3, 1, "User C: Anyone up for games? ")
      Buffer.write_string(current, 4, 1, "User B: Sure, count me in!   ")
      Buffer.write_string(current, 5, 1, "User D: What game shall we?  ")

      operations = Diff.diff(current, previous)

      # Count how many cells are updated
      text_ops = Enum.filter(operations, fn {:text, _} -> true; _ -> false end)
      chars_updated = text_ops |> Enum.map(fn {:text, t} -> String.length(t) end) |> Enum.sum()

      # Total cells in buffer: 5 rows * 30 cols = 150
      # If every cell is updated, chars_updated = 150
      # With the bug, common substrings like "User ", ": ", spaces won't be updated

      # BUG: Only ~some chars updated due to matching patterns
      # After fix with dirty regions: All 150 chars should be updated
      assert chars_updated < 150,
             "If this fails, viewport scroll handling may be fixed! " <>
               "Expected fewer than 150 chars due to matches, got #{chars_updated}."

      Buffer.destroy(previous)
      Buffer.destroy(current)
    end

    test "log-like content with matching prefixes shows fragmented updates" do
      # Real-world scenario: Log entries with similar prefixes
      # Common patterns like "INFO ", "2024-", spaces create matches

      {:ok, previous} = Buffer.new(3, 50)
      {:ok, current} = Buffer.new(3, 50)

      # Frame N: Log entries with common prefix pattern
      # "INFO  | 2024-01-0X | Module | Message"
      Buffer.write_string(previous, 1, 1, "INFO  | 2024-01-05 | Auth   | User logged in   ")
      Buffer.write_string(previous, 2, 1, "INFO  | 2024-01-05 | Auth   | Session created  ")
      Buffer.write_string(previous, 3, 1, "INFO  | 2024-01-05 | DB     | Query executed   ")

      # Frame N+1: Scrolled down
      # Positions 1-6 ("INFO  "), 8-17 ("2024-01-05"), 19 ("|"), 28 ("|") all match!
      Buffer.write_string(current, 1, 1, "INFO  | 2024-01-05 | Auth   | Session created  ")
      Buffer.write_string(current, 2, 1, "INFO  | 2024-01-05 | DB     | Query executed   ")
      Buffer.write_string(current, 3, 1, "INFO  | 2024-01-05 | Cache  | Entry invalidated")

      operations = Diff.diff(current, previous)

      # Count text operations to see how fragmented the updates are
      text_ops = Enum.filter(operations, fn {:text, _} -> true; _ -> false end)

      # With bug: Many small text operations due to matching prefixes
      # After fix: Should be 3 text operations (one per row, full content)
      assert length(text_ops) > 3,
             "If this fails with #{length(text_ops)} text ops, log prefix matching may be handled! " <>
               "Expected fragmented updates (>3 text ops) due to matching INFO/date prefixes."

      Buffer.destroy(previous)
      Buffer.destroy(current)
    end
  end

  describe "documentation: why the bug matters" do
    test "demonstrates buffer desync causing visual corruption" do
      # REVISED: The diff is CORRECT. The bug is previous_buffer != terminal screen.
      #
      # This test simulates the REAL bug scenario:
      # 1. Terminal has scrolled (content shifted up)
      # 2. previous_buffer still has OLD positions
      # 3. current_buffer has NEW content at NEW positions
      # 4. Diff skips cells that "match" between buffers
      # 5. But terminal screen doesn't match previous_buffer → corruption

      {:ok, previous_buffer} = Buffer.new(1, 40)
      {:ok, current_buffer} = Buffer.new(1, 40)

      # What previous_buffer THINKS is on screen (from last render)
      Buffer.write_string(previous_buffer, 1, 1, "AAA the application menu BBB")

      # What we want to render now
      Buffer.write_string(current_buffer, 1, 1, "XXX the application menu YYY")

      # BUT: The terminal has SCROLLED since last render!
      # The ACTUAL terminal screen has DIFFERENT content than previous_buffer
      # Simulating: terminal scrolled, so row 1 now shows what was row 2
      actual_terminal_screen = "CCC different line entirely DDD" |> String.pad_trailing(40)

      operations = Diff.diff(current_buffer, previous_buffer)

      # Apply diff operations to the ACTUAL terminal screen
      # (This is what really happens - we write to the real terminal)
      result = String.to_charlist(actual_terminal_screen)

      {final_result, _col} =
        Enum.reduce(operations, {result, 0}, fn op, {res, col} ->
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

      # BUG: The diff only updated positions where previous_buffer != current_buffer
      # But previous_buffer was a LIE about what's on the terminal
      # So the middle section wasn't updated (diff thought it "matched")
      # Result: We see a mix of actual_terminal_screen + partial updates
      #
      # After fix, the renderer should detect the desync and force full redraw
      refute displayed == expected,
             "If this fails, the buffer desync bug may be fixed! " <>
               "Displayed: #{inspect(displayed)}, Expected: #{inspect(expected)}"

      Buffer.destroy(previous_buffer)
      Buffer.destroy(current_buffer)
    end
  end
end
