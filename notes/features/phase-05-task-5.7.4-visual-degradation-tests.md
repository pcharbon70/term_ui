# Task 5.7.4: Visual Degradation Tests

## Problem Statement

Need to verify that widgets render correctly across different capability levels:
1. Color modes: true_color, color_256, color_16, monochrome
2. Character sets: Unicode vs ASCII
3. Combined degradation: monochrome + ASCII

This ensures the UI remains usable and visually coherent in environments with limited terminal capabilities.

## Solution Overview

Create `test/integration/visual_degradation_integration_test.exs` that tests:

1. **Color mode rendering** - Widgets use appropriate colors/attributes per mode
2. **Unicode vs ASCII** - CharacterSet fallbacks work correctly
3. **Combined degradation** - Both limitations work together

### Key Approach

Visual degradation tests verify that:
- Widgets can be rendered without errors at each capability level
- Character set configuration affects rendered characters
- Theme colors degrade appropriately (using text attributes in monochrome)
- Selection/focus remains visible in all modes

## Test Categories

### 5.7.4.1: Rendering in Each Color Mode
Test widgets render correctly in:
- `:true_color` - Full RGB colors (default modern terminals)
- `:color_256` - 256-color palette
- `:color_16` - Basic 16 ANSI colors
- `:monochrome` - No colors, attributes only (bold, underline, reverse)

Widgets to test: Menu (with selection highlighting), Gauge (with color zones), Tabs (with focus indicator)

### 5.7.4.2: Rendering with Unicode vs ASCII
Test widgets render correctly with:
- `:unicode` - Box-drawing, progress blocks, arrows, check marks
- `:ascii` - ASCII fallbacks (+, -, |, #, >, x)

Widgets to test: Gauge (bar characters), TreeView (tree lines), Table (borders)

### 5.7.4.3: Combined Degradation (Monochrome + ASCII)
Test that widgets render usably with both:
- No color support (monochrome)
- No Unicode support (ASCII only)

This is the worst-case scenario that should still produce usable output.

## Implementation Plan

1. ✅ Create planning document (this file)
2. Create `test/integration/visual_degradation_integration_test.exs`
3. Add color mode rendering tests
4. Add Unicode vs ASCII rendering tests
5. Add combined degradation tests
6. Run and verify all tests pass
7. Update phase plan
8. Create summary document

## Success Criteria

- Color mode tests pass for all 4 modes
- Unicode/ASCII tests verify correct character usage
- Combined degradation tests produce valid output
- Selection/focus remains visible in monochrome
- All tests passing

## Current Status

- ✅ Planning document created
- ✅ Test file created with 33 tests
- ✅ Color mode rendering tests (Menu, Gauge, Tabs)
- ✅ Unicode vs ASCII character set tests
- ✅ Combined degradation tests (monochrome + ASCII)
- ✅ Visual hierarchy tests (focus, selection, error states)
- ✅ Edge case tests
- ✅ All tests passing
- ✅ Phase plan updated (Task 5.7.4 and Section 5.7 marked complete)
- ✅ Implementation complete

## Technical Details

### CharacterSet Configuration
Set via `Application.put_env(:term_ui, :character_set, :ascii)` or use `CharacterSet.get(:ascii)` directly.

### Theme/Color Configuration
The Theme module uses styles which include color attributes. For monochrome testing, we verify that styles include text attributes (bold, underline, reverse) that work without color.

### Widgets for Testing
- **Menu**: Tests item highlighting, selection visibility
- **Tabs**: Tests focus indicator, tab borders
- **Gauge**: Tests bar characters, color zones
- **TreeView**: Tests tree lines, expand/collapse icons
- **Table**: Tests border rendering
