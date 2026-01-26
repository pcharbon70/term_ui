# Summary: Task 5.5.2 - Use CharacterSet Module in Widgets

## Overview

Task 5.5.2 updated all widgets to use the `CharacterSet` module for special characters instead of hardcoded Unicode strings. This enables automatic ASCII fallback when the terminal doesn't support Unicode characters.

## Changes Made

### CharacterSet Module Extensions

Extended `lib/term_ui/character_set.ex` with additional characters needed by widgets:

**New Box-Drawing Characters:**
- `tl_round`, `tr_round`, `bl_round`, `br_round` - Rounded corners for arc gauge and dialogs
- `h_line_heavy`, `v_line_heavy` - Heavy lines for focused split pane dividers

**New Indicator Characters:**
- `arrow_up_down` - Bidirectional arrow for scroll indicators
- `triangle_up`, `triangle_down`, `triangle_left`, `triangle_right` - Triangle indicators
- `bullet`, `bullet_empty` - Bullet points
- `pointer` - Right-pointing indicator

**New Icon Characters:**
- `info` - Information icon (ℹ)
- `warning` - Warning icon (⚠)
- `loading` - Loading spinner (⟳)
- `ellipsis` - Ellipsis (…)
- `dot` - Bullet point (•)
- `literal_question` - Question mark (?)

**New Data Visualization:**
- `sparkline_levels` - 8 Unicode levels (▁▂▃▄▅▆▇█) / 5 ASCII levels (_-=#+)

### Widgets Updated (19 files)

| Widget | Changes |
|--------|---------|
| `split_pane.ex` | Divider uses `v_line` / `v_line_heavy` from CharacterSet |
| `context_menu.ex` | Separator uses `h_line` |
| `context_menu/inline.ex` | Separator uses `h_line` |
| `alert_dialog.ex` | Box-drawing, icons via `icon_key` pattern |
| `dialog.ex` | All box-drawing characters |
| `toast.ex` | Box-drawing, icons via `icon_key` pattern |
| `gauge.ex` | Bar chars (`bar_full`, `bar_empty`), arc uses rounded corners and triangle |
| `scroll_bar.ex` | Track/thumb characters |
| `viewport.ex` | Scrollbar characters via scroll_bar |
| `bar_chart.ex` | Bar character |
| `sparkline.ex` | Dynamic `bar_characters()` function returns charset levels |
| `tree_view.ex` | Expand/collapse icons (`triangle_down`, `triangle_right`), loading indicator |
| `menu.ex` | Checkbox indicator (`check`), submenu arrows, separator line |
| `table.ex` | Sort direction arrows |
| `form_builder.ex` | Group expand indicators |
| `text_input.ex` | Scroll indicators (`arrow_up_down`) |
| `canvas.ex` | Draw functions use charset for defaults |
| `line_chart.ex` | Axis characters |

### API Changes

**alert_dialog.ex and toast.ex:**
- Changed from `icon: "ℹ"` (hardcoded string) to `icon_key: :info` (atom)
- Icon is now looked up at render time: `Map.get(chars, state.icon_key, "")`
- This allows icons to automatically adapt to the current character set

### Test Updates

Updated tests to use new API:
- `test/term_ui/widgets/alert_dialog_test.exs` - Changed `props.icon` to `props.icon_key`
- `test/term_ui/widgets/toast_test.exs` - Changed icon assertions to check `icon_key`

## Pattern Used

All widgets now follow this pattern:

```elixir
defp render_something(state) do
  chars = CharacterSet.current_charset()

  # Use characters from the charset
  border = chars.tl <> String.duplicate(chars.h_line, width) <> chars.tr

  text(border)
end
```

For icons that may vary by widget type:

```elixir
@type_icon_keys %{
  info: :info,
  success: :check,
  warning: :warning,
  error: :cross_mark
}

def new(opts) do
  type = Keyword.get(opts, :type, :info)
  %{
    icon_key: Map.get(@type_icon_keys, type, nil),
    # ...
  }
end

defp render_icon(state) do
  chars = CharacterSet.current_charset()
  icon = Map.get(chars, state.icon_key, "")
  # ...
end
```

## Test Results

The test suite passes with pre-existing failures unrelated to this task:
- Pre-existing failures in ClusterDashboard, LogViewer, and ToastManager tests
- Verified by running tests with changes stashed - same failures occur

## Files Modified

- `lib/term_ui/character_set.ex`
- `lib/term_ui/widgets/split_pane.ex`
- `lib/term_ui/widgets/context_menu.ex`
- `lib/term_ui/widgets/context_menu/inline.ex`
- `lib/term_ui/widgets/alert_dialog.ex`
- `lib/term_ui/widgets/dialog.ex`
- `lib/term_ui/widgets/toast.ex`
- `lib/term_ui/widgets/gauge.ex`
- `lib/term_ui/widgets/scroll_bar.ex`
- `lib/term_ui/widgets/viewport.ex`
- `lib/term_ui/widgets/bar_chart.ex`
- `lib/term_ui/widgets/sparkline.ex`
- `lib/term_ui/widgets/tree_view.ex`
- `lib/term_ui/widgets/menu.ex`
- `lib/term_ui/widgets/table.ex`
- `lib/term_ui/widgets/form_builder.ex`
- `lib/term_ui/widgets/text_input.ex`
- `lib/term_ui/widgets/canvas.ex`
- `lib/term_ui/widgets/line_chart.ex`
- `test/term_ui/widgets/alert_dialog_test.exs`
- `test/term_ui/widgets/toast_test.exs`
- `notes/planning/multi-renderer/phase-05-widget-adaptation.md`
- `notes/features/phase-05-task-5.5.2-use-character-set.md`

## Next Logical Task

**Task 5.5.3: Verify ASCII Fallbacks** - Test that all widgets render correctly when CharacterSet is configured for ASCII mode. This involves:
- Testing box borders render with `+`, `-`, `|` in ASCII mode
- Testing arrows render with `<`, `>`, `^`, `v` in ASCII mode
- Testing progress bars render with `#`, `-` in ASCII mode
