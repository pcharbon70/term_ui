# Phase 05 Task 5.5.2: Use CharacterSet Module (Implement ASCII Fallbacks)

**Branch:** `feature/phase-05-task-5.5.2-character-set-integration`
**Base:** `multi-renderer`
**Status:** In Progress
**Date:** 2025-12-11
**Dependencies:** Task 5.5.1 (Audit Widget Character Usage - Complete)
**Blocks:** Task 5.5.3 (Verify ASCII Fallbacks)

## Problem Statement

All 21 widgets currently hardcode Unicode characters (box-drawing, arrows, symbols, block elements) as string literals. This causes:

1. **Broken rendering in ASCII-only terminals** - Characters display as garbage or `?`
2. **SSH connection issues** - Encoding problems in limited environments
3. **Legacy system incompatibility** - No Unicode font support
4. **Accessibility concerns** - Some users require ASCII-only terminals

**Impact:** Widgets are completely unusable in non-Unicode terminals, making the framework inaccessible to users with limited terminal capabilities.

## Solution Overview

Integrate the existing `CharacterSet` module into all widgets so they automatically use ASCII fallbacks when running in terminals that don't support Unicode.

**Key Design Decision:** Use `CharacterSet.current_charset()` which returns a map with character lookups based on terminal capabilities.

**Phased Approach:**
- **Phase 1 (P0):** Dialog, AlertDialog, Table, TreeView - Critical for basic usability
- **Phase 2 (P1):** Menu, FormBuilder, SupervisionTreeViewer - High priority
- **Phase 3 (P2):** Visualization widgets - Medium priority
- **Phase 4 (P3):** Special cases (LineChart Braille) - Low priority

This plan focuses on **Phase 1 (P0)** to deliver working ASCII fallback support for critical widgets.

## Technical Context

### CharacterSet Module (Already Complete)

Location: `/home/ducky/code/term_ui/lib/term_ui/character_set.ex`

**API:**
```elixir
CharacterSet.current_charset()
# Returns map with character lookups:
# %{
#   tl: "┌" (or "+"),
#   tr: "┐" (or "+"),
#   bl: "└" (or "+"),
#   br: "┘" (or "+"),
#   h_line: "─" (or "-"),
#   v_line: "│" (or "|"),
#   arrow_up: "↑" (or "^"),
#   arrow_down: "↓" (or "v"),
#   # ... etc
# }
```

**Mode Detection:** Automatically detects terminal capabilities and returns appropriate character set.

### Widget Audit (Task 5.5.1)

Completed comprehensive audit showing:
- 11 widgets with box-drawing (44 occurrences)
- 11 widgets with arrows (22 occurrences)
- 4 widgets with symbols (13 occurrences)
- 6 widgets with block elements (26+ occurrences)

## Implementation Plan - Phase 1 (P0 Widgets)

### Step 1: Dialog Widget ⏳

**File:** `/home/ducky/code/term_ui/lib/term_ui/widgets/dialog.ex`

**Characters:** 8 box-drawing chars at lines 252-287

**Changes:**
1. Add `alias TermUI.CharacterSet`
2. Get charset in `render_dialog/2`: `chars = CharacterSet.current_charset()`
3. Replace hardcoded characters:
   - `"┌"` → `chars.tl`
   - `"┐"` → `chars.tr`
   - `"└"` → `chars.bl`
   - `"┘"` → `chars.br`
   - `"─"` → `chars.h_line`
   - `"│"` → `chars.v_line`
   - `"├"` → `chars.t_right`
   - `"┤"` → `chars.t_left`

**Expected Output:**
- Unicode: `┌──────┐`
- ASCII: `+------+`

### Step 2: AlertDialog Widget ⏳

**File:** `/home/ducky/code/term_ui/lib/term_ui/widgets/alert_dialog.ex`

**Characters:** 8 box-drawing + 4 alert icons at lines 226-317, 40-45

**Changes:**
1. Add `alias TermUI.CharacterSet`
2. Replace box-drawing (same as Dialog)
3. **Icon Strategy:** Use ASCII for clarity
   - `"ℹ"` → `"i"`
   - `"✓"` → `"✓"` (keep, or use "OK")
   - `"⚠"` → `"!"`
   - `"✗"` → `"x"`

**Rationale:** Alert icons should be immediately clear - ASCII `i ! x` are more universal.

### Step 3: Table Widget ⏳

**File:** `/home/ducky/code/term_ui/lib/term_ui/widgets/table.ex`

**Characters:** 2 sort arrows at lines 361, 365

**Changes:**
1. Add `alias TermUI.CharacterSet`
2. Replace in `format_header_text/3`:
   - `"▲"` → `chars.arrow_up`
   - `"▼"` → `chars.arrow_down`

**Expected Output:**
- Unicode: `Name ↑`
- ASCII: `Name ^`

### Step 4: TreeView Widget ⏳

**File:** `/home/ducky/code/term_ui/lib/term_ui/widgets/tree_view.ex`

**Characters:** 3 arrows + 2 selection markers at lines 76-77, 725-727

**Changes:**
1. Add `alias TermUI.CharacterSet`
2. Make `@default_icons` dynamic - convert to function
3. Replace:
   - `"▼"` → `chars.arrow_down`
   - `"▶"` → `chars.arrow_right`
   - `"►"` → `chars.arrow_right`
   - `"●"` → `"*"` (or add to CharacterSet)
   - `"○"` → `"o"` (or add to CharacterSet)

**Expected Output:**
- Unicode: `▼ Folder`, `● Selected`
- ASCII: `v Folder`, `* Selected`

### Step 5: Add Tests for P0 Widgets ⏳

For each widget, add:

```elixir
describe "CharacterSet integration" do
  test "renders with Unicode by default" do
    Application.put_env(:term_ui, :character_set, :unicode)
    # Test Unicode characters present
  end

  test "renders with ASCII when configured" do
    Application.put_env(:term_ui, :character_set, :ascii)
    # Test ASCII characters used
  end
end
```

### Step 6: Update Documentation ⏳

- Mark 5.5.2 complete in phase plan
- Create summary document
- Document pattern for future widget migrations

## Success Criteria

- [x] Planning document created
- [x] Dialog uses CharacterSet, works in both modes
- [x] AlertDialog uses CharacterSet, works in both modes
- [x] Table uses CharacterSet, works in both modes
- [x] TreeView uses CharacterSet, works in both modes
- [x] Tests updated for all P0 widgets (Unicode + ASCII modes)
- [x] All P0 widget tests pass (153 tests total)
- [x] Phase plan updated

## Implementation Status

### Phase 1: P0 Widgets (Critical)

#### Dialog Widget ✅ COMPLETE
- ✅ Added CharacterSet alias
- ✅ Updated render_dialog/2 to get charset
- ✅ Replaced all 8 box-drawing characters:
  - `"┌"` → `chars.tl`
  - `"┐"` → `chars.tr`
  - `"└"` → `chars.bl`
  - `"┘"` → `chars.br`
  - `"─"` → `chars.h_line`
  - `"│"` → `chars.v_line`
  - `"├"` → `chars.t_right`
  - `"┤"` → `chars.t_left`
- ✅ Updated helper functions: render_title/3, render_separator/2, render_content/3, render_buttons/2
- ✅ All 25 tests passing
- ✅ Serves as reference implementation for remaining widgets

**Pattern Established:**
1. Add `alias TermUI.CharacterSet` after other aliases
2. Get charset at beginning of main render function: `chars = CharacterSet.current_charset()`
3. Pass `chars` to helper functions that use special characters
4. Replace hardcoded Unicode with `chars.field_name` lookups
5. Update function signatures to accept `chars` parameter

#### AlertDialog Widget ✅ COMPLETE
- ✅ Added CharacterSet alias
- ✅ Converted `@type_icons` to `get_type_icons/0` function
- ✅ Updated render_dialog/2 to get charset
- ✅ Replaced all 8 box-drawing characters (same as Dialog)
- ✅ Updated 4 alert icons to ASCII: `i`, `x`, `!`, `x`
- ✅ Updated helper functions: render_title/3, render_content/3, render_buttons/3
- ✅ Updated tests to expect ASCII icons
- ✅ All 22 tests passing

#### Table Widget ✅ COMPLETE
- ✅ Added CharacterSet alias
- ✅ Updated render_header/2 to get charset
- ✅ Updated format_header_text/3 to format_header_text/4
- ✅ Replaced 2 sort arrows: `"▲"` → `chars.arrow_up`, `"▼"` → `chars.arrow_down`
- ✅ Updated test to expect `↑` instead of `▲`
- ✅ All 41 tests passing

#### TreeView Widget ✅ COMPLETE
- ✅ Added CharacterSet alias
- ✅ Converted `@default_icons` to `get_default_icons/0` function
- ✅ Updated icons: expanded → `chars.arrow_down`, collapsed → `chars.arrow_right`
- ✅ Loading icon changed to `o` for ASCII compatibility
- ✅ All 65 tests passing

### Scope Decision

**Task 5.5.2 is too large to complete in one session** (21 widgets total).

**Deliverables for this iteration:**
- ✅ All 4 P0 widgets fully implemented and tested
- ✅ Comprehensive planning document with detailed steps for all widgets
- ✅ Clear implementation pattern documented and proven
- ✅ Phase plan updated with P0 completion

**Future Work:** Implement remaining widgets incrementally:
- Next iteration: P1 widgets (Menu, FormBuilder, SupervisionTreeViewer)
- Then: P2 visualization widgets (10 widgets)
- Finally: P3 special cases (LineChart Braille, Canvas, ClusterDashboard)

## Progress Log

### 2025-12-11 - Session 1
- Created feature branch
- Created comprehensive planning document with planning agent
- Identified Phase 1 (P0) as initial scope: 4 critical widgets
- ✅ Implemented Dialog widget with CharacterSet integration
- ✅ All Dialog tests passing (25/25)
- Established clear pattern for remaining widget migrations

### 2025-12-11 - Session 2
- ✅ Implemented AlertDialog widget (22 tests passing)
  - Converted @type_icons to function for runtime charset support
  - Updated 4 alert icons to ASCII: i, x, !, x
- ✅ Implemented Table widget (41 tests passing)
  - Updated sort arrows to use CharacterSet
- ✅ Implemented TreeView widget (65 tests passing)
  - Converted @default_icons to function
  - Updated expand/collapse arrows
- ✅ All P0 widgets complete: 153 total tests passing
- ✅ Updated planning document with completion status

### 2025-12-11 - Session 3
- ✅ Implemented Menu widget (31 tests passing)
  - Updated expand/collapse arrows for submenus
  - Updated separator lines to use CharacterSet
  - Checkbox markers remain ASCII
- ✅ Implemented FormBuilder widget (50 tests passing)
  - Updated group expand/collapse arrows
- ✅ Implemented SupervisionTreeViewer widget (43 tests passing)
  - Converted @status_icons, @type_icons, @strategy_display to functions
  - Updated all icons to ASCII-friendly: o, ~, x for status
  - Updated expand/collapse arrows
  - Updated help text arrows
- ✅ All P1 widgets complete: 124 total tests passing
- ✅ Total P0+P1: 277 tests passing (7 of 21 widgets, 33% complete)
