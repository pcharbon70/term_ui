# Feature: Phase 3 Section 3.1 - TTY Backend Module Structure

**Branch:** `feature/phase-03-section-3.1-tty-module-structure`
**Base:** `multi-renderer`
**Date:** 2025-12-05
**Status:** Complete

## Overview

Create the `TermUI.Backend.TTY` module implementing the `TermUI.Backend` behaviour. This module is designed for environments where a shell is already running (Nerves devices, SSH sessions, remote IEx consoles).

## Tasks

### 3.1.1 Define Module with Behaviour Declaration

- [x] 3.1.1.1 Create `lib/term_ui/backend/tty.ex` with `@behaviour TermUI.Backend` declaration
- [x] 3.1.1.2 Add `@moduledoc` explaining the backend's purpose (fallback when raw mode unavailable)
- [x] 3.1.1.3 Document that this backend is selected when raw mode fails with `:already_started`
- [x] 3.1.1.4 Document supported features: ANSI output, colors, cursor positioning, keyboard input via `IO.getn/2`
- [x] 3.1.1.5 Document limitations: no terminal mode control, potential shell interference, limited mouse support

### 3.1.2 Define Internal State Structure

- [x] 3.1.2.1 Define `defstruct` with field `size :: {rows :: pos_integer(), cols :: pos_integer()}`
- [x] 3.1.2.2 Define field `capabilities :: map()` storing detected terminal capabilities
- [x] 3.1.2.3 Define field `line_mode :: :full_redraw | :incremental` for rendering strategy
- [x] 3.1.2.4 Define field `last_frame :: map() | nil` for incremental mode frame comparison
- [x] 3.1.2.5 Define field `character_set :: :unicode | :ascii` for box-drawing characters
- [x] 3.1.2.6 Define field `color_mode :: :true_color | :color_256 | :color_16 | :monochrome`

### Unit Tests - Section 3.1

- [x] Test module compiles and declares `@behaviour TermUI.Backend`
- [x] Test state struct has all expected fields with correct defaults
- [x] Test state struct correctly stores capabilities from init

## Files to Create/Modify

| File | Type | Description |
|------|------|-------------|
| `lib/term_ui/backend/tty.ex` | **New** | TTY backend module with behaviour and state |
| `test/term_ui/backend/tty_test.exs` | **New** | Unit tests for TTY backend |
| `notes/planning/multi-renderer/phase-03-tty-backend.md` | Modified | Mark tasks complete |

## Reference Files

- `lib/term_ui/backend.ex` - Backend behaviour definition
- `lib/term_ui/backend/raw.ex` - Reference implementation

## Verification

```bash
mix compile --warnings-as-errors
mix test test/term_ui/backend/tty_test.exs
mix format --check-formatted
```
