# Feature: Phase 3 Task 3.7.4 - Poll Event Callback

**Branch:** `feature/phase-03-task-3.7.4-poll-event`
**Base:** `multi-renderer`
**Date:** 2025-12-06
**Status:** Complete

## Overview

Implement the poll_event/2 callback for the TTY backend to read keyboard and mouse input using IO.getn/2 and parse escape sequences.

## Implementation Summary

### 3.7.4.1 Implement poll_event/2 Callback
- [x] Accept state and timeout parameters
- [x] Check for buffered input first
- [x] Use `IO.getn("", 1)` to read single character (blocking)
- [x] Handle IO.getn result (character or :eof)

### 3.7.4.2 Read Character with IO.getn
- [x] Call `IO.getn("", 1)` for blocking single-char read
- [x] Handle `:eof` return
- [x] Handle charlist return in some contexts

### 3.7.4.3 Parse Escape Sequences
- [x] Use `TermUI.Terminal.EscapeParser.parse/1`
- [x] Handle partial sequences (buffer for next call)
- [x] Added `input_buffer` field to state

### 3.7.4.4 Return Events
- [x] Return `{:ok, event, state}` for key events
- [x] Return `{:timeout, state}` when partial sequence buffered
- [x] Return `{:error, reason, state}` on errors

### 3.7.4.5 Document Timeout Limitation
- [x] Note in docs that timeout is not honored due to blocking IO.getn

## Files Modified

| File | Changes |
|------|---------|
| `lib/term_ui/backend/tty.ex` | Added `input_buffer` field, implemented `poll_event/2` with IO.getn and EscapeParser |
| `test/term_ui/backend/tty_test.exs` | Added 10 new tests for poll_event behavior |

## New State Field

Added `input_buffer :: binary()` to the TTY state struct for buffering partial escape sequences between calls.

## Success Criteria

- [x] `poll_event/2` reads input via IO.getn
- [x] Escape sequences parsed correctly via EscapeParser
- [x] Events returned in correct format
- [x] Partial sequences buffered for next call
- [x] All 194 tests pass
