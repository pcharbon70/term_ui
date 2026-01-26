# Feature: Phase 5 Task 5.4.1 - Widget Color Audit

**Branch:** `feature/phase-05-task-5.4.1-widget-color-audit`
**Base:** `multi-renderer`
**Date:** 2025-12-11
**Status:** In Progress

## Overview

Audit all widgets to identify color usage patterns and prepare for graceful color degradation across terminal capabilities (true_color → 256 → 16 → monochrome). This audit establishes baseline knowledge before implementing Task 5.4.2 (theme integration) and Task 5.4.3 (color degradation).

## Requirements from Phase Plan

From `notes/planning/multi-renderer/phase-05-widget-adaptation.md`:

### Task 5.4.1: Audit Widget Color Usage
- [ ] 5.4.1.1: List all widgets with hardcoded colors
- [ ] 5.4.1.2: List all widgets using theme colors
- [ ] 5.4.1.3: Identify any widgets with RGB-only colors

---

## Background

### Color System Components

1. **TermUI.Style** (`lib/term_ui/style.ex`)
   - Defines color types: named, indexed, RGB
   - Named colors: `:black`, `:red`, `:green`, `:yellow`, `:blue`, `:magenta`, `:cyan`, `:white`, `:bright_*`
   - Indexed: `{:indexed, 0..255}`
   - RGB: `{:rgb, r, g, b}`

2. **TermUI.Theme** (`lib/term_ui/theme.ex`)
   - Provides theme system with base colors and semantic colors
   - Built-in themes: `:dark`, `:light`, `:high_contrast`
   - API: `Theme.get_color/1`, `Theme.get_semantic/1`, `Theme.get_component_style/2`
   - Component styles for: `:button`, `:text_input`, `:text`, `:border`

3. **TermUI.Color.Converter** (`lib/term_ui/color/converter.ex`)
   - Converts RGB → 256-color palette
   - Converts RGB → 16-color ANSI
   - Handles grayscale detection
   - Perceptual color distance matching

4. **TermUI.Capabilities** (`lib/term_ui/capabilities.ex`)
   - Detects terminal color support
   - Color modes: `:true_color`, `:color_256`, `:color_16`, `:monochrome`
   - Auto-detection via environment variables

### Current State

Based on initial exploration:
- **No widgets currently use Theme API** - No calls to `Theme.get_color/1` or `Theme.get_semantic/1` found
- **Hardcoded colors prevalent** - Many widgets use direct color atoms (`:blue`, `:red`, `:green`, etc.)
- **No RGB-only colors detected** - Search for `{:rgb, ...}` patterns found no usage in widgets
- **Visualization widgets accept color options** - Can pass colors via props but default to hardcoded values

---

## Implementation Progress

### ✅ Step 1: Systematic Widget Discovery
**Status:** Complete

**Widget Inventory** (28 widgets total):

#### Interactive Widgets (10)
- `lib/term_ui/widgets/text_input.ex`
- `lib/term_ui/widgets/text_input/line.ex`
- `lib/term_ui/widgets/dialog.ex`
- `lib/term_ui/widgets/alert_dialog.ex`
- `lib/term_ui/widgets/context_menu.ex`
- `lib/term_ui/widgets/context_menu/inline.ex`
- `lib/term_ui/widgets/menu.ex`
- `lib/term_ui/widgets/command_palette.ex`
- `lib/term_ui/widgets/form_builder.ex`
- `lib/term_ui/widgets/pick_list.ex`

#### Visualization Widgets (4)
- `lib/term_ui/widgets/bar_chart.ex`
- `lib/term_ui/widgets/gauge.ex`
- `lib/term_ui/widgets/sparkline.ex`
- `lib/term_ui/widgets/line_chart.ex`

#### Container Widgets (6)
- `lib/term_ui/widgets/split_pane.ex`
- `lib/term_ui/widgets/viewport.ex`
- `lib/term_ui/widgets/tabs.ex`
- `lib/term_ui/widgets/scroll_bar.ex`
- `lib/term_ui/widgets/canvas.ex`
- `lib/term_ui/widgets/table.ex`

#### Display Widgets (5)
- `lib/term_ui/widgets/toast.ex`
- `lib/term_ui/widgets/tree_view.ex`
- `lib/term_ui/widgets/log_viewer.ex`
- `lib/term_ui/widgets/process_monitor.ex`
- `lib/term_ui/widgets/stream_widget.ex`

#### Specialized Widgets (3)
- `lib/term_ui/widgets/cluster_dashboard.ex`
- `lib/term_ui/widgets/supervision_tree_viewer.ex`
- `lib/term_ui/widgets/visualization_helper.ex`

---

### ⏳ Step 2: Analyze Color Usage Patterns
**Status:** In Progress

Will analyze each widget for:
- Hardcoded named colors
- Theme API usage
- RGB-only colors
- Indexed color usage
- Style.new() calls

---

### ⏸️ Step 3: Deep Widget Analysis
**Status:** Pending

Will read and analyze each widget file for comprehensive understanding.

---

### ⏸️ Step 4: Categorize Widgets by Color Usage
**Status:** Pending

Will group widgets into:
- No color usage
- Hardcoded named colors
- User-configurable colors
- Theme-integrated
- RGB-only colors
- Mixed approach

---

### ⏸️ Step 5: Identify Degradation Issues
**Status:** Pending

Will check for:
- Color-only information
- RGB-dependent features
- Low contrast combinations
- Missing accessibility attributes

---

### ⏸️ Step 6: Document Findings
**Status:** Pending

Will create comprehensive audit report.

---

### ⏸️ Step 7: Create Audit Deliverables
**Status:** Pending

Deliverables:
1. Audit Report
2. Widget Color Matrix
3. Migration Checklist
4. Test Scenarios

---

## Detailed Audit Findings

### 5.4.1.1: Widgets with Hardcoded Colors

*(Will be populated as analysis progresses)*

### 5.4.1.2: Widgets Using Theme Colors

*(Will be populated as analysis progresses)*

### 5.4.1.3: Widgets with RGB-Only Colors

*(Will be populated as analysis progresses)*

---

## Success Criteria

1. **Completeness**
   - All 28 widgets analyzed
   - Every color usage documented
   - No widgets missed in audit

2. **Accuracy**
   - Color sources correctly identified
   - Theme usage (or lack thereof) verified
   - RGB-only detection confirmed

3. **Actionability**
   - Clear migration paths defined
   - Priorities established
   - Next task (5.4.2) can proceed with confidence

4. **Documentation Quality**
   - Audit report is clear and comprehensive
   - Examples provided for each category
   - Recommendations are specific and implementable

---

## Timeline Estimate

- **Step 1 (Widget Discovery):** 30 minutes - COMPLETE
- **Step 2 (Pattern Analysis):** 1 hour - IN PROGRESS
- **Step 3 (Deep Analysis):** 3-4 hours
- **Step 4 (Categorization):** 30 minutes
- **Step 5 (Degradation Issues):** 1 hour
- **Step 6 (Report Writing):** 1-2 hours
- **Step 7 (Deliverables):** 30 minutes

**Total: 7-9 hours**

---

## Notes

### Known Widgets from Initial Exploration

#### Widgets with Hardcoded Colors Detected:
- `command_palette.ex` - Uses `:black`, `:cyan` for selection
- `split_pane.ex` - Uses `:white`, `:cyan` for divider styles
- `stream_widget.ex` - Uses `:blue`, `:white`, `:cyan`, `:yellow`
- `cluster_dashboard.ex` - Extensive color usage: `:red`, `:green`, `:blue`, `:yellow`, `:cyan`, `:white`
- `supervision_tree_viewer.ex` - Status colors: `:green`, `:yellow`, `:red`, `:white`, `:cyan`, `:blue`
- `tree_view.ex` - Uses `:black`, `:yellow`, `:cyan`
- `form_builder.ex` - Uses `:red` for errors
- `text_input.ex` - Uses `:white` as default
- `gauge.ex` - Zones with `:green`, `:yellow`, `:red`

#### Widgets Likely Without Hardcoded Colors:
- `context_menu.ex` - No hardcoded colors found in initial scan
- `bar_chart.ex` - Colors user-configurable via options
- `sparkline.ex` - Colors user-configurable via color_ranges
- `line_chart.ex` - Colors user-configurable in series

---

## Current Status

**Last Updated:** 2025-12-11

**Progress:** Step 1 Complete (Widget Discovery)

**Next Steps:**
1. Run Grep searches for color patterns
2. Analyze each widget file
3. Document findings in detail
4. Create comprehensive audit report
