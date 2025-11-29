# Line Chart (Braille) Widget Feature

## Problem Statement

Phase 6.4.3 requires a Line Chart widget using Braille patterns for sub-character resolution. Each Braille cell is 2x4 pixels, enabling smooth lines in text mode for time series visualization.

## Solution Overview

The `TermUI.Widgets.LineChart` widget is already implemented with:
- Braille dot pattern calculation from coordinates
- Line drawing between data points (Bresenham's algorithm)
- Axis rendering with labels (optional)
- Multiple data series with colors
- Auto or manual min/max scaling

**Status**: Widget, tests, and example already exist.

## Technical Details

### Existing Files
- Widget: `lib/term_ui/widgets/line_chart.ex`
- Tests: `test/term_ui/widgets/line_chart_test.exs` (15 tests passing)
- Example: `examples/line_chart/` directory with mix project

### Braille Cell Structure
Each Braille character has 8 dots arranged as:
```
1 4
2 5
3 6
7 8
```
Unicode range: U+2800 to U+28FF (256 patterns)

### Canvas System
- Canvas dimensions: width*2 dots × height*4 dots
- Uses ETS table for dot storage
- Bresenham's line algorithm for smooth lines
- Converts dot matrix to Braille characters

## Implementation Plan

### 6.4.3.1 Braille dot pattern calculation from coordinates
- [x] @dot_bits mapping for 8 dot positions
- [x] dots_to_braille/1 converts coordinates to character
- [x] get_cell_pattern/3 reads 2x4 cell from canvas

### 6.4.3.2 Line drawing between data points
- [x] Bresenham's line algorithm implementation
- [x] draw_line/5 connects consecutive points
- [x] Points and lines both rendered

### 6.4.3.3 Axis rendering with labels
- [x] show_axis option adds axis line
- [x] └─── style axis at bottom

### 6.4.3.4 Multiple data series with colors
- [x] series option accepts list of {data, color}
- [x] Each series drawn independently
- [x] Style option for overall chart

## Success Criteria

- [x] Braille patterns calculate correctly
- [x] Lines draw smoothly between points
- [x] Axis renders when enabled
- [x] Multiple series supported
- [x] All tests pass (15 tests)
- [x] Example application demonstrates usage

## Current Status

**Completed**: All tasks done. Widget, tests, and example are complete.
