# Task 5.5.2: Use CharacterSet Module in Widgets

## Problem Statement

Widgets currently use hardcoded Unicode characters for box-drawing, arrows, and progress indicators. This prevents proper degradation to ASCII in terminals that don't support Unicode.

## Solution Overview

Update all widgets to use `CharacterSet.current_charset()` to get the appropriate characters based on terminal capabilities. This enables automatic ASCII fallback when configured.

## Widgets to Update

Based on the audit from Task 5.5.1, the following widgets need updates:

### Box-Drawing Characters
1. **split_pane.ex** - Dividers: `│`, `┃`, `─`, `━`
2. **context_menu.ex** - Separator: `─`
3. **alert_dialog.ex** - Borders: `┌`, `┐`, `└`, `┘`, `─`, `│`, `├`, `┤`
4. **dialog.ex** - Borders: `┌`, `┐`, `└`, `┘`, `─`, `│`, `├`, `┤`
5. **toast.ex** - Borders: `┌`, `┐`, `└`, `┘`, `─`, `│`
6. **gauge.ex** - Arc borders: `╭`, `╮`, `╰`, `╯`, `─`, `│`
7. **canvas.ex** - Draw functions: `─`, `│`, `┌`, `┐`, `└`, `┘`, `•`
8. **line_chart.ex** - Axis: `└`, `─`
9. **context_menu/inline.ex** - Separator: `|`, `───`

### Progress/Gauge Characters
10. **gauge.ex** - Bar: `█`, `░`, `▼`
11. **scroll_bar.ex** - Track/thumb: `░`, `█`
12. **viewport.ex** - Scrollbar: `░`, `█`
13. **bar_chart.ex** - Bar: `█`, `░`
14. **sparkline.ex** - Bars: `▁▂▃▄▅▆▇█`

### Arrows and Indicators
15. **tree_view.ex** - Expand/collapse: `▼`, `▶`, Selection: `●`, `►`, `○`, Loading: `⟳`
16. **menu.ex** - Separator: `─`, Checkbox: `×`, Submenu: `▼`, `▶`
17. **table.ex** - Sort: `▲`, `▼`
18. **form_builder.ex** - Group expand: `▶`, `▼`
19. **text_input.ex** - Scroll: `↕`, `↑`, `↓`
20. **alert_dialog.ex** - Icons: `ℹ`, `✓`, `⚠`, `✗`, `?`
21. **toast.ex** - Icons: `ℹ`, `✓`, `⚠`, `✗`
22. **supervision_tree_viewer.ex** - Status icons, type icons
23. **process_monitor.ex** - Sort: `▲`, `▼`

## Implementation Plan

### Step 1: Extend CharacterSet with Missing Characters ✅
Add any missing character definitions needed by widgets:
- Rounded corners: `╭`, `╮`, `╰`, `╯`
- Heavy lines: `┃`, `━`
- Pointer/indicator: `▼`, `▶`, `●`, `►`, `○`
- Sparkline bars: `▁▂▃▄▅▆▇`
- Sort arrows: `▲`
- Alert icons: `ℹ`, `⚠`, `⟳`
- Scroll indicator: `↕`

### Step 2: Update Box-Drawing Widgets
- [ ] split_pane.ex
- [ ] context_menu.ex
- [ ] alert_dialog.ex
- [ ] dialog.ex
- [ ] toast.ex
- [ ] gauge.ex
- [ ] canvas.ex
- [ ] line_chart.ex
- [ ] context_menu/inline.ex

### Step 3: Update Progress/Gauge Widgets
- [ ] gauge.ex (bar chars)
- [ ] scroll_bar.ex
- [ ] viewport.ex
- [ ] bar_chart.ex
- [ ] sparkline.ex

### Step 4: Update Arrow/Indicator Widgets
- [ ] tree_view.ex
- [ ] menu.ex
- [ ] table.ex
- [ ] form_builder.ex
- [ ] text_input.ex
- [ ] alert_dialog.ex (icons)
- [ ] toast.ex (icons)
- [ ] supervision_tree_viewer.ex
- [ ] process_monitor.ex

### Step 5: Test and Verify
- [ ] Run existing tests
- [ ] Verify widgets render in Unicode mode
- [ ] Verify widgets render in ASCII mode

## Technical Details

### Pattern to Use

```elixir
# Before (hardcoded)
@divider "│"

# After (using CharacterSet)
alias TermUI.CharacterSet

defp get_divider do
  CharacterSet.current_charset().v_line
end
```

For module attributes that need runtime lookup, convert to functions or calculate at render time.

## Current Status

- [x] Created planning document
- [ ] Extended CharacterSet with missing characters
- [ ] Updated widgets
- [ ] Tests pass
- [ ] Summary written
