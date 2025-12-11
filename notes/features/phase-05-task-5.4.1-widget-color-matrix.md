# Widget Color Usage Matrix

**Date:** 2025-12-11
**Purpose:** Quick reference for theme migration and degradation planning

---

## Master Widget Color Matrix

| # | Widget | File | Has Colors | Theme Ready | Degradable | Mono Ready | Priority | Notes |
|---|--------|------|-----------|-------------|------------|-----------|----------|-------|
| 1 | Cluster Dashboard | cluster_dashboard.ex | ✅ (14) | ❌ | ⚠️ Partial | ⚠️ Partial | **P1 Critical** | Status colors, needs semantic theme colors |
| 2 | Supervision Tree Viewer | supervision_tree_viewer.ex | ✅ (12+map) | ❌ | ⚠️ Partial | ❌ No | **P1 Critical** | Status map, needs text indicators |
| 3 | Process Monitor | process_monitor.ex | ✅ (15) | ❌ | ⚠️ Partial | ⚠️ Partial | **P1 High** | Threshold colors, needs text indicators |
| 4 | Log Viewer | log_viewer.ex | ✅ (17+map) | ❌ | ✅ Yes | ✅ Yes | P1 High | Level map, already accessible |
| 5 | Tree View | tree_view.ex | ✅ (5) | ❌ | ✅ Yes | ✅ Yes | P2 Medium | Selection/highlight colors |
| 6 | Command Palette | command_palette.ex | ✅ (2) | ❌ | ✅ Yes | ⚠️ Partial | P2 Medium | Selection color, add reverse |
| 7 | Form Builder | form_builder.ex | ✅ (1) | ❌ | ✅ Yes | ✅ Yes | P2 Medium | Error color only, well-designed |
| 8 | Text Input | text_input.ex | ✅ (3) | ❌ | ✅ Yes | ✅ Yes | P2 Medium | Focus/placeholder colors |
| 9 | Text Input Line | text_input/line.ex | ✅ (2) | ❌ | ✅ Yes | ✅ Yes | P2 Medium | Same as TextInput |
| 10 | Split Pane | split_pane.ex | ✅ (2) | ❌ | ✅ Yes | ✅ Yes | P2 Medium | Divider focus color |
| 11 | Dialog | dialog.ex | ✅ (1) | ❌ | ✅ Yes | ✅ Yes | P2 Medium | Background only |
| 12 | Gauge | gauge.ex | ✅ (3 zones) | ❌ | ✅ Yes | ⚠️ Partial | P3 Low | User-configurable, needs defaults |
| 13 | Line Chart | line_chart.ex | ⚠️ Example | ❌ | ⚠️ Partial | ❌ No | P3 Low | Multi-series needs line styles |
| 14 | Visualization Helper | visualization_helper.ex | ⚠️ Docs | ❌ | N/A | N/A | P4 Ignore | Documentation examples only |
| 15 | Widget Helpers | widget_helpers.ex | ⚠️ Example | ❌ | N/A | N/A | P4 Ignore | Example code only |
| 16 | Context Menu | context_menu.ex | ❌ | ❌ | ✅ Yes | ✅ Yes | - | No colors needed |
| 17 | Context Menu Inline | context_menu/inline.ex | ❌ | ❌ | ✅ Yes | ✅ Yes | - | No colors needed |
| 18 | Menu | menu.ex | ❌ | ❌ | ✅ Yes | ✅ Yes | - | No colors needed |
| 19 | Alert Dialog | alert_dialog.ex | ❌ | ❌ | ✅ Yes | ✅ Yes | - | No colors needed |
| 20 | Tabs | tabs.ex | ❌ | ❌ | ✅ Yes | ✅ Yes | - | No colors needed |
| 21 | Table | table.ex | ❌ | ❌ | ✅ Yes | ✅ Yes | - | No colors needed |
| 22 | Toast | toast.ex | ❌ | ❌ | ✅ Yes | ✅ Yes | - | No colors needed |
| 23 | Pick List | pick_list.ex | ❌ | ❌ | ✅ Yes | ✅ Yes | - | No colors needed |
| 24 | Viewport | viewport.ex | ❌ | ❌ | ✅ Yes | ✅ Yes | - | No colors needed |
| 25 | Scroll Bar | scroll_bar.ex | ❌ | ❌ | ✅ Yes | ✅ Yes | - | No colors needed |
| 26 | Canvas | canvas.ex | ❌ | ❌ | ✅ Yes | ✅ Yes | - | User-controlled content |
| 27 | Bar Chart | bar_chart.ex | ❌ | ❌ | ⚠️ User | ⚠️ User | P3 Low | User-configurable |
| 28 | Sparkline | sparkline.ex | ❌ | ❌ | ⚠️ User | ⚠️ User | P3 Low | User-configurable |

---

## Legend

### Has Colors
- ✅ (N) - Widget uses N hardcoded colors
- ❌ - No hardcoded colors
- ⚠️ Example/Docs - Only in examples/documentation

### Theme Ready
- ✅ Yes - Uses Theme API
- ❌ No - Uses hardcoded colors
- N/A - Not applicable

### Degradable
- ✅ Yes - Colors degrade gracefully to 16/mono
- ⚠️ Partial - Some color information loss
- ❌ No - Significant information loss
- ⚠️ User - Depends on user configuration

### Mono Ready
- ✅ Yes - Works well in monochrome
- ⚠️ Partial - Some visual distinction lost
- ❌ No - Critical information unclear
- ⚠️ User - Depends on user configuration

### Priority
- **P1 Critical** - Monitoring/status widgets, accessibility concern
- **P1 High** - Interactive widgets, user-facing
- P2 Medium - Supporting widgets, enhancements
- P3 Low - Configuration/visualization widgets
- P4 Ignore - Examples/documentation only

---

## Quick Filters

### Needs Theme Migration (Priority 1)
1. Supervision Tree Viewer (Critical - status colors)
2. Cluster Dashboard (Critical - status colors)
3. Process Monitor (High - threshold colors)
4. Log Viewer (High - level colors)

### Needs Accessibility Improvements (Monochrome)
1. Supervision Tree Viewer - Add status text indicators
2. Line Chart - Add line styles for multi-series
3. Process Monitor - Add threshold text indicators
4. Gauge - Add zone labels (optional)
5. Command Palette - Add reverse video for selection

### Ready for Theme Integration (Priority 2)
1. Command Palette
2. Form Builder
3. Text Input / Text Input Line
4. Tree View
5. Split Pane
6. Dialog

### No Action Needed (13 widgets)
- Context Menu (both variants)
- Menu
- Alert Dialog
- Tabs
- Table
- Toast
- Pick List
- Viewport
- Scroll Bar
- Canvas
- Bar Chart (user config)
- Sparkline (user config)

---

## Migration Checklist

### Phase 1: Critical Status Widgets

- [ ] **Supervision Tree Viewer**
  - [ ] Replace `@status_colors` with `Theme.get_semantic/1` calls
  - [ ] Add text status indicators: `[R]`, `[Y]`, `[T]`, `[U]`
  - [ ] Use attributes (bold/reverse) for status
  - [ ] Test in all color modes

- [ ] **Cluster Dashboard**
  - [ ] Replace `:green`/`:red`/`:yellow` with theme semantic colors
  - [ ] Enhance status text indicators
  - [ ] Migrate selection colors to theme component styles
  - [ ] Test in all color modes

- [ ] **Process Monitor**
  - [ ] Replace threshold colors with theme semantic colors
  - [ ] Add "[HIGH]" / "[MED]" text indicators for thresholds
  - [ ] Migrate selection colors to theme
  - [ ] Test in all color modes

- [ ] **Log Viewer**
  - [ ] Replace `@level_colors` with theme semantic mapping
  - [ ] Already has level text - verify in monochrome
  - [ ] Migrate selection/input colors to theme
  - [ ] Test in all color modes

### Phase 2: Interactive Widgets

- [ ] **Command Palette**
  - [ ] Migrate selection color to `Theme.get_component_style(:item, :selected)`
  - [ ] Add reverse video for monochrome
  - [ ] Add `>` selection marker

- [ ] **Form Builder**
  - [ ] Migrate error color to `Theme.get_semantic(:error)`
  - [ ] Already has "! " prefix - no changes needed

- [ ] **Text Input & Text Input Line**
  - [ ] Migrate to `Theme.get_component_style(:text_input, :focused/placeholder)`
  - [ ] Add underline or reverse for focus in monochrome

- [ ] **Tree View**
  - [ ] Migrate selection colors to theme
  - [ ] Use reverse video for selection
  - [ ] Use bold for matches

- [ ] **Split Pane**
  - [ ] Migrate divider colors to `Theme.get_component_style(:divider, :normal/focused)`
  - [ ] Bold already sufficient for focus

- [ ] **Dialog**
  - [ ] Migrate background to `Theme.get_color(:background)`

### Phase 3: Visualization Widgets

- [ ] **Gauge**
  - [ ] Provide theme-based default zones
  - [ ] Document zone color degradation
  - [ ] Consider zone text labels

- [ ] **Line Chart**
  - [ ] Add `:line_style` option (`:solid`, `:dashed`, `:dotted`)
  - [ ] Add different point markers for series
  - [ ] Provide theme-based default colors

- [ ] **Bar Chart & Sparkline**
  - [ ] Provide theme-based default colors
  - [ ] Document degradation behavior

---

## Test Coverage Matrix

| Widget | true_color | 256 | 16 | mono | Status |
|--------|-----------|-----|----|----|--------|
| Supervision Tree Viewer | ☐ | ☐ | ☐ | ☐ | Pending |
| Cluster Dashboard | ☐ | ☐ | ☐ | ☐ | Pending |
| Process Monitor | ☐ | ☐ | ☐ | ☐ | Pending |
| Log Viewer | ☐ | ☐ | ☐ | ☐ | Pending |
| Tree View | ☐ | ☐ | ☐ | ☐ | Pending |
| Command Palette | ☐ | ☐ | ☐ | ☐ | Pending |
| Form Builder | ☐ | ☐ | ☐ | ☐ | Pending |
| Text Input | ☐ | ☐ | ☐ | ☐ | Pending |
| Split Pane | ☐ | ☐ | ☐ | ☐ | Pending |
| Dialog | ☐ | ☐ | ☐ | ☐ | Pending |
| Gauge | ☐ | ☐ | ☐ | ☐ | Pending |
| Line Chart | ☐ | ☐ | ☐ | ☐ | Pending |
| Bar Chart | ☐ | ☐ | ☐ | ☐ | Pending |
| Sparkline | ☐ | ☐ | ☐ | ☐ | Pending |

---

## Color Pattern Reference

### Semantic Colors (From Hardcoded Usage)

| Semantic | Current Color | Theme Mapping |
|----------|--------------|---------------|
| Success | `:green` | `Theme.get_semantic(:success)` |
| Error | `:red` | `Theme.get_semantic(:error)` |
| Warning | `:yellow` | `Theme.get_semantic(:warning)` |
| Info | `:cyan` | `Theme.get_semantic(:info)` |
| Muted | `:bright_black` | `Theme.get_semantic(:muted)` |
| Help | `:white` + dim | `Theme.get_semantic(:help)` |

### Component Styles (From Hardcoded Usage)

| Component | State | Current Colors | Theme Mapping |
|-----------|-------|----------------|---------------|
| Item | Selected | `:black` on `:cyan` | `Theme.get_component_style(:item, :selected)` |
| Item | Focused | `:blue` bg + `:white` fg | `Theme.get_component_style(:item, :focused)` |
| Button | Focused | `:blue` bg + `:white` fg | `Theme.get_component_style(:button, :focused)` |
| Text Input | Focused | `:white` fg | `Theme.get_component_style(:text_input, :focused)` |
| Text Input | Placeholder | `:bright_black` | `Theme.get_component_style(:text_input, :placeholder)` |
| Border | Normal | `:blue` | `Theme.get_component_style(:border, :normal)` |
| Divider | Normal | `:white` | `Theme.get_component_style(:divider, :normal)` |
| Divider | Focused | `:cyan` + bold | `Theme.get_component_style(:divider, :focused)` |
| Background | Normal | `:black` | `Theme.get_color(:background)` |

---

## Statistics Summary

- **Total Widgets:** 28
- **With Hardcoded Colors:** 15 (53.6%)
- **Without Colors:** 13 (46.4%)
- **Priority 1 (Critical/High):** 4 widgets
- **Priority 2 (Medium):** 6 widgets
- **Priority 3 (Low):** 3 widgets
- **No Action Needed:** 15 widgets

**Theme Migration Estimate:**
- P1 widgets: 4-6 hours (complex status systems)
- P2 widgets: 3-4 hours (simple color replacements)
- P3 widgets: 1-2 hours (defaults and documentation)
- **Total: 8-12 hours** for complete theme migration
