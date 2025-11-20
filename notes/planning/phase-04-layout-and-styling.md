# Phase 4: Layout and Styling

## Overview

This phase implements the layout engine that positions components within the terminal window and the styling system that controls visual presentation. Layout uses constraint-based solving to distribute space according to component requirements—fixed sizes, percentages, minimum/maximum bounds, and flexible filling. Styling provides a consistent approach to colors, text attributes, and visual properties across all components.

By the end of this phase, we will have constraint types defining how components request space, a constraint solver implementing Cassowary-inspired algorithms in pure Elixir, a layout cache with LRU eviction for performance, Flexbox-inspired alignment for positioning within allocated space, a style system supporting all terminal visual features, and a theme system enabling runtime appearance switching.

The layout system integrates with Container components from Phase 3—containers implement `layout/3` callbacks using the constraint solver to position children. The styling system integrates with the rendering engine from Phase 2—styles translate to Cell properties for rendering. Together, layout and styling provide the visual foundation for professional-looking TUI applications.

---

## 4.1 Constraint Types

- [ ] **Section 4.1 Complete**

Constraint types express how components request space from the layout system. We implement constraint types matching common UI patterns: exact length (pixels/cells), percentage of parent, ratio relative to siblings, minimum/maximum bounds, and flexible fill. Constraints combine with direction (horizontal/vertical) and alignment to fully specify layout behavior.

Constraints are declarative—they describe desired outcome, not how to achieve it. The solver translates constraints into concrete pixel positions. This separation allows components to specify requirements without knowing their context. We design constraints to be composable—multiple constraints on the same dimension combine sensibly.

### 4.1.1 Length Constraint

- [ ] **Task 4.1.1 Complete**

Length constraints specify exact sizes in terminal cells. This is the simplest constraint—the component gets exactly the requested size. Length is used for fixed-size elements like buttons, icons, and status bars.

- [ ] 4.1.1.1 Define `Constraint.length(n)` returning constraint for exactly n cells
- [ ] 4.1.1.2 Implement length validation ensuring non-negative integer
- [ ] 4.1.1.3 Implement length constraint solving returning requested size
- [ ] 4.1.1.4 Handle overflow when length exceeds available space (truncate with warning)

### 4.1.2 Percentage Constraint

- [ ] **Task 4.1.2 Complete**

Percentage constraints specify size as a fraction of the parent container's size. This enables responsive layouts that adapt to terminal resizing. Percentages are common for multi-pane layouts (50% left, 50% right).

- [ ] 4.1.2.1 Define `Constraint.percentage(p)` returning constraint for p% of parent (0-100)
- [ ] 4.1.2.2 Implement percentage validation ensuring valid range
- [ ] 4.1.2.3 Implement percentage calculation from parent size
- [ ] 4.1.2.4 Handle rounding for sub-cell percentages (round to nearest integer)

### 4.1.3 Ratio Constraint

- [ ] **Task 4.1.3 Complete**

Ratio constraints distribute space proportionally among siblings. Components with ratio constraints share remaining space after fixed/percentage allocations. Ratios are useful for weighted distribution (sidebar 1:3 main content).

- [ ] 4.1.3.1 Define `Constraint.ratio(r)` returning constraint for ratio r of remaining space
- [ ] 4.1.3.2 Implement ratio calculation distributing space proportionally
- [ ] 4.1.3.3 Handle multiple ratio constraints dividing space by ratio weights
- [ ] 4.1.3.4 Handle zero remaining space when ratios can't be satisfied

### 4.1.4 Min/Max Constraints

- [ ] **Task 4.1.4 Complete**

Min/max constraints bound other constraints to ensure usability. Min prevents components from becoming too small to display content. Max prevents components from wasting space by growing too large. These combine with other constraints as bounds.

- [ ] 4.1.4.1 Define `Constraint.min(n)` returning constraint for at least n cells
- [ ] 4.1.4.2 Define `Constraint.max(n)` returning constraint for at most n cells
- [ ] 4.1.4.3 Implement min/max as bounds on primary constraint
- [ ] 4.1.4.4 Implement `Constraint.min_max(min, max)` for combined bounds

### 4.1.5 Fill Constraint

- [ ] **Task 4.1.5 Complete**

Fill constraint takes all remaining space after other constraints are satisfied. It's equivalent to ratio(1) when only one fill exists. Fill is common for main content areas that should use available space.

- [ ] 4.1.5.1 Define `Constraint.fill()` returning constraint for remaining space
- [ ] 4.1.5.2 Implement fill as ratio(1) for consistent calculation
- [ ] 4.1.5.3 Handle multiple fills distributing equally
- [ ] 4.1.5.4 Handle zero remaining space returning zero for fill

### 4.1.6 Constraint Composition

- [ ] **Task 4.1.6 Complete**

Constraints compose to express complex requirements. We support constraint math: `percentage(50) |> min(10)` means 50% but at least 10. Composition follows algebraic laws enabling optimization. The solver handles composed constraints by solving inner constraints first.

- [ ] 4.1.6.1 Implement constraint piping with `|>` for readable composition
- [ ] 4.1.6.2 Implement `Constraint.with_min/2` and `with_max/2` for bounds
- [ ] 4.1.6.3 Implement constraint simplification for optimization
- [ ] 4.1.6.4 Document constraint composition semantics with examples

### Unit Tests - Section 4.1

- [ ] **Unit Tests 4.1 Complete**
- [ ] Test length constraint returns exact requested size
- [ ] Test percentage constraint calculates correct fraction of parent
- [ ] Test ratio constraint distributes space proportionally
- [ ] Test min constraint enforces minimum size
- [ ] Test max constraint enforces maximum size
- [ ] Test fill constraint uses all remaining space
- [ ] Test constraint composition applies bounds correctly
- [ ] Test overflow handling when constraints exceed space

---

## 4.2 Constraint Solver

- [ ] **Section 4.2 Complete**

The constraint solver translates constraints into concrete cell positions and sizes. We implement a Cassowary-inspired algorithm that handles the common layout cases efficiently. The solver processes constraints in priority order: fixed first, then bounded, then flexible. This produces deterministic, predictable layouts.

The solver is implemented in pure Elixir without external dependencies, keeping the framework self-contained. We optimize for the common cases (linear layouts with simple constraints) while supporting more complex scenarios. The solver integrates with the layout cache for performance—repeated identical layouts return cached results instantly.

### 4.2.1 Solver Algorithm

- [ ] **Task 4.2.1 Complete**

The solver algorithm processes constraints in passes: first allocate fixed sizes, then calculate percentages, then distribute ratios. Each pass reduces remaining space for subsequent passes. The algorithm is greedy but produces optimal results for non-conflicting constraints.

- [ ] 4.2.1.1 Implement `Solver.solve(constraints, available_space)` returning sizes list
- [ ] 4.2.1.2 Implement fixed-size pass allocating length constraints
- [ ] 4.2.1.3 Implement percentage pass calculating from parent size
- [ ] 4.2.1.4 Implement ratio pass distributing remaining space
- [ ] 4.2.1.5 Implement bounds enforcement clamping results to min/max

### 4.2.2 Conflict Resolution

- [ ] **Task 4.2.2 Complete**

Constraint conflicts occur when constraints can't all be satisfied—total fixed sizes exceed space, or min bounds conflict. We implement conflict resolution: warn about conflicts, prioritize in defined order (min > fixed > percentage > ratio), and produce best-effort result.

- [ ] 4.2.2.1 Implement conflict detection identifying unsatisfiable constraint sets
- [ ] 4.2.2.2 Implement priority-based resolution preferring higher-priority constraints
- [ ] 4.2.2.3 Implement proportional reduction shrinking constraints proportionally when over-constrained
- [ ] 4.2.2.4 Emit warnings for constraint conflicts to aid debugging

### 4.2.3 Two-Dimensional Layout

- [ ] **Task 4.2.3 Complete**

Layout is inherently two-dimensional—we solve for both width and height. We solve dimensions independently since terminal cells have fixed aspect ratio. Direction (horizontal/vertical) determines which dimension is primary for the layout and which uses component intrinsic size or secondary constraints.

- [ ] 4.2.3.1 Implement horizontal layout solving for widths, using constraints for heights
- [ ] 4.2.3.2 Implement vertical layout solving for heights, using constraints for widths
- [ ] 4.2.3.3 Implement cross-axis sizing using stretch (fill) or intrinsic (content) modes
- [ ] 4.2.3.4 Implement nested layout with recursive solving for container children

### 4.2.4 Position Calculation

- [ ] **Task 4.2.4 Complete**

After solving sizes, we calculate positions—where each component's top-left corner is placed. Positions accumulate along the layout direction with optional gaps. We support absolute positioning for overlays that escape normal flow.

- [ ] 4.2.4.1 Implement position calculation from sizes and direction
- [ ] 4.2.4.2 Implement gap support adding spacing between children
- [ ] 4.2.4.3 Implement absolute positioning for overlay components
- [ ] 4.2.4.4 Implement `solve_to_rects/2` returning positioned rectangles

### 4.2.5 Solver Optimization

- [ ] **Task 4.2.5 Complete**

Solver optimization improves performance for common cases. We detect simple cases (all fixed, single fill) and use fast paths. We avoid allocations in hot paths and use efficient data structures. Optimization is critical since layout runs every resize and frame.

- [ ] 4.2.5.1 Implement fast path for all-fixed-size layouts (simple sum)
- [ ] 4.2.5.2 Implement fast path for single-fill layouts (subtraction)
- [ ] 4.2.5.3 Optimize data structures using tuples over maps in hot paths
- [ ] 4.2.5.4 Benchmark solver performance with typical constraint sets

### Unit Tests - Section 4.2

- [ ] **Unit Tests 4.2 Complete**
- [ ] Test solver produces correct sizes for various constraint combinations
- [ ] Test conflict resolution produces reasonable results with warnings
- [ ] Test two-dimensional layout solves both dimensions correctly
- [ ] Test position calculation produces non-overlapping rectangles
- [ ] Test gap support adds correct spacing
- [ ] Test optimization fast paths produce same results as general solver
- [ ] Test solver performance meets targets (1000 solves/second)

---

## 4.3 Layout Cache

- [ ] **Section 4.3 Complete**

The layout cache stores solved layouts for reuse, avoiding redundant calculation. Layouts change rarely—only on resize or component change—but are queried every frame. Caching provides O(1) lookup for unchanged layouts. We implement LRU eviction to bound memory usage while keeping frequently-used layouts.

The cache key combines constraints and available space. Cache invalidation occurs on terminal resize, component tree changes, or explicit invalidation. We implement cache statistics for monitoring hit rate and tuning size. The cache is thread-safe for concurrent access from multiple component processes.

### 4.3.1 Cache Structure

- [ ] **Task 4.3.1 Complete**

The cache structure stores layout results keyed by constraints and dimensions. We use ETS for fast concurrent access and atomic operations. The structure tracks access times for LRU eviction and entry count for size limiting.

- [ ] 4.3.1.1 Implement cache ETS table with key `{constraints_hash, width, height}`
- [ ] 4.3.1.2 Implement value structure `{solved_rects, access_time}`
- [ ] 4.3.1.3 Implement cache statistics: size, hit count, miss count
- [ ] 4.3.1.4 Implement constraint hashing for efficient key comparison

### 4.3.2 Cache Operations

- [ ] **Task 4.3.2 Complete**

Cache operations include lookup, insert, and invalidation. Lookup returns cached result or nil. Insert adds new result and updates access time. Invalidation removes stale entries. We implement all operations as atomic ETS operations for thread safety.

- [ ] 4.3.2.1 Implement `cache_lookup/3` returning cached result or nil
- [ ] 4.3.2.2 Implement `cache_insert/4` storing result and updating access time
- [ ] 4.3.2.3 Implement `cache_invalidate/1` removing specific entry
- [ ] 4.3.2.4 Implement `cache_clear/0` removing all entries (for resize)

### 4.3.3 LRU Eviction

- [ ] **Task 4.3.3 Complete**

LRU eviction removes least-recently-used entries when cache exceeds size limit. We implement eviction as a background process that periodically scans for stale entries. The eviction strategy balances between memory usage and hit rate.

- [ ] 4.3.3.1 Implement size limit configuration (default 500 entries)
- [ ] 4.3.3.2 Implement access time tracking updated on each lookup
- [ ] 4.3.3.3 Implement eviction pass removing oldest entries when over limit
- [ ] 4.3.3.4 Implement eviction scheduling running periodically or on insert

### 4.3.4 Cache Integration

- [ ] **Task 4.3.4 Complete**

Cache integration wraps the solver with automatic caching. Layout calls first check cache, falling back to solver on miss. The integration is transparent—callers don't know whether result is cached. We provide both cached and uncached entry points for testing.

- [ ] 4.3.4.1 Implement `Layout.solve/3` with automatic caching
- [ ] 4.3.4.2 Implement cache-through pattern checking cache then solving
- [ ] 4.3.4.3 Implement uncached solver access for testing and debugging
- [ ] 4.3.4.4 Implement cache warming for predictable initial performance

### Unit Tests - Section 4.3

- [ ] **Unit Tests 4.3 Complete**
- [ ] Test cache lookup returns stored results
- [ ] Test cache insert stores and retrieves correctly
- [ ] Test cache miss returns nil and triggers solve
- [ ] Test LRU eviction removes oldest entries
- [ ] Test cache size stays within limit
- [ ] Test invalidation removes specific entries
- [ ] Test clear removes all entries
- [ ] Test cache integration uses cache transparently

---

## 4.4 Flexbox-Inspired Alignment

- [ ] **Section 4.4 Complete**

Alignment controls how components are positioned within their allocated space when the content is smaller than the space. We implement Flexbox-inspired alignment for familiarity: justify (main axis), align (cross axis), and self-align (per-component override). Alignment combined with constraints provides precise control over component placement.

The alignment model uses main axis (layout direction) and cross axis (perpendicular). Justify controls distribution along main axis: start, center, end, space-between, space-around. Align controls position on cross axis: start, center, end, stretch. Components can override container alignment with self-align.

### 4.4.1 Justify Content

- [ ] **Task 4.4.1 Complete**

Justify content distributes components along the main axis (layout direction). Options include: start (pack at beginning), center (center in space), end (pack at end), space-between (equal space between), space-around (equal space around each).

- [ ] 4.4.1.1 Implement `justify: :start` positioning components at axis start
- [ ] 4.4.1.2 Implement `justify: :center` centering components in available space
- [ ] 4.4.1.3 Implement `justify: :end` positioning components at axis end
- [ ] 4.4.1.4 Implement `justify: :space_between` distributing space between components
- [ ] 4.4.1.5 Implement `justify: :space_around` distributing space around components

### 4.4.2 Align Items

- [ ] **Task 4.4.2 Complete**

Align items positions components on the cross axis (perpendicular to layout direction). Options include: start, center, end, and stretch. Stretch expands components to fill cross-axis space. This is the container's default for all children.

- [ ] 4.4.2.1 Implement `align: :start` positioning at cross-axis start
- [ ] 4.4.2.2 Implement `align: :center` centering on cross-axis
- [ ] 4.4.2.3 Implement `align: :end` positioning at cross-axis end
- [ ] 4.4.2.4 Implement `align: :stretch` expanding to fill cross-axis

### 4.4.3 Align Self

- [ ] **Task 4.4.3 Complete**

Align self allows individual components to override container alignment. A component with `align_self: :end` aligns to end even if container specifies `:start`. This enables mixed alignment within a single container.

- [ ] 4.4.3.1 Implement `align_self` prop on components
- [ ] 4.4.3.2 Override container alignment when align_self specified
- [ ] 4.4.3.3 Support `:auto` value inheriting container alignment
- [ ] 4.4.3.4 Apply alignment during position calculation

### 4.4.4 Margin and Padding

- [ ] **Task 4.4.4 Complete**

Margin adds space outside components; padding adds space inside. Both affect layout calculations—margin reduces available space for siblings, padding reduces space for children. We support per-side values (top, right, bottom, left) and shorthand.

- [ ] 4.4.4.1 Implement margin props: `margin`, `margin_top/right/bottom/left`
- [ ] 4.4.4.2 Implement padding props: `padding`, `padding_top/right/bottom/left`
- [ ] 4.4.4.3 Implement shorthand parsing: single value, vertical/horizontal, four values
- [ ] 4.4.4.4 Integrate margin/padding into constraint solving

### Unit Tests - Section 4.4

- [ ] **Unit Tests 4.4 Complete**
- [ ] Test justify start positions at beginning
- [ ] Test justify center positions in middle
- [ ] Test justify space_between distributes evenly
- [ ] Test align positions on cross axis correctly
- [ ] Test stretch expands to fill cross axis
- [ ] Test align_self overrides container alignment
- [ ] Test margin adds space outside component
- [ ] Test padding reduces space for children

---

## 4.5 Style System

- [ ] **Section 4.5 Complete**

The style system provides consistent visual presentation across components. Styles define colors (foreground, background), text attributes (bold, italic, underline), and borders. We implement styles as composable structures that can be inherited, merged, and overridden. The style system integrates with terminal capabilities for graceful degradation.

Styles flow from themes to components through inheritance. A component's effective style merges theme defaults, container styles, and component-specific props. We implement style variants for component states (normal, focused, disabled, pressed). The system supports both programmatic styles and declarative style props.

### 4.5.1 Color System

- [ ] **Task 4.5.1 Complete**

The color system supports all terminal color modes: 16 named colors, 256-color palette, and true-color RGB. We implement color types that convert between modes based on terminal capabilities. Named colors provide semantic meaning (success, warning, error) mapped to actual colors by themes.

- [ ] 4.5.1.1 Implement named color atoms: `:black`, `:red`, `:green`, `:yellow`, `:blue`, `:magenta`, `:cyan`, `:white` plus bright variants
- [ ] 4.5.1.2 Implement indexed colors 0-255 for 256-color palette
- [ ] 4.5.1.3 Implement RGB colors as `{r, g, b}` tuples for true-color
- [ ] 4.5.1.4 Implement color conversion: RGB to nearest 256, 256 to nearest 16
- [ ] 4.5.1.5 Implement semantic colors: `:primary`, `:secondary`, `:success`, `:warning`, `:error`

### 4.5.2 Text Attributes

- [ ] **Task 4.5.2 Complete**

Text attributes modify text appearance beyond color. We support: bold (brighter/heavier), dim (darker), italic, underline, blink (rarely used), reverse (swap fg/bg), hidden, and strikethrough. Attributes combine—bold + underline is valid.

- [ ] 4.5.2.1 Implement attribute set as MapSet of attribute atoms
- [ ] 4.5.2.2 Implement attribute toggling: `style |> Style.bold() |> Style.underline()`
- [ ] 4.5.2.3 Implement attribute merging combining sets
- [ ] 4.5.2.4 Implement attribute output generating SGR codes

### 4.5.3 Style Structure

- [ ] **Task 4.5.3 Complete**

The Style structure encapsulates all visual properties. Styles are immutable—modifications return new styles. We implement builder pattern for ergonomic construction and merge for combining styles with precedence.

- [ ] 4.5.3.1 Define `%Style{fg: color, bg: color, attrs: MapSet.t(), border: border_style}`
- [ ] 4.5.3.2 Implement Style.new/0 returning default style
- [ ] 4.5.3.3 Implement builder functions: `fg/2`, `bg/2`, `bold/1`, etc.
- [ ] 4.5.3.4 Implement `Style.merge/2` with later style overriding earlier

### 4.5.4 Style Inheritance

- [ ] **Task 4.5.4 Complete**

Style inheritance allows components to inherit visual properties from ancestors. A component without explicit color inherits from parent. This enables consistent styling across subtrees and reduces repetition. Inheritance follows the component tree.

- [ ] 4.5.4.1 Implement style context tracking inherited styles through component tree
- [ ] 4.5.4.2 Implement selective inheritance inheriting only unset properties
- [ ] 4.5.4.3 Implement style resolution merging inherited and component styles
- [ ] 4.5.4.4 Implement inheritance breaking resetting to theme defaults

### 4.5.5 Style Variants

- [ ] **Task 4.5.5 Complete**

Style variants define different styles for component states: normal, focused, disabled, hovered, pressed. Components switch variants based on state. Variants inherit from normal, overriding specific properties.

- [ ] 4.5.5.1 Implement variant map: `%{normal: style, focused: style, disabled: style}`
- [ ] 4.5.5.2 Implement variant selection based on component state
- [ ] 4.5.5.3 Implement variant inheritance from normal variant
- [ ] 4.5.5.4 Implement custom variant definition for component-specific states

### Unit Tests - Section 4.5

- [ ] **Unit Tests 4.5 Complete**
- [ ] Test named colors map to correct values
- [ ] Test color conversion produces visually similar results
- [ ] Test text attributes combine correctly
- [ ] Test style builder produces correct structure
- [ ] Test style merge overrides with later style
- [ ] Test inheritance resolves unset properties from parent
- [ ] Test variants select correct style for state
- [ ] Test variant inheritance from normal

---

## 4.6 Theme System

- [ ] **Section 4.6 Complete**

The theme system provides application-wide visual consistency and runtime appearance switching. A theme defines colors, typography, and component defaults. Applications can switch themes at runtime for light/dark modes or user customization. The theme system loads themes from configuration and applies them through style inheritance.

Themes are structured as nested maps defining semantic colors and component styles. The system provides built-in themes (default light/dark) and supports custom themes. Theme switching triggers full re-render with new styles. We implement theme-aware components that automatically use theme values.

### 4.6.1 Theme Structure

- [ ] **Task 4.6.1 Complete**

The theme structure defines all customizable visual properties. It includes colors (background, foreground, accent), component defaults (button style, input style), and semantic tokens (success, warning, error). Structure is hierarchical for organization and override.

- [ ] 4.6.1.1 Define theme struct with colors, typography, and component sections
- [ ] 4.6.1.2 Define color section: background, foreground, primary, secondary, accent
- [ ] 4.6.1.3 Define semantic colors: success, warning, error, info
- [ ] 4.6.1.4 Define component section with per-widget style defaults

### 4.6.2 Built-in Themes

- [ ] **Task 4.6.2 Complete**

We provide built-in themes for immediate use: default (dark background, light text), light (light background, dark text), and high-contrast. Built-in themes demonstrate proper structure and provide good defaults.

- [ ] 4.6.2.1 Implement default dark theme with appropriate colors
- [ ] 4.6.2.2 Implement light theme for bright environments
- [ ] 4.6.2.3 Implement high-contrast theme for accessibility
- [ ] 4.6.2.4 Document theme customization with examples

### 4.6.3 Theme Loading

- [ ] **Task 4.6.3 Complete**

Themes load from configuration files or application config. We support JSON and Elixir formats. Theme loading validates structure and provides helpful errors for invalid themes. Partial themes merge with defaults for convenience.

- [ ] 4.6.3.1 Implement theme loading from config file
- [ ] 4.6.3.2 Implement theme validation checking required fields
- [ ] 4.6.3.3 Implement partial theme merge with default theme
- [ ] 4.6.3.4 Implement theme error reporting for invalid configurations

### 4.6.4 Runtime Theme Switching

- [ ] **Task 4.6.4 Complete**

Themes can switch at runtime for user preferences or automatic light/dark modes. Switching updates the theme context and triggers re-render. We implement smooth switching without flicker by batching the update.

- [ ] 4.6.4.1 Implement `set_theme/1` changing active theme
- [ ] 4.6.4.2 Implement theme change notification to all components
- [ ] 4.6.4.3 Implement re-render trigger after theme change
- [ ] 4.6.4.4 Implement theme transition without visual glitches

### 4.6.5 Theme-Aware Components

- [ ] **Task 4.6.5 Complete**

Theme-aware components automatically use theme values for their styles. They subscribe to theme context and re-render on theme changes. This is the default for built-in widgets—custom components opt-in to theme awareness.

- [ ] 4.6.5.1 Implement theme context providing current theme to components
- [ ] 4.6.5.2 Implement `use_theme/0` hook for accessing theme in components
- [ ] 4.6.5.3 Implement theme subscription for automatic re-render on change
- [ ] 4.6.5.4 Update essential widgets to use theme values

### Unit Tests - Section 4.6

- [ ] **Unit Tests 4.6 Complete**
- [ ] Test theme structure contains all required sections
- [ ] Test built-in themes load correctly
- [ ] Test theme loading from config file
- [ ] Test invalid theme produces helpful error
- [ ] Test partial theme merges with defaults
- [ ] Test theme switching updates context
- [ ] Test components re-render on theme change
- [ ] Test theme-aware components use theme values

---

## 4.7 Integration Tests

- [ ] **Section 4.7 Complete**

Integration tests validate layout and styling working together in realistic UIs. We test complex layouts with nested constraints, style inheritance through component trees, theme switching, and resize handling. Tests verify visual correctness through buffer inspection and performance through timing.

### 4.7.1 Complex Layout Testing

- [ ] **Task 4.7.1 Complete**

We test complex layouts combining multiple constraint types, nested containers, and alignment options. Tests verify that all components receive correct positions and sizes, and that layouts adapt correctly to size changes.

- [ ] 4.7.1.1 Test three-pane layout with sidebar, main, and detail using ratio constraints
- [ ] 4.7.1.2 Test form layout with labels and inputs using percentage and fill
- [ ] 4.7.1.3 Test nested containers with different directions
- [ ] 4.7.1.4 Test resize updates all component positions correctly

### 4.7.2 Style Cascade Testing

- [ ] **Task 4.7.2 Complete**

We test style inheritance and cascade through component hierarchies. Tests verify correct resolution order and that overrides work as expected.

- [ ] 4.7.2.1 Test style inheritance from parent to child
- [ ] 4.7.2.2 Test style override at child level
- [ ] 4.7.2.3 Test variant selection based on component state
- [ ] 4.7.2.4 Test theme values propagate to components

### 4.7.3 Theme Integration Testing

- [ ] **Task 4.7.3 Complete**

We test theme loading, switching, and component integration. Tests verify that themes apply correctly and switching updates all components.

- [ ] 4.7.3.1 Test application starts with correct theme
- [ ] 4.7.3.2 Test theme switching updates all component styles
- [ ] 4.7.3.3 Test custom theme loading and application
- [ ] 4.7.3.4 Test theme persistence across sessions

### 4.7.4 Performance Testing

- [ ] **Task 4.7.4 Complete**

We benchmark layout and styling performance to ensure they don't become bottlenecks. Tests measure solver time, cache effectiveness, and style resolution performance.

- [ ] 4.7.4.1 Benchmark layout solving for typical constraint sets
- [ ] 4.7.4.2 Benchmark cache hit rate for common scenarios
- [ ] 4.7.4.3 Benchmark style resolution for deep component trees
- [ ] 4.7.4.4 Verify layout + styling < 5ms for typical frame

---

## Success Criteria

1. **Constraint Types**: All constraint types (length, percentage, ratio, min/max, fill) working correctly
2. **Solver Correctness**: Constraint solver produces correct layouts for all constraint combinations
3. **Cache Performance**: Layout cache achieves 80%+ hit rate for typical usage patterns
4. **Alignment**: Flexbox-inspired alignment positions components correctly within allocated space
5. **Style System**: Complete style support for colors (16/256/RGB), attributes, and inheritance
6. **Theme System**: Runtime theme switching works smoothly with component re-rendering
7. **Test Coverage**: 85% test coverage with comprehensive unit and integration tests

## Provides Foundation

This phase establishes the infrastructure for:
- **Phase 5**: Event system using layout for spatial event routing
- **Phase 6**: Advanced widgets relying on sophisticated layouts (tables, tabs)
- All application development using layout and styling for visual design

## Key Outputs

- Constraint types for expressing layout requirements
- Constraint solver producing positioned rectangles
- Layout cache with LRU eviction for performance
- Flexbox-inspired alignment (justify, align, margins, padding)
- Style system with colors, attributes, and inheritance
- Theme system with built-in themes and runtime switching
- Comprehensive test suite covering layout and styling
- API documentation for layout and styling modules
