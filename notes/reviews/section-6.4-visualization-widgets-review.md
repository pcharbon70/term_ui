# Section 6.4 Visualization Widgets - Code Review

**Date**: 2025-11-29
**Reviewers**: 7 parallel agents (factual, QA, senior-engineer, security, consistency, redundancy, elixir)
**Status**: Review Complete

---

## Executive Summary

All 7 parallel reviewers have completed their analysis. The visualization widgets (BarChart, Sparkline, LineChart, Gauge) are **functionally complete** and meet all planning requirements. However, the review identified several issues requiring attention before production use.

**Overall Grade: B+**

| Aspect | Grade | Notes |
|--------|-------|-------|
| Functionality | A | All requirements met + extras |
| Test Coverage | B- | Good structure, weak verification |
| Security | C | Memory/resource concerns |
| Code Quality | B | Solid but duplicated |
| Consistency | B | Minor naming issues |
| Documentation | A- | Good moduledocs |

---

## Files Reviewed

- `lib/term_ui/widgets/bar_chart.ex` (279 lines)
- `lib/term_ui/widgets/sparkline.ex` (215 lines)
- `lib/term_ui/widgets/line_chart.ex` (283 lines)
- `lib/term_ui/widgets/gauge.ex` (300 lines)
- `test/term_ui/widgets/bar_chart_test.exs`
- `test/term_ui/widgets/sparkline_test.exs`
- `test/term_ui/widgets/line_chart_test.exs`
- `test/term_ui/widgets/gauge_test.exs`

---

## Blockers (Must Fix)

### 1. ETS Memory Leak in LineChart

**Severity**: Critical
**File**: `lib/term_ui/widgets/line_chart.ex:109-128`
**CWE**: CWE-404 (Improper Resource Shutdown or Release)

**Issue**: ETS table created without try/after cleanup. If rendering crashes, the table leaks.

**Current Code**:
```elixir
canvas = :ets.new(:braille_canvas, [:set])
# ... drawing logic (can throw exceptions) ...
:ets.delete(canvas)
```

**Impact**:
- Memory leaks (each leaked table ~100KB+)
- BEAM ETS table limit exhaustion (default ~1400 tables)
- Application crash when table limit reached

**Fix**:
```elixir
canvas = :ets.new(:canvas, [:set, :private])
try do
  # ... drawing logic ...
after
  :ets.delete(canvas)
end
```

### 2. Unbounded Memory Allocation

**Severity**: Critical
**Files**: All 4 widgets
**CWE**: CWE-770 (Allocation of Resources Without Limits)

**Issue**: No bounds checking on width/height parameters. `String.duplicate/2` can allocate gigabytes of memory.

**Attack Vector**:
```elixir
BarChart.render(data: [%{label: "A", value: 100}], width: 2_000_000_000)
# Attempts to allocate ~2GB of memory
```

**Impact**:
- Process crash (OOM)
- BEAM scheduler starvation
- Potential cascade failure

**Fix**:
```elixir
@max_width 1000
@max_height 1000

def render(opts) do
  width = Keyword.get(opts, :width, 40) |> min(@max_width)
  height = Keyword.get(opts, :height, 10) |> min(@max_height)
  # ...
end
```

### 3. Stack Overflow in Bresenham Algorithm

**Severity**: High
**File**: `lib/term_ui/widgets/line_chart.ex:205-229`
**CWE**: CWE-674 (Uncontrolled Recursion)

**Issue**: Drawing extremely long lines causes deep recursion, potentially exhausting the Erlang process stack.

**Attack Vector**:
```elixir
LineChart.render(data: [0, 10], width: 40_000, height: 10)
# ~80,000 recursive calls
```

**Note**: The algorithm is tail-recursive, but validation should still prevent extreme cases.

---

## Concerns (Should Address)

### Security & Input Validation

#### 4. No Input Type Validation
**Files**: All widgets
**Issue**: All widgets assume correct data types without validation.

```elixir
# These will crash with obscure errors:
BarChart.render(data: [%{foo: "bar"}])  # Missing :label, :value
LineChart.render(data: ["not", "numbers"])
Sparkline.render(values: nil)
```

**Recommendation**: Add input validation with helpful error messages.

#### 5. Negative Bar Width
**File**: `lib/term_ui/widgets/bar_chart.ex:83-88`
**Issue**: Long labels can cause negative `bar_width`.

```elixir
max_label_len = data |> Enum.map(&String.length(&1.label)) |> Enum.max()
bar_width = width - max_label_len - value_width - 2
# If max_label_len > width, bar_width is negative
# String.duplicate(char, negative) raises ArgumentError
```

**Recommendation**: Clamp label length and ensure `bar_width >= 0`.

#### 6. Unicode Character Validation
**Files**: BarChart, Gauge
**Issue**: No validation of user-provided characters (`:bar_char`, `:empty_char`).

**Attack Vector**:
```elixir
BarChart.render(data: [...], bar_char: "\u200B")  # Zero-width space
Gauge.render(value: 50, bar_char: "A\u0301\u0302")  # Combining marks
```

**Recommendation**: Validate that characters are single-width printable characters.

### Code Quality

#### 7. Significant Code Duplication (~150 lines)

**Duplicated Patterns**:

| Pattern | Files | Lines |
|---------|-------|-------|
| Value normalization | All 4 | ~40 |
| Number formatting | BarChart, Gauge | ~20 |
| Zone/color finding | Sparkline, Gauge | ~20 |
| Empty data handling | All 4 | ~30 |
| Min/max calculation | 3 widgets | ~20 |
| Style application | 3 widgets | ~20 |

**Value Normalization Examples**:

```elixir
# gauge.ex:223-228
defp normalize_value(value, min, max) when max > min do
  normalized = (value - min) / (max - min)
  max(0, min(1, normalized))
end

# sparkline.ex:112-120
def value_to_bar(value, min, max) when max > min do
  normalized = (value - min) / (max - min)
  normalized = max(0, min(1, normalized))
  # ...
end

# line_chart.ex:172-180
defp value_to_y(value, min, max, canvas_height) when max > min do
  normalized = (value - min) / (max - min)
  # ...
end
```

**Recommendation**: Create `TermUI.Widgets.VisualizationHelper` module.

#### 8. Inconsistent Option Naming

| Widget | Style Option | Variant Option |
|--------|--------------|----------------|
| Dialog | `:backdrop_style`, `:title_style` | - |
| Toast | `:style`, `:icon_style` | - |
| BarChart | `:style`, `:colors` | `:direction` |
| Sparkline | `:style`, `:color_ranges` | - |
| LineChart | `:style` | - |
| Gauge | `:style_type` (unusual), `:zones` | `:style_type` |

**Issues**:
- Gauge uses `:style_type` instead of `:type` or `:variant`
- Color options inconsistent: `:colors` vs `:color_ranges` vs `:zones`

**Recommendation**: Standardize on `:type`/`:variant` for rendering mode, `:color_zones` for threshold-based coloring.

#### 9. Incomplete Typespecs
**Files**: All widgets

**Current**:
```elixir
@spec render(keyword()) :: TermUI.Component.RenderNode.t()
```

**Better**:
```elixir
@type bar_item :: %{label: String.t(), value: number()}
@spec render(
  data: [bar_item()],
  direction: :horizontal | :vertical,
  width: pos_integer(),
  ...
) :: TermUI.Component.RenderNode.t()
```

### Testing

#### 10. Tests Verify Structure, Not Output

**Issue**: Most tests only check node types, not actual rendered content.

**Example** (`bar_chart_test.exs:27-46`):
```elixir
test "renders bars proportional to values" do
  result = BarChart.render(data: [...], width: 10)
  assert first.type == :text  # Only checks type!
  # Should verify: count of "█" characters is proportional to value
end
```

**Recommendation**: Add assertions that verify actual rendered characters.

#### 11. Missing Edge Case Coverage

| Edge Case | BarChart | Sparkline | LineChart | Gauge |
|-----------|----------|-----------|-----------|-------|
| Empty data | ✅ | ✅ | ✅ | ❌ |
| Single value | ❌ | ❌ | ✅ | ❌ |
| All same values | ❌ | ❌ | ❌ | ❌ |
| Min == Max | ❌ | ✅ | ❌ | ✅ |
| Negative values | ❌ | ❌ | ❌ | ❌ |
| Width = 1 | ❌ | ❌ | ❌ | ❌ |

---

## Suggestions (Nice to Have)

### 12. Create Shared Visualization Helper Module

```elixir
defmodule TermUI.Widgets.VisualizationHelper do
  @moduledoc "Shared utilities for visualization widgets"

  @spec normalize(number(), number(), number()) :: float()
  def normalize(value, min, max) when max > min do
    normalized = (value - min) / (max - min)
    max(0, min(1, normalized))
  end
  def normalize(_value, _min, _max), do: 0.5

  @spec format_number(number()) :: String.t()
  def format_number(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 1)
  def format_number(value) when is_integer(value), do: Integer.to_string(value)
  def format_number(value), do: inspect(value)

  @spec find_zone(number(), [{number(), any()}]) :: any() | nil
  def find_zone(value, zones) do
    zones
    |> Enum.sort_by(fn {threshold, _} -> -threshold end)
    |> Enum.find_value(fn {threshold, style} ->
      if value >= threshold, do: style
    end)
  end

  @spec calculate_range([number()], keyword()) :: {number(), number()}
  def calculate_range([], _opts), do: {0, 1}
  def calculate_range(values, opts) do
    min = Keyword.get(opts, :min, Enum.min(values))
    max = Keyword.get(opts, :max, Enum.max(values))
    {min, max}
  end
end
```

**Impact**: Eliminates ~150 lines of duplicated code.

### 13. Extract Braille Canvas Module

LineChart's Braille logic (lines 34-282) could be extracted to `TermUI.Widgets.BrailleCanvas` for:
- Reusability in other widgets
- Better testability
- Cleaner LineChart implementation

### 14. Standardize Width Defaults

| Widget | Current Default | Suggested |
|--------|-----------------|-----------|
| BarChart | 40 | 40 |
| Sparkline | (none) | 40 |
| LineChart | 40 | 40 |
| Gauge | 20 | 40 |

### 15. Use IO Lists for Performance

**Current** (`bar_chart.ex:114-115`):
```elixir
bar = String.duplicate(bar_char, bar_length)
empty = String.duplicate(@empty_char, bar_width - bar_length)
line = label <> bar <> empty <> value_str
```

**Better**:
```elixir
line = [
  String.pad_trailing(item.label, max_label_len), " ",
  List.duplicate(bar_char, bar_length),
  List.duplicate(@empty_char, bar_width - bar_length),
  value_str
] |> IO.iodata_to_binary()
```

---

## Good Practices Noticed

### Functionality
- ✅ All planning requirements (6.4.x.x) implemented
- ✅ Additional helper functions beyond requirements (percentage/2, traffic_light/1, etc.)
- ✅ Both bar and arc styles for Gauge
- ✅ Braille patterns correctly implemented in LineChart

### Code Quality
- ✅ Consistent RenderNode integration (`text()`, `stack()`, `styled()`, `empty()`)
- ✅ Empty data handling returns `empty()` in all widgets
- ✅ Good use of guard clauses for division by zero prevention
- ✅ Tail-recursive Bresenham algorithm
- ✅ Pattern matching used effectively throughout

### Documentation
- ✅ Comprehensive `@moduledoc` with usage examples
- ✅ `@spec` declarations on all public functions
- ✅ Braille cell structure documented in LineChart

### Testing
- ✅ 66 tests total, all passing
- ✅ Edge cases tested: empty data, min==max, value clamping
- ✅ Both rendering modes tested (horizontal/vertical, bar/arc)

---

## Test Results

```
mix test test/term_ui/widgets/bar_chart_test.exs \
         test/term_ui/widgets/sparkline_test.exs \
         test/term_ui/widgets/line_chart_test.exs \
         test/term_ui/widgets/gauge_test.exs

Running ExUnit with seed: 497718, max_cases: 40
Excluding tags: [:requires_terminal]

..................................................................
Finished in 0.05 seconds (0.05s async, 0.00s sync)
66 tests, 0 failures
```

| Widget | Tests | Status |
|--------|-------|--------|
| BarChart | 16 | ✅ Pass |
| Sparkline | 17 | ✅ Pass |
| LineChart | 15 | ✅ Pass |
| Gauge | 18 | ✅ Pass |

---

## Reviewer Verdicts

| Reviewer | Verdict | Key Finding |
|----------|---------|-------------|
| Factual | ✅ PASS | All requirements implemented + extras |
| QA | ⚠️ WARN | Tests verify structure, not output |
| Senior Engineer | ⚠️ WARN | ETS leak, code duplication |
| Security | 🚨 BLOCK | Memory allocation, ETS leak, input validation |
| Consistency | ⚠️ WARN | Option naming inconsistencies |
| Redundancy | 💡 SUGGEST | ~150 lines duplicated code |
| Elixir | ⚠️ WARN | Typespecs incomplete, ETS cleanup needed |

---

## Recommended Actions

### P0 - Critical (Before Production)

| # | Issue | File | Action |
|---|-------|------|--------|
| 1 | ETS memory leak | line_chart.ex:109-128 | Wrap in try/after |
| 2 | Unbounded allocation | All widgets | Add max bounds on width/height |
| 3 | Input validation | All widgets | Validate data types |

### P1 - High Priority

| # | Issue | Action |
|---|-------|--------|
| 4 | Code duplication | Create VisualizationHelper module |
| 5 | Incomplete typespecs | Add structured keyword types |
| 6 | Test verification | Add character-counting assertions |

### P2 - Medium Priority

| # | Issue | Action |
|---|-------|--------|
| 7 | Option naming | Rename `:style_type` to `:type` |
| 8 | Edge case tests | Add property-based tests |
| 9 | Braille reuse | Extract BrailleCanvas module |

### P3 - Low Priority

| # | Issue | Action |
|---|-------|--------|
| 10 | Performance | Use IO lists in BarChart |
| 11 | Defaults | Standardize width to 40 |
| 12 | Documentation | Add @doc to private functions |

---

## Conclusion

Section 6.4 Visualization Widgets is **functionally complete** and demonstrates solid Elixir fundamentals. The widgets meet all planning requirements and include additional convenience functions.

**Main concerns**:
1. Security vulnerabilities (ETS leak, unbounded allocation) must be fixed before production
2. Significant code duplication should be addressed for maintainability
3. Tests need functional verification, not just structural checks

**Recommendation**: Address P0 issues immediately, then create the shared VisualizationHelper module to reduce duplication and improve consistency.
