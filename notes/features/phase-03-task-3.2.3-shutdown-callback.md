# Feature: Phase 3 Task 3.2.3 - Implement shutdown/1 Callback

**Branch:** `feature/phase-03-task-3.2.3-shutdown-callback`
**Base:** `multi-renderer`
**Date:** 2025-12-05
**Status:** Complete

## Overview

Task 3.2.3 implements the `shutdown/1` callback for the TTY backend. This callback restores terminal state when the backend shuts down.

## Tasks

### 3.2.3 Implement shutdown/1 Callback

- [x] 3.2.3.1 Implement `@impl true` `shutdown/1` accepting state
- [x] 3.2.3.2 Reset all attributes with `\e[0m`
- [x] 3.2.3.3 Show cursor with `\e[?25h`
- [x] 3.2.3.4 Leave alternate screen with `\e[?1049l` if it was entered
- [x] 3.2.3.5 Note: No cooked mode restoration needed (never left cooked mode)
- [x] 3.2.3.6 Return `:ok`

## Implementation Plan

1. Modify `shutdown/1` to output ANSI reset sequences
2. Check `state.alternate_screen` to decide whether to leave alternate screen
3. Output sequences in correct order:
   - Reset attributes first (`\e[0m`)
   - Show cursor (`\e[?25h`)
   - Leave alternate screen if entered (`\e[?1049l`)
4. Return `:ok`

## ANSI Escape Sequences

| Sequence | Description |
|----------|-------------|
| `\e[0m` | Reset all attributes (colors, styles) |
| `\e[?25h` | Show cursor |
| `\e[?1049l` | Leave alternate screen buffer |

## Files to Modify

| File | Type | Description |
|------|------|-------------|
| `lib/term_ui/backend/tty.ex` | Modified | Implement shutdown cleanup sequences |
| `test/term_ui/backend/tty_test.exs` | Modified | Add tests for shutdown sequences |
| `notes/planning/multi-renderer/phase-03-tty-backend.md` | Modified | Mark tasks complete |

## Verification

```bash
mix compile --warnings-as-errors
mix test test/term_ui/backend/tty_test.exs
mix format --check-formatted
```
