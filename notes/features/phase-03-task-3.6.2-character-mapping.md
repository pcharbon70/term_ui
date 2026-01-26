# Feature: Phase 3 Task 3.6.2 - Character Mapping in TTY Backend

**Branch:** `feature/phase-03-task-3.6.2-character-mapping`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Integrate character set selection into TTY backend rendering. When the terminal doesn't support Unicode, box-drawing characters should be automatically converted to ASCII equivalents.

## Implementation Plan

### Task 3.6.2 - Implement Character Mapping in TTY Backend

- [x] 3.6.2.1 Store selected `character_set` in state from capabilities (already done in init)
- [x] 3.6.2.2 Implement `map_character/2` accepting character and character_set
- [x] 3.6.2.3 Replace Unicode box-drawing with ASCII equivalents when `character_set == :ascii`
- [x] 3.6.2.4 Pass through regular characters unchanged

## Design

### Approach

Create a compile-time mapping from Unicode box-drawing characters to their ASCII equivalents. The `map_character/2` function will:

1. For `:unicode` mode: pass through all characters unchanged
2. For `:ascii` mode: look up Unicode characters in the mapping and replace with ASCII equivalents

### Mapping Table

| Unicode | ASCII | Description |
|---------|-------|-------------|
| `┌` | `+` | Top-left corner |
| `┐` | `+` | Top-right corner |
| `└` | `+` | Bottom-left corner |
| `┘` | `+` | Bottom-right corner |
| `─` | `-` | Horizontal line |
| `│` | `\|` | Vertical line |
| `┬` | `+` | T-down |
| `┴` | `+` | T-up |
| `├` | `+` | T-right |
| `┤` | `+` | T-left |
| `┼` | `+` | Cross |
| `█` | `#` | Full block |
| `░` | `.` | Light shade |
| `▏▎▍▌▋▊▉` | varies | Bar levels |
| `✓` | `x` | Check mark |
| `✗` | `X` | Cross mark |
| `↑` | `^` | Up arrow |
| `↓` | `v` | Down arrow |
| `←` | `<` | Left arrow |
| `→` | `>` | Right arrow |

## Files to Modify

| File | Changes |
|------|---------|
| `lib/term_ui/backend/tty.ex` | Update `map_character/2` implementation |
| `test/term_ui/backend/tty_test.exs` | Add character mapping tests |

## Success Criteria

- [x] `map_character/2` correctly maps Unicode to ASCII in `:ascii` mode
- [x] Regular characters pass through unchanged
- [x] All existing tests still pass
- [x] New character mapping tests pass (12 tests)
