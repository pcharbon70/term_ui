# Feature Plan: Fix All Credo Issues

## Problem Statement

The codebase has 165 pre-existing credo issues that need to be addressed:
- 3 warnings (expensive empty enum checks)
- 56 refactoring opportunities
- 104 code readability issues
- 2 software design suggestions (TODOs)

**Impact:** Fixing these issues will:
- Improve code consistency across the codebase
- Follow Elixir community best practices
- Make code more maintainable and readable
- Eliminate potential performance issues

## Solution Overview

Address all credo issues systematically, grouped by type:

1. **Simple fixes** - Alias ordering, large numbers, predicate names
2. **Medium fixes** - Map/join refactoring, negated conditions
3. **Complex fixes** - Cyclomatic complexity, nesting depth

### Key Design Decisions
- Preserve existing functionality while improving code quality
- Use consistent patterns across the codebase
- Break complex functions into smaller, focused helpers

## Technical Details

### Issue Categories

#### Readability Issues (104)
- Alias ordering (~40)
- Large numbers without underscores (~25)
- Predicate function names (7)
- Prefer implicit try (4)

#### Refactoring Issues (56)
- Map/join inefficiency (~10)
- Negated conditions with else (~10)
- Nesting too deep (~15)
- Cyclomatic complexity (6)
- Function arity (1)
- Cond statements (1)
- Unless with else (1)

#### Warnings (3)
- Expensive empty enum checks

#### Design (2)
- TODO tags

## Implementation Plan

### Task 1: Simple Readability Fixes

- [x] 1.1 Fix alias ordering in all files (55 files fixed)
- [x] 1.2 Fix large numbers formatting (24 occurrences fixed)
- [x] 1.3 Rename predicate functions (8 functions renamed, 26 call sites updated)
- [x] 1.4 Convert explicit try to implicit try (8 occurrences fixed)

### Task 2: Refactoring - Easy

- [x] 2.1 Convert Enum.map |> Enum.join to Enum.map_join (already done)
- [x] 2.2 Fix negated conditions with else (8 occurrences fixed)
- [x] 2.3 Fix unless with else (1 occurrence fixed)
- [x] 2.4 Fix cond statements with only one condition (1 occurrence fixed)
- [x] 2.5 Fix expensive empty enum checks (3 occurrences fixed)

### Task 3: Refactoring - Complex

- [x] 3.1 Fix function nesting depth issues (18 occurrences fixed)
- [x] 3.2 Fix cyclomatic complexity issues (6 functions refactored)
- [x] 3.3 Fix high arity function (3 functions refactored)

### Task 4: Design Issues

- [x] 4.1 Address TODO comments (2 converted to FIXME)

### Task 5: Final Steps

- [x] 5.1 Run full test suite (1203 tests passed)
- [x] 5.2 Verify credo --strict passes (0 errors, only 2 FIXME suggestions)
- [x] 5.3 Format code with mix format

## Success Criteria

1. `mix credo --strict` returns no issues
2. All tests pass
3. No functionality changes
4. Code is properly formatted

## Notes/Considerations

- Some cyclomatic complexity issues may require significant refactoring
- Predicate function renames will need to update all call sites
- TODOs represent actual work that needs to be done - may convert to FIXME or address
