# Feature: Phase 2 Review Fixes

**Branch:** `feature/phase-02-review-fixes`
**Base:** `multi-renderer`
**Date:** 2025-12-05
**Status:** Complete

## Overview

Address all blockers, concerns, and suggestions from the Phase 2 comprehensive review (`notes/reviews/phase-02-raw-backend-review.md`).

## Tasks

### Security Fixes (High Priority)

#### 1. Add Input Buffer Size Limit ✅
- [x] Add `@max_input_buffer_size` constant (1024 bytes)
- [x] Modify `poll_event/2` to truncate buffer when exceeded
- [x] Log warning when buffer is truncated

#### 2. Add Event Queue Size Limit ✅
- [x] Add `@max_event_queue_size` constant (100 events)
- [x] Modify event queue handling to drop oldest when exceeded
- [x] Log warning when events are dropped

#### 3. Add Mouse Coordinate Bounds Checking ✅
- [x] Add validation in `EscapeParser.parse_mouse_params/1`
- [x] Reject coordinates outside `@max_coordinate` (9999)
- [x] Return `:error` for invalid coordinates

### Code Quality Fixes (Medium Priority)

#### 4. Tighten Exception Handling in Cursor Optimization ✅
- [x] Replace bare `rescue _` with specific exception types
- [x] Catch only `ArgumentError`, `ArithmeticError`, `FunctionClauseError`

#### 5. Add ANSI Output Verification Tests ✅
- [x] Add tests that capture IO and verify escape sequences
- [x] Test cursor positioning sequences
- [x] Test color sequences
- [x] Test attribute sequences

#### 6. Test CursorOptimizer Error Handling Path ✅
- [x] Create tests verifying optimizer behavior
- [x] Verify fallback to absolute positioning works

### Code Deduplication (High Priority)

#### 7. Extract SGR Generation to Shared Module ✅
- [x] Create `TermUI.SGR` module
- [x] Provide color_param/2 and attr_param/1 for parameter generation
- [x] Provide color_sequence/2 and attr_sequence/1 for full sequences
- [x] Update SequenceBuffer to use shared module

#### 8. Extract Terminal Size Detection to Shared Module ✅
- [x] Create `TermUI.Terminal.SizeDetector` module
- [x] Move size detection logic from Raw backend
- [x] Move size detection logic from Terminal module
- [x] Add consistent bounds checking (max 9999)
- [x] Update both modules to use shared detector

## Implementation Order

1. Security fixes (1-3) - Critical path ✅
2. Exception handling fix (4) - Quick win ✅
3. Test improvements (5-6) - Verification ✅
4. Code deduplication (7-8) - Cleanup ✅

## Files Created/Modified

| File | Changes |
|------|---------|
| `lib/term_ui/backend/raw.ex` | Buffer limits, exception handling, use SizeDetector |
| `lib/term_ui/terminal/escape_parser.ex` | Mouse bounds checking |
| `lib/term_ui/sgr.ex` | **New** - SGR parameter/sequence generation |
| `lib/term_ui/terminal/size_detector.ex` | **New** - Terminal size detection |
| `lib/term_ui/terminal.ex` | Use shared size detector |
| `lib/term_ui/renderer/sequence_buffer.ex` | Use SGR module |
| `test/term_ui/backend/raw_test.exs` | Output verification, error path tests |

## Verification

```bash
mix compile --warnings-as-errors  # ✅ Passed
mix test test/term_ui/backend/raw_test.exs  # ✅ 191 tests, 0 failures
mix format --check-formatted  # ✅ Passed
```
