# Feature: Phase 3 Task 3.8.4 - Character Set Fallback Tests

**Branch:** `feature/phase-03-task-3.8.4-character-set-fallback-tests`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Implement integration tests for character set selection and fallback. These tests verify that the TTY backend correctly renders:
1. Unicode box-drawing characters in Unicode mode
2. ASCII fallback characters when Unicode is unavailable
3. Mixed content (regular text with box-drawing characters)

## Character Set Mapping

The TTY backend uses `TermUI.CharacterSet` to define character sets:

### Unicode Characters (`:unicode` mode)
- Box corners: `┌`, `┐`, `└`, `┘`
- Lines: `─`, `│`
- T-junctions: `┴`, `┬`, `┤`, `├`
- Cross: `┼`
- Progress: `█`, `░`
- Check marks: `✓`, `✗`
- Arrows: `↑`, `↓`, `←`, `→`

### ASCII Characters (`:ascii` mode)
- Box corners: `+` (all corners)
- Lines: `-`, `|`
- T-junctions: `+` (all junctions)
- Cross: `+`
- Progress: `#`, `.`
- Check marks: `x`, `X`
- Arrows: `^`, `v`, `<`, `>`

## Implementation Plan

### 3.8.4.1 Test Unicode box-drawing renders correctly
- [x] Test box corners render as Unicode characters
- [x] Test horizontal and vertical lines render correctly
- [x] Test T-junctions and cross render correctly
- [x] Test progress bar characters (full, empty, levels)
- [x] Test check marks and arrows

### 3.8.4.2 Test ASCII fallback renders correctly
- [x] Test box corners render as `+`
- [x] Test horizontal line renders as `-`
- [x] Test vertical line renders as `|`
- [x] Test T-junctions and cross render as `+`
- [x] Test progress bar characters render as `#` and `.`
- [x] Test check marks and arrows render as ASCII equivalents

### 3.8.4.3 Test mixed content (Unicode text with ASCII boxes)
- [x] Test regular ASCII text passes through unchanged in both modes
- [x] Test Unicode text passes through unchanged in Unicode mode
- [x] Test only box-drawing characters are mapped in ASCII mode
- [x] Test cells with mixed content on same row

## Tests Added (16 total)

### 3.8.4.1 - Unicode box-drawing (5 tests)
1. `Unicode box corners render correctly in unicode mode`
2. `Unicode horizontal and vertical lines render correctly`
3. `Unicode T-junctions and cross render correctly`
4. `Unicode progress bar characters render correctly`
5. `Unicode check marks and arrows render correctly`

### 3.8.4.2 - ASCII fallback (5 tests)
6. `ASCII fallback maps box corners to +`
7. `ASCII fallback maps horizontal line to - and vertical to |`
8. `ASCII fallback maps T-junctions and cross to +`
9. `ASCII fallback maps progress bar characters`
10. `ASCII fallback maps check marks and arrows`

### 3.8.4.3 - Mixed content (6 tests)
11. `regular ASCII text passes through unchanged in both modes`
12. `Unicode text passes through unchanged in unicode mode`
13. `non-box-drawing Unicode passes through unchanged in ascii mode`
14. `mixed content: text with box-drawing on same row in unicode mode`
15. `mixed content: text with box-drawing on same row in ascii mode`
16. `character_set state is set correctly based on capabilities`

## Test Location

Tests added to: `test/term_ui/backend/tty_test.exs`

In describe block: `describe "integration - character set fallback (Section 3.8.4)"`

## Success Criteria

- [x] All integration tests pass
- [x] Tests verify Unicode box-drawing renders correctly
- [x] Tests verify ASCII fallback maps all characters
- [x] Tests verify mixed content renders appropriately
- [x] Regular text is unaffected by character set setting
- [x] Total TTY backend tests: 228 (was 212, added 16)

## Files Modified

| File | Changes |
|------|---------|
| `test/term_ui/backend/tty_test.exs` | Add 16 integration tests for character set fallback |
| `notes/planning/multi-renderer/phase-03-tty-backend.md` | Mark task 3.8.4 complete |
