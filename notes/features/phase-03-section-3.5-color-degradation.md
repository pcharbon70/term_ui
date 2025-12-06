# Feature: Phase 3 Section 3.5 - Color Degradation

**Branch:** `feature/phase-03-section-3.5-color-degradation`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Implement automatic color degradation based on detected terminal capabilities. Colors are downgraded from true color to 256-color to 16-color to monochrome as needed.

## Implementation Status

After reviewing the TTY backend code, **all color degradation functionality is already implemented**:

### Task 3.5.1 - True Color Output
- [x] 3.5.1.1 Detect `color_mode == :true_color` in state
- [x] 3.5.1.2 Output RGB colors using `\e[38;2;r;g;bm` and `\e[48;2;r;g;bm`
- [x] 3.5.1.3 Pass through RGB tuples unchanged

**Implementation:** Lines 784-795 in `tty.ex`

### Task 3.5.2 - 256-Color Degradation
- [x] 3.5.2.1 Detect `color_mode == :color_256` in state
- [x] 3.5.2.2 Implement `rgb_to_256/1` mapping RGB to 256-color palette
- [x] 3.5.2.3 Use 6x6x6 color cube (indices 16-231) for colors
- [x] 3.5.2.4 Use grayscale ramp (indices 232-255) for near-gray colors
- [x] 3.5.2.5 Output using `\e[38;5;nm` and `\e[48;5;nm`

**Implementation:** Lines 799-811 and 886-898 in `tty.ex`

### Task 3.5.3 - 16-Color Degradation
- [x] 3.5.3.1 Detect `color_mode == :color_16` in state
- [x] 3.5.3.2 Implement `rgb_to_16/1` mapping RGB to nearest basic color
- [x] 3.5.3.3 Map to standard 8 colors + 8 bright variants
- [x] 3.5.3.4 Use Euclidean distance in RGB space for nearest match
- [x] 3.5.3.5 Output using standard SGR codes (30-37, 40-47, 90-97, 100-107)

**Implementation:** Lines 814-826 and 901-965 in `tty.ex`

### Task 3.5.4 - Monochrome Degradation
- [x] 3.5.4.1 Detect `color_mode == :monochrome` in state
- [x] 3.5.4.2 Skip all color sequences
- [x] 3.5.4.3 Preserve text attributes (bold, underline, reverse) for contrast
- [x] 3.5.4.4 Use reverse video for highlighting where color was used

**Implementation:** Line 829 in `tty.ex`

### Task 3.5.5 - Named Color Handling
- [x] 3.5.5.1 Pass named colors (`:red`, `:blue`, etc.) directly to SGR in 16-color mode
- [x] 3.5.5.2 Map named colors to RGB, then to palette in 256-color mode
- [x] 3.5.5.3 Pass named colors directly in true color mode (terminal handles mapping)
- [x] 3.5.5.4 Handle `:default` color in all modes with `\e[39m`/`\e[49m`

**Implementation:** Lines 834-835 and 847-880 in `tty.ex`

## Remaining Work

The implementation is complete but some **additional unit tests** are needed to match the plan requirements:

### Unit Tests - Section 3.5
- [x] Test true_color mode outputs RGB sequences unchanged (existing: line 720-729)
- [x] Test 256-color mode maps RGB to palette index (existing: line 907-918)
- [x] Test 256-color mapping uses color cube correctly
- [x] Test 256-color mapping uses grayscale for near-gray
- [x] Test 16-color mode maps to nearest basic color (existing: line 921-931)
- [x] Test monochrome mode omits color sequences (existing: line 934-946)
- [x] Test monochrome preserves text attributes
- [x] Test named colors work in all color modes
- [x] Test `:default` color resets in all modes (existing: lines 975-1003)

## Files Modified

| File | Changes |
|------|---------|
| `lib/term_ui/backend/tty.ex` | Fixed monochrome handling for named colors and palette indices |
| `test/term_ui/backend/tty_test.exs` | Added 14 new unit tests for Section 3.5 |
| `notes/planning/multi-renderer/phase-03-tty-backend.md` | Marked Section 3.5 complete |

## Success Criteria

- [x] All color degradation code implemented
- [x] All 161 unit tests pass
- [x] Section 3.5 marked complete in plan
