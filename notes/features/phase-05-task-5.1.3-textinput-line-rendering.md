# Feature: Phase 5 Task 5.1.3 - Implement TextInput.Line Rendering

**Branch:** `feature/phase-05-task-5.1.3-textinput-line-rendering`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** In Progress

## Overview

Implement rendering for the `TextInput.Line` widget, following the task requirements from Phase 5.1.3 in the multi-renderer plan.

## Scope

### Task 5.1.3: Implement Rendering

- [ ] 5.1.3.1 Render label on first line if provided
- [ ] 5.1.3.2 Render prompt + current value on input line
- [ ] 5.1.3.3 Render validation error below if present
- [ ] 5.1.3.4 Support styling via theme

---

## Implementation Plan

### Step 1: Import RenderNode Module

Import the `TermUI.Component.RenderNode` module for building render nodes:
- `text/2` - Create text nodes with styling
- `stack/2` - Stack nodes vertically/horizontally
- `empty/0` - Empty node

### Step 2: Implement `render/1` Function

Create a `render/1` function that takes the widget state and returns a `RenderNode.t()`:

```elixir
def render(%__MODULE__{} = state) do
  # Build render tree:
  # 1. Label (if present)
  # 2. Prompt + value (or placeholder)
  # 3. Error (if present)
end
```

### Step 3: Style Support

Use the Theme system for consistent styling:
- Default foreground for label
- Muted/dim for placeholder
- Error semantic color for validation errors
- Allow custom styles to be passed in props

### Step 4: Add Unit Tests

Create tests for:
- Rendering with label
- Rendering prompt + value
- Rendering placeholder when empty
- Rendering validation error
- Theme-based styling

---

## Design Decisions

### Simple Stateless Rendering

Unlike the full `TextInput` widget which uses `StatefulComponent` with complex rendering, `TextInput.Line` has a simpler design:
- No cursor rendering (shell handles cursor during input)
- No scroll handling (single line only)
- Static display of label, prompt, value/placeholder, and error

### Render Function Signature

Following the pattern of simple widgets like `Gauge`, use `render/1` taking the state directly rather than `render/2` with an area parameter. The widget renders its content and layout handles positioning.

### Theme Integration

For theme support, we'll:
1. Accept optional style props during initialization
2. Fall back to sensible defaults using `Style.new/1`
3. Use semantic colors for errors

---

## Success Criteria

- [x] Module compiles without warnings
- [x] Label renders on first line when provided
- [x] Prompt + value render correctly
- [x] Placeholder shows when value is empty
- [x] Error renders below with appropriate styling
- [x] Unit tests pass (40 tests, 0 failures)

---

## Files to Modify

| File | Action |
|------|--------|
| `lib/term_ui/widgets/text_input/line.ex` | Add render/1 function |
| `test/term_ui/widgets/text_input/line_test.exs` | Add rendering tests |
| `notes/planning/multi-renderer/phase-05-widget-adaptation.md` | Update task status |
