# Feature: Phase 3 Task 3.2.2 - Implement Terminal Setup

**Branch:** `feature/phase-03-task-3.2.2-terminal-setup`
**Base:** `multi-renderer`
**Date:** 2025-12-05
**Status:** Complete

## Overview

Task 3.2.2 adds terminal setup sequences to the TTY backend's `init/1` callback. These ANSI escape sequences prepare the terminal for rendering.

## Tasks

### 3.2.2 Implement Terminal Setup

- [x] 3.2.2.1 Optionally enter alternate screen with `\e[?1049h` if configured
- [x] 3.2.2.2 Hide cursor with `\e[?25l` for cleaner rendering
- [x] 3.2.2.3 Clear screen with `\e[2J\e[H` for fresh start
- [x] 3.2.2.4 Note: No raw mode activation (shell already running)

## Implementation Plan

1. Add a private helper `setup_terminal/1` that outputs ANSI sequences
2. Call `setup_terminal/1` at the end of `init/1` before returning
3. Sequences to output:
   - If `alternate_screen: true`: `\e[?1049h` (enter alternate screen)
   - Always: `\e[?25l` (hide cursor)
   - Always: `\e[2J\e[H` (clear screen and home cursor)
4. Update cursor_visible state to false after hiding cursor

## ANSI Escape Sequences

| Sequence | Description |
|----------|-------------|
| `\e[?1049h` | Enter alternate screen buffer |
| `\e[?25l` | Hide cursor |
| `\e[2J` | Clear entire screen |
| `\e[H` | Move cursor to home (1,1) |

## Files to Modify

| File | Type | Description |
|------|------|-------------|
| `lib/term_ui/backend/tty.ex` | Modified | Add terminal setup in init/1 |
| `test/term_ui/backend/tty_test.exs` | Modified | Add tests for setup sequences |
| `notes/planning/multi-renderer/phase-03-tty-backend.md` | Modified | Mark tasks complete |

## Verification

```bash
mix compile --warnings-as-errors
mix test test/term_ui/backend/tty_test.exs
mix format --check-formatted
```
