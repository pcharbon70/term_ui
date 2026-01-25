# Phase 6 Review Fixes and Improvements

**Feature Branch**: `feature/phase-6-review-fixes`
**Target Branch**: `multi-renderer`
**Created**: 2025-01-24
**Status**: In Progress

---

## Problem Statement

The comprehensive code review of Phase 6 (multi-renderer integration) identified **12 blockers**, **33 concerns**, and **40 suggestions** that need to be addressed before the code is production-ready. The issues span:

1. **Security vulnerabilities** - Command injection, unbounded queues, escape sequence injection
2. **Code duplication** - ~600 lines duplicated across backends and input handlers
3. **OTP violations** - Missing child_spec, persistent_term leaks, unsafe process dictionary
4. **Inconsistencies** - Error handling, naming conventions, return types
5. **Testing gaps** - Missing edge cases, property tests, real terminal I/O tests

**Impact**: Without addressing these issues, the system has security vulnerabilities, potential memory leaks, and maintenance challenges that will compound over time.

---

## Solution Overview

### Strategy

Fix issues in order of severity and dependency:

1. **Security Blockers (Immediate)** - Fix vulnerabilities first
2. **OTP Blockers (Immediate)** - Ensure proper GenServer behaviour
3. **Consistency Blockers (Immediate)** - Standardize error handling
4. **Redundancy Blockers (Short-term)** - Extract duplicated code
5. **Planning Doc (Quick)** - Update checkboxes
6. **Concerns (Medium-term)** - Address architectural concerns
7. **Suggestions (Long-term)** - Implement improvements

### Design Decisions

| Area | Decision | Rationale |
|------|----------|-----------|
| Command Injection | Use absolute paths + whitelist parsing | Defense-in-depth |
| Event Queue | Bounded queue with drop-oldest strategy | Prevents DoS, maintains responsiveness |
| Code Deduplication | New ANSI.Parser, ANSI.Emitter, Geometry modules | Clear separation of concerns |
| Error Handling | Standardize on tagged tuples `{:ok, _} \| {:error, _}` | OTP convention |
| child_spec | Add to all GenServers with explicit restart strategy | Enable proper supervision |

---

## Technical Details

### Files to Modify

#### New Files to Create
```
lib/term_ui/ansi/parser.ex          # Escape sequence parser
lib/term_ui/ansi/emitter.ex          # ANSI sequence emitter
lib/term_ui/geometry.ex              # Area calculation utilities
lib/term_ui/event_queue.ex           # Bounded event queue
lib/term_ui/term_utils.ex            # Terminal command safety wrapper
lib/term_ui/sanitize.ex              # Input sanitization
```

#### Files to Modify (Security)
```
lib/term_ui/backend/tty.ex           # Command injection fixes
lib/term_ui/backend/raw.ex           # Escape injection fixes
lib/term_ui/runtime.ex               # Event queue, persistent_term, process dictionary
```

#### Files to Modify (Deduplication)
```
lib/term_ui/backend/raw.ex           # Use shared parser/emitter
lib/term_ui/backend/tty.ex           # Use shared parser/emitter
lib/term_ui/input/raw.ex             # Use shared parser
lib/term_ui/input/tty.ex             # Use shared parser
```

#### Files to Modify (OTP)
```
lib/term_ui/backend/raw.ex           # Add child_spec
lib/term_ui/backend/tty.ex           # Add child_spec
lib/term_ui/input/raw.ex             # Add child_spec (if GenServer)
lib/term_ui/input/tty.ex             # Add child_spec (if GenServer)
lib/term_ui/runtime.ex               # Add child_spec
```

#### Files to Modify (Consistency)
```
lib/term_ui/backend/raw.ex           # Standardize error returns
lib/term_ui/backend/tty.ex           # Standardize error returns
```

#### Planning Document
```
notes/planning/multi-renderer.md     # Update Section 6.3 checkboxes
```

### Dependencies

No new external dependencies required. All changes use existing Elixir/OTP features.

---

## Success Criteria

### Must Have (Blockers)
- [ ] All 3 security vulnerabilities fixed
- [ ] All 3 redundancy blockers resolved
- [ ] All 3 Elixir/OTP blockers addressed
- [ ] All 2 consistency blockers fixed
- [ ] Planning document updated (Section 6.3)

### Should Have (Concerns)
- [ ] At least 50% of concerns addressed (17/33)
- [ ] Priority concerns (Senior Engineer + Security) fully addressed

### Nice to Have (Suggestions)
- [ ] At least 25% of suggestions implemented (10/40)
- [ ] Focus on security, consistency, and Elixir suggestions

### Verification
- [ ] All tests pass
- [ ] No Credo warnings
- [ ] No Dialyzer warnings (if available)
- [ ] Security review passes re-check
- [ ] Code review approves changes

---

## Implementation Plan

### Phase 1: Security Blockers (Priority: CRITICAL)

#### 1.1 Command Injection Fix ✅
- [x] Create `lib/term_ui/term_utils.ex` with safe command wrapper
  - Absolute path lookup for `stty`, `infocmp`
  - Command timeout (5s default)
  - Output validation
- [x] Update `lib/term_ui/backend/tty.ex:47-52`
  - Use safe wrapper instead of `System.cmd/2`
  - Add output parsing validation
- [x] Add tests for command safety
- [x] Verify no regressions

**Implementation Details**:
- Created `TermUI.TermUtils` module with `safe_stty/2`, `safe_test/2`, `safe_infocmp/2`
- Command whitelist enforced: `stty`, `test`, `infocmp` only
- All arguments validated against safe patterns before execution
- Timeout enforced via Task.await with 5s default
- Output validation: max 64KB, no null bytes, character checks
- Updated `lib/term_ui/terminal.ex` to use TermUtils (5 call sites)
- Updated `lib/term_ui/terminal/size_detector.ex` to use TermUtils
- 15 security tests added - all passing

#### 1.2 Bounded Event Queue ✅
- [x] Create `lib/term_ui/event_queue.ex`
  - Max size configuration (default 1000)
  - Drop-oldest strategy when full
  - Warning logging on overflow
- [x] Update `lib/term_ui/runtime.ex:589-602`
  - Replace unbounded queue with bounded version
- [x] Add overflow tests
- [x] Add performance tests

**Implementation Details**:
- Created `TermUI.EventQueue` module with bounded queue using Erlang `:queue`
- Default max size: 1000 events (~16 seconds at 60 FPS)
- Drop-oldest strategy when full (prevents queue from growing unbounded)
- Rate-limited warning logging (once per 5 seconds max)
- Added `event_queue` field to `Runtime.State`
- Updated `Runtime.handle_cast({:event, _})` to use bounded queue
- Updated `Runtime.handle_info({:input, _})` to use bounded queue
- Added `process_event_queue/1` function to process queued events
- 18 comprehensive tests added - all passing

#### 1.3 Terminal Escape Injection ✅
- [x] Create `lib/term_ui/sanitize.ex`
  - Strip ANSI codes from user input
  - Max length validation
  - Control character filtering
- [x] Add security tests for escape injection
- [x] Document security model

**Implementation Details**:
- Created `TermUI.Sanitize` module with escape sequence sanitization
- Three sanitization modes: `:bracket`, `:remove`, `:keep`
- Max length validation (default: 10_000 characters)
- Detects and neutralizes:
  - CSI sequences (like `\e[31m` for colors)
  - OSC sequences (like `\e]0;Title\a` for window title)
  - DCS sequences
  - Control characters (except tab, newline, carriage return)
  - Null bytes
- `validate/1` function returns `:ok` or `{:error, reason}`
- `has_ansi?/1` function to detect escape sequences
- `strip_ansi/1` function to remove all escapes
- 45 comprehensive security tests added - all passing

**Note**: Integration with rendering path deferred to Phase 6 (concerns) as it requires identifying where user input enters the system.

### Phase 2: Elixir/OTP Blockers (Priority: HIGH)

#### 2.1 Add child_spec to All GenServers
- [ ] Add `child_spec/1` to `lib/term_ui/backend/raw.ex`
- [ ] Add `child_spec/1` to `lib/term_ui/backend/tty.ex`
- [ ] Add `child_spec/1` to `lib/term_ui/runtime.ex`
- [ ] Add tests for child_spec
- [ ] Document supervision tree

#### 2.2 Persistent Term Cleanup
- [ ] Add `cleanup_persistent_terms/0` to Runtime
- [ ] Call cleanup on shutdown
- [ ] Add cleanup on backend switch
- [ ] Document persistent term lifecycle
- [ ] Add tests for cleanup

#### 2.3 Remove Process Dictionary Usage
- [ ] Replace `Process.put(:term_ui_context, ...)` with state storage
- [ ] Update all consumers of term_ui_context
- [ ] Add tests for state persistence
- [ ] Document state management approach

### Phase 3: Consistency Blockers (Priority: HIGH)

#### 3.1 Standardize Error Handling
- [ ] Audit all error return patterns
- [ ] Create `lib/term_ui/error.ex` with error types
- [ ] Update `TTY.init/1` to return `{:error, reason}` instead of raising
- [ ] Update all error sites to use tagged tuples
- [ ] Add error handling tests
- [ ] Document error handling convention

#### 3.2 Naming Conventions
- [ ] Define naming conventions in docs
  - `backend_mode` not `mode`
  - `capabilities` not `caps`
  - Consistent async/sync naming
- [ ] Create glossary document
- [ ] Update inconsistent names (where safe)
- [ ] Add Credo rules for naming

### Phase 4: Redundancy Blockers (Priority: MEDIUM)

#### 4.1 Extract ANSI Parser
- [ ] Create `lib/term_ui/ansi/parser.ex`
  - Consolidate escape sequence parsing
  - Handle CSI, DCS, OSC, ESC sequences
  - Provide parsed struct output
- [ ] Refactor `Raw` to use ANSI.Parser
- [ ] Refactor `TTY` to use ANSI.Parser
- [ ] Refactor Input.Raw to use ANSI.Parser
- [ ] Refactor Input.TTY to use ANSI.Parser
- [ ] Add parser tests
- [ ] Verify no regressions

#### 4.2 Extract ANSI Emitter
- [ ] Create `lib/term_ui/ansi/emitter.ex`
  - Consolidate ANSI sequence generation
  - Support all terminal capabilities
  - Input: capability + params, Output: iodata
- [ ] Refactor `Raw` to use ANSI.Emitter
- [ ] Refactor `TTY` to use ANSI.Emitter
- [ ] Add emitter tests
- [ ] Verify output compatibility

#### 4.3 Extract Geometry Utilities
- [ ] Create `lib/term_ui/geometry.ex`
  - Area calculation functions
  - Intersection functions
  - Containment checks
- [ ] Replace duplicate area calculations
- [ ] Add geometry tests

### Phase 5: Planning Document (Quick Win)

- [ ] Update `notes/planning/multi-renderer.md`
  - Mark Section 6.3 checkboxes as complete
  - Update status summary
  - Add note about completion verification

### Phase 6: Address Concerns (Priority: MEDIUM)

#### 6.1 Senior Engineer Concerns
- [ ] Document dual input paths and when to use each
- [ ] Add architecture decision record (ADR) for backend coupling
- [ ] Document persistent term usage and rationale
- [ ] Add error recovery patterns documentation
- [ ] Refactor color mapping to single module

#### 6.2 QA Concerns
- [ ] Add edge case tests for error paths
- [ ] Add property-based tests for event queue
- [ ] Add fuzzing tests for ANSI parser
- [ ] Add backend switching stress tests
- [ ] Add concurrent event handling tests
- [ ] Document real terminal testing approach

#### 6.3 Security Concerns (Remaining)
- [ ] Add rate limiting for event input
- [ ] Add terminal size validation
- [ ] Add mouse tracking security documentation
- [ ] Add capability detection validation
- [ ] Create security checklist

#### 6.4 Consistency Concerns (Remaining)
- [ ] Audit and document async vs sync patterns
- [ ] Create state field naming guide
- [ ] Document return type conventions
- [ ] Standardize error messages
- [ ] Document callback ordering
- [ ] Audit public API naming

#### 6.5 Redundancy Concerns
- [ ] Extract capability detection patterns
- [ ] Unify terminal size handling
- [ ] Create shared error module
- [ ] Extract common initialization
- [ ] Share area calculation via Geometry

#### 6.6 Elixir Concerns
- [ ] Add @spec to all behaviour callbacks
- [ ] Complete @type definitions
- [ ] Add missing @moduledoc
- [ ] Standardize GenServer timeouts
- [ ] Add comprehensive process monitoring
- [ ] Document Supervisor strategies
- [ ] Add handle_continue for slow inits
- [ ] Add @impl true where missing

### Phase 7: Implement Suggestions (Priority: LOW)

#### 7.1 Security Suggestions (Priority: MEDIUM)
- [ ] Add command execution timeout
- [ ] Implement event queue size limits
- [ ] Add max recursion depth to parser
- [ ] Consider SHA verification (deferred - out of scope)

#### 7.2 Consistency Suggestions
- [ ] Create coding standards document
- [ ] Add Credo rules for naming
- [ ] Standardize error response format
- [ ] Document callback ordering

#### 7.3 Redundancy Suggestions
- [ ] Use shared Geometry module (from 4.3)
- [ ] Create shared error module (from 3.1)
- [ ] Unify terminal size detection
- [ ] Common event queue abstraction (from 1.2)
- [ ] Shared capability normalization

#### 7.4 Elixir Suggestions
- [ ] Add comprehensive @type specs
- [ ] Consider TypedStruct (deferred - external dep)
- [ ] Use Application.compile_env where appropriate
- [ ] Add :telemetry hooks (deferred - external dep)
- [ ] Improve Logger usage
- [ ] Add Supervisor.restart_child for recovery
- [ ] Consider :ets for capabilities cache
- [ ] Add benchmarks (deferred - separate feature)
- [ ] Add dialyxir (deferred - separate feature)
- [ ] Add @dialyzer annotations

---

## Notes and Considerations

### Risks

1. **Breaking Changes**: Error handling changes may affect consumers
   - **Mitigation**: Provide migration guide, deprecation period

2. **Performance Impact**: Bounded queue adds overhead
   - **Mitigation**: Benchmark before/after, optimize if needed

3. **Testing Complexity**: More code paths to test
   - **Mitigation**: Leverage property-based tests, increase coverage

4. **Scope Creep**: 85 total items is ambitious
   - **Mitigation**: Focus on blockers first, defer non-critical items

### Dependencies Between Phases

- Phase 2 (child_spec) enables Phase 6.6 (monitoring)
- Phase 4 (deduplication) simplifies Phase 6.5 (redundancy)
- Phase 3.1 (error standardization) should precede other error-related work

### Time Estimates (Developer-Days)

| Phase | Estimate | Notes |
|-------|----------|-------|
| 1. Security Blockers | 3 days | Critical path |
| 2. OTP Blockers | 2 days | Straightforward |
| 3. Consistency Blockers | 2 days | May reveal issues |
| 4. Redundancy Blockers | 3 days | Careful refactoring |
| 5. Planning Doc | 0.5 day | Quick win |
| 6. Concerns | 5 days | Selective approach |
| 7. Suggestions | 5 days | Best effort |
| **Total** | **20.5 days** | ~4 weeks |

### Out of Scope (Defer to Future)

- External dependencies (TypedStruct, Benchee, :telemetry)
- Major architectural changes (would require new phase)
- Visual regression testing infrastructure
- Chaos engineering framework
- Performance benchmarking suite
- Operator runbooks (documentation effort)

---

## Current Status

### What Works
- **Phase 1.1 Complete**: Command injection vulnerability fixed
  - `TermUI.TermUtils` created with safe command execution
  - All `System.cmd` calls for terminal commands now use safe wrapper
  - Security tests passing (command injection attempts blocked)
- Current multi-renderer system is functional
- Feature branch created from clean `multi-renderer`

### What's Next
- Phase 1.2: Bounded Event Queue - Prevent DoS via event flooding
- Create `lib/term_ui/event_queue.ex` with max size and drop-oldest strategy
- Update `lib/term_ui/runtime.ex` to use bounded queue

### How to Run Tests
```bash
# Full test suite
mix test

# Specific test files
mix test test/term_ui/term_utils_test.exs
mix test test/term_ui/backend/tty_test.exs
mix test test/term_ui/runtime_test.exs

# With coverage
mix test --cover

# Credo check
mix credo --strict
```

---

## Change Log

| Date | Action | Status |
|------|--------|--------|
| 2025-01-24 | Created planning document | ✅ Complete |
| 2025-01-24 | Created feature branch | ✅ Complete |
| 2025-01-24 | **Phase 1.1 Complete**: Command injection fix | ✅ Complete |
| 2025-01-24 | **Phase 1.2 Complete**: Bounded event queue | ✅ Complete |
| 2025-01-24 | **Phase 1.3 Complete**: Terminal escape injection | ✅ Complete |
| | Phase 2: OTP Blockers | 🔄 In Progress |
| | Phase 3: Consistency Blockers | ⏳ Pending |
| | Phase 4: Redundancy Blockers | ⏳ Pending |
| | Phase 5: Planning Doc | ⏳ Pending |
| | Phase 6: Concerns | ⏳ Pending |
| | Phase 7: Suggestions | ⏳ Pending |
