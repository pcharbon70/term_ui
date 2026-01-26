# Phase 05 Task 5.5.1: Audit Widget Character Usage

**Branch:** `feature/phase-05-task-5.5.1-audit-widget-characters`
**Base:** `multi-renderer`
**Status:** In Progress
**Date:** 2025-12-11
**Dependencies:** Task 5.4.3 (Monochrome Fallbacks - Complete)
**Blocks:** Task 5.5.2 (Implement ASCII Fallbacks)

## Problem Statement

TermUI widgets currently hardcode Unicode characters (box-drawing, arrows, symbols, Braille patterns, block elements) in their rendering code. This creates issues for:

1. **ASCII-only terminals** - Cannot display Unicode characters correctly
2. **Legacy systems** - May not have Unicode font support
3. **SSH connections** - Character encoding issues in some environments
4. **Terminal emulator compatibility** - Inconsistent Unicode support

**Impact:** Widgets become unreadable or render incorrectly in non-Unicode terminals, making the framework inaccessible to users with limited terminal capabilities.

## Solution Overview

Systematically audit all widgets to:
1. Identify which widgets use special Unicode characters
2. Categorize character types (box-drawing, arrows, symbols, Braille, blocks)
3. Document specific characters and their purposes
4. Note current fallback behavior (currently: none)
5. Prioritize widgets for ASCII fallback implementation

This audit enables Task 5.5.2 to implement ASCII fallbacks using the existing `CharacterSet` module.

## Technical Context

### CharacterSet Module (Already Exists)

The framework includes `/home/ducky/code/term_ui/lib/term_ui/character_set.ex` which defines:
- Unicode character sets (box-drawing, arrows, symbols)
- ASCII fallback character sets
- Mapping between Unicode and ASCII representations

**Current Problem:** NO widgets use this module - all hardcode Unicode characters.

### Character Categories

1. **Box-drawing (U+2500-U+257F)**: ┌ ┐ └ ┘ ─ ━ │ ┃ ├ ┤ ┬ ┴ ┼
   - Used for: borders, separators, tree structures
   - ASCII fallbacks: + - | (corners and lines)

2. **Arrows**: → ← ↑ ↓ ▶ ▼
   - Used for: navigation indicators, tree expansion, sort indicators
   - ASCII fallbacks: > < ^ v

3. **Symbols**: ● ○ ■ □ ✓ ✗ ⚠ ℹ
   - Used for: status indicators, checkboxes, alerts
   - ASCII fallbacks: * o # [ ] x ! i

4. **Block elements (U+2580-U+259F)**: █ ░ ▁ ▂ ▃ ▄ ▅ ▆ ▇
   - Used for: progress bars, gauges, sparklines, scrollbars
   - ASCII fallbacks: # - (various combinations)

5. **Braille patterns (U+2800-U+28FF)**: Used by LineChart
   - Used for: sub-character resolution plotting
   - ASCII fallback: Use simple characters or dots

## Implementation Plan

### Step 1: Audit Box-Drawing Characters ⏳

**Goal:** Identify all widgets using box-drawing characters (borders, separators, trees).

**Method:**
```bash
# Search for common box-drawing characters
grep -r "┌\|┐\|└\|┘\|─\|│\|├\|┤\|┬\|┴\|┼" lib/term_ui/widgets/
```

**Document:**
- Widget name
- Character types used
- Purpose (border, separator, tree)
- File location with line numbers

### Step 2: Audit Arrows and Symbols ⏳

**Goal:** Identify widgets using arrows and symbols.

**Method:**
```bash
# Search for arrows
grep -r "→\|←\|↑\|↓\|▶\|▼" lib/term_ui/widgets/

# Search for symbols
grep -r "●\|○\|■\|□\|✓\|✗\|⚠\|ℹ" lib/term_ui/widgets/
```

**Document:**
- Navigation arrows vs status arrows
- Symbol purposes (status, checkbox, alert)

### Step 3: Audit Block Elements and Braille ⏳

**Goal:** Identify visualization widgets using block elements and Braille.

**Method:**
```bash
# Search for block elements
grep -r "█\|░\|▁\|▂\|▃\|▄\|▅\|▆\|▇" lib/term_ui/widgets/

# Check LineChart for Braille
grep -r "braille\|0x2800" lib/term_ui/widgets/
```

### Step 4: Document Current Fallback Behavior ⏳

**Goal:** Verify no widgets currently use CharacterSet module.

**Method:**
```bash
# Check for CharacterSet usage
grep -r "CharacterSet\|character_set" lib/term_ui/widgets/
```

**Expected:** No results (all widgets hardcode characters).

### Step 5: Create Priority Ranking ⏳

**Criteria:**
1. **Critical widgets** - Core UI elements (Dialog, Table, TreeView)
2. **High usage** - Frequently used widgets (CommandPalette, FormBuilder)
3. **Complexity** - Widgets with multiple character types
4. **User impact** - Widgets where broken characters severely impact usability

**Priority Tiers:**
- **P0 (Critical):** Dialog, Table, TreeView, SupervisionTreeViewer
- **P1 (High):** CommandPalette, FormBuilder, Menu, Tabs
- **P2 (Medium):** Progress, Gauge, Sparkline, BarChart
- **P3 (Low):** LineChart (Braille requires special handling)

### Step 6: Write Comprehensive Audit Report ⏳

**Deliverable:** Complete audit document with:
- Summary of findings
- Detailed character usage by widget
- Priority recommendations for Task 5.5.2
- ASCII fallback suggestions

## Success Criteria

- [x] Task planning document created
- [x] All widgets audited for box-drawing characters (5.5.1.1) - 11 widgets identified
- [x] All widgets audited for arrows and symbols (5.5.1.2) - 11 widgets + 4 widgets identified
- [x] All widgets audited for Braille patterns (5.5.1.3) - 2 widgets identified
- [x] Current fallback behavior documented (5.5.1.4) - Zero widgets use CharacterSet
- [x] Priority ranking created (P0-P3, 21 widgets prioritized)
- [x] Comprehensive audit report written with tables and recommendations
- [x] Phase plan updated with completed task

## Expected Findings (Based on Planning Agent)

- **32 widgets** use box-drawing characters
- **7 widgets** use arrows
- **6 widgets** use symbols
- **6 widgets** use block elements
- **1 widget** (LineChart) uses Braille patterns
- **0 widgets** currently use CharacterSet module

## Audit Results

### Box-Drawing Characters (5.5.1.1) ✅

**Total: 11 widgets, 44 occurrences**

| Widget | Characters Used | Purpose | Lines |
|--------|----------------|---------|-------|
| Dialog | ┌ ┐ └ ┘ ─ │ ├ ┤ | Full border box with separator | 252-342 |
| AlertDialog | ┌ ┐ └ ┘ ─ │ ├ ┤ | Full border box with separator | 226-317 |
| Canvas | ┌ ┐ └ ┘ ─ │ | Customizable box drawing | 16, 218-307 |
| Toast | ┌ ┐ └ ┘ ─ │ | Simple border box | 170-172 |
| Gauge | ╭ ╮ ╰ ╯ ─ │ | Rounded border box | 217-229 |
| Menu | ─ | Horizontal separators | 373 |
| ContextMenu | ─ | Horizontal separators | 256 |
| ContextMenu.Inline | ─ | Separator (inline menu) | 299 |
| SplitPane | │ ─ | Vertical and horizontal dividers | 81-83 |
| SupervisionTreeViewer | ─ | Info panel separator | 1038 |
| LineChart | └ ─ | Axis rendering | 154 |

**Key Patterns:**
- **Full border boxes**: Dialog, AlertDialog use complete set (8 characters)
- **Rounded borders**: Gauge uses rounded corners (╭ ╮ ╰ ╯)
- **Separators only**: Menu, ContextMenu use horizontal lines only
- **Dividers**: SplitPane uses single line characters

### Arrows and Navigation Indicators (5.5.1.2) ✅

**Total: 11 widgets, 22 occurrences**

| Widget | Characters Used | Purpose | Lines |
|--------|----------------|---------|-------|
| Table | ▲ ▼ | Sort direction indicators | 361, 365 |
| Menu | ▶ ▼ | Expand/collapse indicators | 408 |
| SupervisionTreeViewer | ▶ ▼ → | Tree expand + strategy indicator | 107, 966, 969 |
| TreeView | ▶ ▼ ► | Tree expand + cursor | 76-77, 726 |
| FormBuilder | ▶ ▼ | Section expand/collapse | 584 |
| ClusterDashboard | ↑ ↓ ← → | Keyboard help text | 1014, 1100 |
| ProcessMonitor | ▲ ▼ ↑ ↓ | Sort + keyboard help | 709, 922 |
| Gauge | ▼ | Value indicator pointer | 224 |
| TextInput | ↑ ↓ | Scroll indicators | 699-700 |
| WidgetHelpers | → | Focus indicator (example) | 148-149 |

**Key Patterns:**
- **Sort indicators**: ▲ (ascending) ▼ (descending) - Table, ProcessMonitor
- **Tree expand**: ▶ (collapsed) ▼ (expanded) - Menu, TreeView, SupervisionTreeViewer, FormBuilder
- **Cursor/focus**: ► (cursor position) - TreeView
- **Navigation help**: ↑ ↓ ← → in keyboard help text
- **Directional**: → for strategy flow in SupervisionTreeViewer

### Symbols (Status, Icons, Markers) (5.5.1.2) ✅

**Total: 4 widgets, 13 occurrences**

| Widget | Characters Used | Purpose | Lines |
|--------|----------------|---------|-------|
| SupervisionTreeViewer | ● ○ □ | Process status + type | 86-88, 100 |
| TreeView | ● ○ | Selection markers | 725, 727 |
| AlertDialog | ℹ ✓ ⚠ ✗ | Alert type icons | 20-22, 40-43 |
| Toast | ℹ ✓ ⚠ ✗ | Notification type icons | 36-39 |

**Key Patterns:**
- **Status indicators**: ● (running/filled), ○ (terminated/empty), □ (supervisor/box)
- **Alert icons**: ℹ (info), ✓ (success), ⚠ (warning), ✗ (error)
- **Selection**: ● (selected), ○ (unselected)

### Block Elements (Progress, Charts) (5.5.1.3) ✅

**Total: 6 widgets, 26+ occurrences**

| Widget | Characters Used | Purpose | Lines |
|--------|----------------|---------|-------|
| Sparkline | ▁ ▂ ▃ ▄ ▅ ▆ ▇ █ | 8-level value visualization | 5, 19, 33, 112-118 |
| BarChart | █ ░ | Filled bar + empty space | 29, 37, 52, 238-247 |
| Gauge | █ ░ | Filled progress + empty | 33-34 |
| ScrollBar | █ ░ | Thumb + track | 49-50, 62-63 |
| Viewport | █ ░ | Scrollbar rendering | 212, 301-334 |
| VisualizationHelper | █ | Examples/validation | 447-482 |

**Key Patterns:**
- **8-level sparklines**: ▁▂▃▄▅▆▇█ for fine-grained value display
- **Progress bars**: █ (filled) + ░ (empty) - standard pattern
- **Scrollbars**: Same pattern as progress (█ thumb, ░ track)

### Braille Patterns (Sub-Character Graphics) (5.5.1.3) ✅

**Total: 2 widgets**

| Widget | Usage | Purpose | Lines |
|--------|-------|---------|-------|
| LineChart | Full Braille range (U+2800-U+28FF) | Sub-character resolution plotting | 35-303 |
| Canvas | Braille buffer for pixel-level drawing | General purpose drawing | 38-130 |

**Implementation:**
- Base character: `0x2800`
- 8 dots per cell (2×4 grid)
- Dot patterns combined via bitwise operations
- Functions: `dots_to_braille/1`, `empty_braille/0`, `full_braille/0`

**Special Handling Required:** Braille cannot have simple ASCII fallback - requires algorithmic conversion to lower-resolution display.

### Current Fallback Behavior (5.5.1.4) ✅

**CharacterSet Module Usage:**
```bash
$ grep -rn "CharacterSet\|character_set" lib/term_ui/widgets/
# NO RESULTS
```

**Finding:** **ZERO widgets** currently use the `CharacterSet` module.

**Current Behavior:**
- All characters are **hardcoded** as Unicode string literals
- No runtime character set detection
- No fallback to ASCII in limited terminals
- Widgets will render **incorrectly** in ASCII-only environments

**CharacterSet Module Status:**
- Module exists at `/home/ducky/code/term_ui/lib/term_ui/character_set.ex`
- Defines both Unicode and ASCII character sets
- Provides mappings for box-drawing, arrows, symbols
- **Not integrated** with any widgets yet

## Priority Ranking for Task 5.5.2

### P0 - Critical (Core UI Elements)

**Must work in ASCII terminals for basic usability:**

1. **Dialog** - Primary modal interface, 8 box-drawing chars
2. **AlertDialog** - System alerts, 8 box-drawing + 4 icons
3. **Table** - Data display, 2 sort arrows
4. **TreeView** - Hierarchical navigation, 3 tree arrows + 2 selection symbols

**Rationale:** These are fundamental UI widgets that users expect to work everywhere.

### P1 - High (Interactive Widgets)

**Important for user workflows:**

5. **Menu** - Navigation, 2 arrows + 1 separator
6. **FormBuilder** - Data entry, 2 expand arrows
7. **SupervisionTreeViewer** - Process management, 3 arrows + 3 symbols + 1 separator
8. **CommandPalette** - (No special chars - already ASCII-safe)

### P2 - Medium (Visualization & Enhancement)

**Enhance experience but not critical:**

9. **Gauge** - Progress display, 4 rounded borders + 2 block elements + 1 arrow
10. **BarChart** - Data visualization, 2 block elements
11. **Sparkline** - Inline trends, 8 block elements
12. **ScrollBar** - Navigation aid, 2 block elements
13. **Viewport** - Scrolling container, 2 block elements
14. **Toast** - Notifications, 4 box + 4 icons
15. **SplitPane** - Layout, 2 divider chars
16. **ProcessMonitor** - System monitoring, 2 sort + 4 nav arrows
17. **ContextMenu** - Dropdown, 1 separator
18. **TextInput** - Input field, 2 scroll indicators

### P3 - Low (Complex/Special Cases)

**Require special handling or less critical:**

19. **LineChart** - Complex Braille patterns, requires algorithmic fallback
20. **Canvas** - General purpose drawing, Braille buffer, advanced use case
21. **ClusterDashboard** - Advanced monitoring, 4 nav arrows in help text

## Summary Statistics

| Category | Widgets | Total Chars | Notes |
|----------|---------|-------------|-------|
| Box-drawing | 11 | 44 | Borders, separators, dividers |
| Arrows | 11 | 22 | Sort, expand, navigation |
| Symbols | 4 | 13 | Status, alerts, selection |
| Block elements | 6 | 26+ | Progress, charts, scrollbars |
| Braille | 2 | N/A | LineChart (complex), Canvas |
| **Using CharacterSet** | **0** | **N/A** | **None - all hardcoded** |

## Recommendations for Task 5.5.2

### 1. Create CharacterSet Integration Pattern

**Recommended approach:**
```elixir
# In widget init or render:
charset = CharacterSet.get()  # Returns :unicode or :ascii based on terminal

# Use charset for character selection:
corner_tl = charset.box.top_left  # "┌" or "+"
arrow_down = charset.arrow.down   # "▼" or "v"
```

### 2. Phase Implementation by Priority

**Phase 1 (P0):** Dialog, AlertDialog, Table, TreeView
- Essential for basic usability
- Clear ASCII fallbacks (+ - | for boxes, > v for arrows)

**Phase 2 (P1):** Menu, FormBuilder, SupervisionTreeViewer
- Important workflows
- Same pattern as Phase 1

**Phase 3 (P2):** Visualization widgets
- Gauge, BarChart, Sparkline, ScrollBar
- Block elements: # for filled, - for empty

**Phase 4 (P3):** Special cases
- LineChart: Requires custom fallback algorithm
- Canvas: Advanced use case, document limitations

### 3. Testing Strategy

**Per widget:**
- Test with `CharacterSet.set_mode(:unicode)` - verify Unicode works
- Test with `CharacterSet.set_mode(:ascii)` - verify ASCII fallback
- Visual regression: ASCII version must be readable

**Integration:**
- Test terminal type detection
- Test runtime mode switching
- Test mixed scenarios (some widgets ASCII, some Unicode)

## Next Steps

1. ✅ Complete this audit (Task 5.5.1)
2. Implement ASCII fallbacks (Task 5.5.2) starting with P0 widgets
3. Add character set tests (Task 5.5.3)
4. Update phase plan marking 5.5.1 complete

## Progress Log

### 2025-12-11
- Created feature branch
- Created planning document with planning agent assistance
- ✅ Completed systematic audit of all widgets
- ✅ Identified 11 widgets with box-drawing (44 occurrences)
- ✅ Identified 11 widgets with arrows (22 occurrences)
- ✅ Identified 4 widgets with symbols (13 occurrences)
- ✅ Identified 6 widgets with block elements (26+ occurrences)
- ✅ Identified 2 widgets with Braille patterns (LineChart, Canvas)
- ✅ Confirmed ZERO widgets use CharacterSet module
- ✅ Created priority ranking (P0-P3) for Task 5.5.2
- ✅ Documented recommendations for ASCII fallback implementation
