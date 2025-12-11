# Phase 05 Task 5.4.2: Implement Theme-Based Colors

**Branch:** `feature/phase-05-task-5.4.2-theme-based-colors`
**Base:** `multi-renderer`
**Status:** In Progress
**Date:** 2025-12-11
**Dependencies:** Task 5.4.1 (Widget Color Audit - Complete)
**Blocks:** Task 5.4.3 (Add Monochrome Fallbacks), Task 5.4.4 (Color Mode Testing)

---

## Executive Summary

This task migrates 15 widgets from hardcoded colors to the Theme API, enabling:
- Consistent visual design across the framework
- User-customizable color schemes
- Automatic color degradation based on terminal capabilities
- Improved accessibility through semantic color usage

**Scope:** 15 widgets across 3 priority phases
**Estimated Effort:** 8-12 hours
**Risk Level:** Low (existing Theme infrastructure is solid)

---

## Architecture Review

### Theme System Components

**1. Theme Module** (`lib/term_ui/theme.ex`)
- GenServer managing current theme
- ETS-cached for fast concurrent reads
- Provides:
  - `Theme.get_color/1` - Base colors (background, foreground, primary, secondary, accent)
  - `Theme.get_semantic/1` - Semantic colors (success, warning, error, info, muted)
  - `Theme.get_component_style/2` - Component variant styles (button.focused, etc.)
  - `Theme.style_from_theme/3` - Base style + overrides

**2. Style Module** (`lib/term_ui/style.ex`)
- Immutable style structs with fg/bg colors + attributes
- Color conversion:
  - `Style.convert_for_terminal/2` - Degrades colors based on capability
  - `Style.to_rgb/1`, `Style.to_named/1` - Color format conversion
- Provides semantic helpers (currently not used by widgets)

**3. Color Converter** (`lib/term_ui/color/converter.ex`)
- `rgb_to_256/1` - Maps to xterm 256-color palette
- `rgb_to_16/2` - Maps to ANSI 16 colors with perceptual weighting
- `grayscale?/1` - Detects near-grayscale colors

**4. Capabilities Module** (`lib/term_ui/capabilities.ex`)
- Detects terminal color mode
- Returns one of: `:true_color`, `:color_256`, `:color_16`, `:monochrome`

### Integration Pattern

The intended flow for widgets is:

```elixir
# 1. Get semantic color from theme
error_color = Theme.get_semantic(:error)

# 2. Create style with theme color
style = Style.new() |> Style.fg(error_color)

# 3. Convert for terminal capabilities (handled by renderer)
caps = Capabilities.get()
degraded_color = Style.convert_for_terminal(error_color, caps.color_mode)
```

**Current Reality:** Widgets skip steps 1-2 and use hardcoded colors like `:red` directly.

---

## Migration Strategy

### Phase 1: Critical Status Widgets (Priority)

**Widgets:**
1. Supervision Tree Viewer (12 color usages + status map)
2. Cluster Dashboard (14 color usages)
3. Process Monitor (15 color usages)
4. Log Viewer (17 color usages + level map)

**Rationale:** These are monitoring widgets where color conveys critical information. They also have the most complex color systems that will benefit most from theme semantic colors.

**Special Requirements:**
- Supervision Tree Viewer needs text indicators added for accessibility
- All need status color maps migrated to theme semantics
- All have selection/focus colors to migrate

**Estimated Effort:** 4-6 hours

### Phase 2: Interactive Widgets

**Widgets:**
5. Command Palette (2 color usages)
6. Form Builder (1 color usage - error)
7. Text Input (3 color usages)
8. Text Input Line (2 color usages)
9. Tree View (5 color usages)
10. Split Pane (2 color usages)
11. Dialog (1 color usage - background)

**Rationale:** These are user-facing interactive widgets with simpler color requirements. Mostly selection/focus/error states.

**Estimated Effort:** 3-4 hours

### Phase 3: Visualization Widgets

**Widgets:**
12. Gauge (3 zone colors)
13. Line Chart (example colors only)
14. Bar Chart (user-configurable)
15. Sparkline (user-configurable)

**Rationale:** These widgets are primarily user-configured. Migration involves providing theme-based defaults and documentation.

**Note:** Bar Chart and Sparkline don't have hardcoded colors, just need theme-based defaults added.

**Estimated Effort:** 1-2 hours

---

## Implementation Steps

### ✅ Step 1: Enhance Theme System (1-2 hours)

**Status:** Complete

**File:** `lib/term_ui/theme.ex`

1. Add new semantic colors:
   - `:help` - for help text (with dim attribute)
   - `:placeholder` - for input placeholders

2. Add new component styles:
   - `:item` - with variants :normal, :selected, :focused
   - `:divider` - with variants :normal, :focused
   - `:status` - with variants :running, :warning, :error, :terminated, :unknown

3. Update all three built-in themes (dark, light, high_contrast)

4. Add tests for new semantic/component colors

**Deliverables:**
- [x] Enhanced theme structure
- [x] Tests passing (42/42)
- [ ] Documentation updated (will update at end)

**Changes Made:**
- Updated semantic type to include `:help` and `:placeholder`
- Added `:item`, `:divider`, and `:status` component styles to all themes
- Updated validation to require new semantic colors
- Fixed test to include new semantic colors
- All tests passing

---

### ⏸️ Step 2: Phase 1 - Supervision Tree Viewer (2-3 hours)

**Status:** Pending
**Priority:** **CRITICAL** - Accessibility Issue

**File:** `lib/term_ui/widgets/supervision_tree_viewer.ex`

**Current Status Colors (lines 76-81):**
```elixir
@status_colors %{
  running: :green,
  restarting: :yellow,
  terminated: :red,
  undefined: :white
}
```

**Migration Steps:**

1. **Add text indicators for accessibility** (CRITICAL)
   - Enhance rendering to include text status markers
   - Add option `:show_status_text` (default: true)
   - Render format: `"● [R]"` (running), `"○ [T]"` (terminated), etc.

2. **Replace status color map with theme lookups**
   - Remove `@status_colors` module attribute
   - Create helper function `status_style/1`

3. **Migrate selection colors**
   - Replace `:blue` bg + `:white` fg with `Theme.get_component_style(:item, :selected)`

4. **Migrate header colors**
   - Replace `:cyan` with `Theme.get_semantic(:info)` or component style

5. **Add attributes for monochrome degradation**
   - Running: normal text
   - Restarting: bold
   - Terminated: reverse video
   - Unknown: dim

**Tests to Add:**
- Status colors from theme in all color modes
- Text indicators always visible
- Selection visible in monochrome

**Success Criteria:**
- [ ] Status map replaced with theme lookups
- [ ] Text indicators `[R]`, `[Y]`, `[T]`, `[U]` added
- [ ] Selection uses theme component style
- [ ] Works in all color modes (true_color/256/16/mono)

---

### ⏸️ Step 3: Phase 1 - Log Viewer (1 hour)

**Status:** Pending

**File:** `lib/term_ui/widgets/log_viewer.ex`

**Current Level Colors (lines 74-83):**
```elixir
@level_colors %{
  debug: :cyan,
  info: :green,
  notice: :blue,
  warning: :yellow,
  error: :red,
  critical: :magenta,
  alert: :red,
  emergency: :red
}
```

**Migration Steps:**

1. **Replace level color map with theme semantics**
   - Create mapping function `level_color/1`
   - Map debug → info, info → success, warning → warning, error → error, etc.

2. **Migrate selection colors**
   - Replace with theme component styles

3. **Migrate mode indicators**
   - Search mode (`:blue` bg) → theme component style
   - Filter mode (`:yellow` bg) → theme component style

4. **Note:** Already has level text (e.g., "ERROR", "WARNING") - excellent for accessibility

**Success Criteria:**
- [ ] Level color map replaced with theme lookups
- [ ] Already accessible (level text always present)
- [ ] Selection/mode colors from theme
- [ ] Works in all color modes

---

### ⏸️ Step 4: Phase 1 - Cluster Dashboard (1-2 hours)

**Status:** Pending

**File:** `lib/term_ui/widgets/cluster_dashboard.ex`

**Current Color Usage:**
- Status colors: `:green` (healthy), `:red` (down), `:yellow` (warning)
- Selection: `:blue` bg + `:white` fg
- Headers: `:cyan` with bold
- Borders: `:blue`
- Help text: `:white` with dim

**Migration Steps:**

1. **Migrate status colors to semantics**
   - Healthy/up: `Theme.get_semantic(:success)`
   - Down/error: `Theme.get_semantic(:error)`
   - Warning/no data: `Theme.get_semantic(:warning)`

2. **Enhance status text indicators**
   - Already has text (e.g., "UP", "DOWN")
   - Add symbols: `"● UP"`, `"○ DOWN"`

3. **Migrate selection, headers, borders**
   - Use theme component styles

**Success Criteria:**
- [ ] All status colors use theme semantics
- [ ] Selection uses theme component style
- [ ] Status visible in all color modes

---

### ⏸️ Step 5: Phase 1 - Process Monitor (1-2 hours)

**Status:** Pending

**File:** `lib/term_ui/widgets/process_monitor.ex`

**Current Color Usage:**
- High memory/queue: `:red` with bold
- Moderate levels: `:yellow`
- Headers: `:cyan` with bold
- Selection: `:blue` bg + `:white` fg

**Migration Steps:**

1. **Migrate threshold colors**
   - High/critical: `Theme.get_semantic(:error)` + bold
   - Medium/warning: `Theme.get_semantic(:warning)`

2. **Add text threshold indicators**
   - Format: `"Queue: 1000 [HIGH]"` or `"Memory: 50MB [MED]"`

3. **Migrate selection, headers**
   - Use theme component styles

**Success Criteria:**
- [ ] Threshold colors use theme semantics
- [ ] Text indicators added: `[HIGH]`, `[MED]`
- [ ] Works in all color modes

---

### ⏸️ Step 6: Phase 2 - Interactive Widgets (3-4 hours)

**Status:** Pending

**Order (by complexity):**
1. Form Builder (15 min) - 1 color only
2. Dialog (15 min) - 1 color only
3. Split Pane (30 min) - 2 colors
4. Command Palette (30 min) - 2 colors
5. Text Input + Line (1 hour) - Coordinate both
6. Tree View (1 hour) - 5 colors

**Process:** For each widget, migrate colors to theme API and add tests

---

### ⏸️ Step 7: Phase 3 - Visualization Widgets (1-2 hours)

**Status:** Pending

**Widgets:**
- Gauge - Provide theme-based default zones
- Line Chart - Documentation updates
- Bar Chart - Documentation updates
- Sparkline - Documentation updates

---

### ⏸️ Step 8: Documentation & Testing (1 hour)

**Status:** Pending

1. Update widget documentation
2. Create theme usage guide
3. Final integration testing
4. Update examples

**Deliverables:**
- [ ] Widget docs updated
- [ ] Theme usage guide
- [ ] Examples updated

---

## Testing Strategy

### Test Coverage by Color Mode

**Required Tests per Widget:**
```elixir
describe "color modes" do
  test "renders with true_color mode"
  test "renders with color_256 mode"
  test "renders with color_16 mode"
  test "renders with monochrome mode"
end
```

### Critical Accessibility Tests

**Supervision Tree Viewer:**
```elixir
test "status visible without color" do
  # Verify text indicators present: "[R]", "[T]", etc.
  # Verify status distinguishable by attributes
end
```

**Process Monitor:**
```elixir
test "thresholds visible without color" do
  # Verify threshold text: "[HIGH]", "[MED]"
end
```

---

## Success Criteria

### Functional Requirements

- [ ] All 15 widgets use Theme API for colors
- [ ] Zero hardcoded colors remain in migrated widgets
- [ ] All widgets work in all color modes (true_color/256/16/mono)
- [ ] Supervision Tree Viewer has text status indicators
- [ ] Process Monitor has threshold text indicators
- [ ] Selection is visible in all widgets in all modes
- [ ] Theme changes propagate to all widgets

### Accessibility Requirements

- [ ] Supervision Tree Viewer status clear without color
- [ ] Process Monitor thresholds clear without color
- [ ] All status information has non-color indicators
- [ ] Monochrome mode tested and verified
- [ ] High contrast theme tested

### Testing Requirements

- [ ] All existing tests pass
- [ ] Color mode tests added for all migrated widgets
- [ ] Theme integration tests pass
- [ ] Manual testing in multiple terminals

### Documentation Requirements

- [ ] Theme API usage documented
- [ ] Widget docs updated
- [ ] Examples use theme colors
- [ ] Degradation behavior documented

---

## Helper Function Templates

### Status Color Helper

```elixir
defp status_color(status) do
  case status do
    :running -> Theme.get_component_style(:status, :running)
    :warning -> Theme.get_component_style(:status, :warning)
    :error -> Theme.get_component_style(:status, :error)
    _ -> Theme.get_component_style(:status, :unknown)
  end
end

defp status_style(status, text) do
  color = status_color(status)
  indicator = status_indicator(status)
  {color, "#{indicator} #{text}"}
end

defp status_indicator(:running), do: "[R]"
defp status_indicator(:warning), do: "[W]"
defp status_indicator(:error), do: "[E]"
defp status_indicator(:terminated), do: "[T]"
defp status_indicator(_), do: "[?]"
```

### Threshold Color Helper

```elixir
defp threshold_style(value, thresholds) do
  cond do
    value >= thresholds.critical ->
      {Theme.get_semantic(:error), "[HIGH]"}
    value >= thresholds.warning ->
      {Theme.get_semantic(:warning), "[MED]"}
    true ->
      {Theme.get_color(:foreground), ""}
  end
end
```

---

## Current Status

**Last Updated:** 2025-12-11
**Progress:** Planning Complete - Ready to begin Step 1

**Next Action:** Enhance Theme System with new semantic colors and component styles
