# Feature: Phase 3 Task 3.6.1 - Create Character Set Module

**Branch:** `feature/phase-03-section-3.6-character-set`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Create the `TermUI.CharacterSet` module with Unicode and ASCII character sets for box-drawing and special characters. This enables ASCII fallback when Unicode is unavailable.

## Implementation Plan

### Task 3.6.1 - Create Character Set Module

- [x] 3.6.1.1 Create `lib/term_ui/character_set.ex` with `@moduledoc`
- [x] 3.6.1.2 Define `get(:unicode)` returning map with Unicode box-drawing characters
- [x] 3.6.1.3 Define `get(:ascii)` returning map with ASCII equivalents
- [x] 3.6.1.4 Include box corners: `tl`, `tr`, `bl`, `br`
- [x] 3.6.1.5 Include lines: `h_line`, `v_line`
- [x] 3.6.1.6 Include junctions: `t_up`, `t_down`, `t_left`, `t_right`, `cross`
- [x] 3.6.1.7 Include progress/gauge characters: `bar_full`, `bar_empty`, `bar_levels`
- [x] 3.6.1.8 Include check marks: `check`, `cross_mark`
- [x] 3.6.1.9 Include arrows: `arrow_up`, `arrow_down`, `arrow_left`, `arrow_right`

## Character Mappings

### Box Drawing Characters

| Key | Unicode | ASCII | Description |
|-----|---------|-------|-------------|
| `tl` | `┌` (U+250C) | `+` | Top-left corner |
| `tr` | `┐` (U+2510) | `+` | Top-right corner |
| `bl` | `└` (U+2514) | `+` | Bottom-left corner |
| `br` | `┘` (U+2518) | `+` | Bottom-right corner |
| `h_line` | `─` (U+2500) | `-` | Horizontal line |
| `v_line` | `│` (U+2502) | `\|` | Vertical line |
| `t_up` | `┴` (U+2534) | `+` | T-junction pointing up |
| `t_down` | `┬` (U+252C) | `+` | T-junction pointing down |
| `t_left` | `┤` (U+2524) | `+` | T-junction pointing left |
| `t_right` | `├` (U+251C) | `+` | T-junction pointing right |
| `cross` | `┼` (U+253C) | `+` | Cross junction |

### Progress/Gauge Characters

| Key | Unicode | ASCII | Description |
|-----|---------|-------|-------------|
| `bar_full` | `█` (U+2588) | `#` | Full block |
| `bar_empty` | `░` (U+2591) | `.` | Light shade |
| `bar_levels` | `["▏","▎","▍","▌","▋","▊","▉","█"]` | `[" ",".",":","=","#"]` | Progress levels |

### Check Marks

| Key | Unicode | ASCII | Description |
|-----|---------|-------|-------------|
| `check` | `✓` (U+2713) | `x` | Check mark |
| `cross_mark` | `✗` (U+2717) | `X` | Cross mark |

### Arrows

| Key | Unicode | ASCII | Description |
|-----|---------|-------|-------------|
| `arrow_up` | `↑` (U+2191) | `^` | Up arrow |
| `arrow_down` | `↓` (U+2193) | `v` | Down arrow |
| `arrow_left` | `←` (U+2190) | `<` | Left arrow |
| `arrow_right` | `→` (U+2192) | `>` | Right arrow |

## Files to Create

| File | Description |
|------|-------------|
| `lib/term_ui/character_set.ex` | CharacterSet module |
| `test/term_ui/character_set_test.exs` | Unit tests |

## Success Criteria

- [x] CharacterSet module compiles without warnings
- [x] `get(:unicode)` returns complete Unicode character set
- [x] `get(:ascii)` returns complete ASCII character set
- [x] All expected keys present in both sets
- [x] Unit tests pass (33 tests)
