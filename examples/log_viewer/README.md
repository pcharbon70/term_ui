# LogViewer Example

A demonstration of the LogViewer widget for displaying and analyzing log data with virtual scrolling.

## Widget Overview

The LogViewer widget efficiently displays large log files (millions of lines) using virtual scrolling. It provides powerful features for searching, filtering, and analyzing logs in real-time.

### Key Features

- Virtual scrolling for efficient rendering of large datasets
- Tail mode for live log monitoring
- Search with regex support and match highlighting
- Syntax highlighting for log levels and timestamps
- Filtering by pattern with regex support
- Line bookmarking for marking important entries
- Selection for copy operations
- Wrap/truncate toggle for long lines
- Automatic log parsing (timestamp, level, source)

### When to Use

Use LogViewer when you need to:
- Monitor application logs in real-time
- Search through large log files efficiently
- Debug issues by filtering specific patterns
- Track important log entries with bookmarks
- Analyze log levels and patterns

## Widget Options

The LogViewer widget accepts the following options in its `new/1` function:

- `:lines` - Initial log lines (strings or log entries)
- `:max_lines` - Maximum lines to keep in buffer (default: 100,000)
- `:tail_mode` - Auto-scroll to new lines (default: true)
- `:wrap_lines` - Wrap long lines instead of truncating (default: false)
- `:show_line_numbers` - Display line numbers (default: true)
- `:show_timestamps` - Display timestamps column (default: false)
- `:show_levels` - Display level column (default: true)
- `:highlight_levels` - Color-code by level (default: true)
- `:on_select` - Callback when lines are selected
- `:on_copy` - Callback when copy is requested
- `:parser` - Custom log parser function

### Example Usage

```elixir
LogViewer.new(
  lines: log_lines,
  tail_mode: true,
  highlight_levels: true,
  show_line_numbers: true,
  max_lines: 10_000
)
```

## Example Structure

This example contains:

- `lib/log_viewer/app.ex` - Main application demonstrating the LogViewer widget
  - Generates simulated log entries from multiple modules
  - Demonstrates various log levels (debug, info, warning, error)
  - Shows dynamic log addition and clearing
  - Integrates all LogViewer features

## Running the Example

From the `examples/log_viewer` directory:

```bash
mix deps.get
mix run -e "LogViewer.App.run()"
```

Or using the Mix task:

```bash
mix log_viewer
```

## Controls

### Navigation
- **Up/Down** - Navigate between lines
- **PageUp/PageDown** - Scroll by page (20 lines)
- **Home/End** - Jump to first/last line

### Search
- **/** - Start search (supports regex)
- **n/N** - Next/previous search match
- **Escape** - Clear search

### Filtering
- **f** - Toggle filter mode (or start filter input)
- **Escape** - Clear filter

### Bookmarks
- **b** - Toggle bookmark on current line
- **B** - Jump to next bookmark

### Display Modes
- **t** - Toggle tail mode (auto-scroll to new entries)
- **w** - Toggle wrap mode (wrap vs truncate long lines)

### Selection
- **Space** - Start or extend selection
- **Escape** - Clear selection

### Data Management
- **A** - Add 5 simulated log entries
- **C** - Clear all logs
- **Q** - Quit the application

## Features Demonstrated

1. **Automatic Parsing** - Extracts timestamps, log levels, and module names
2. **Level Highlighting** - Color codes by severity (debug=cyan, info=green, warning=yellow, error=red)
3. **Virtual Scrolling** - Efficiently renders only visible lines
4. **Search & Highlight** - Find patterns with regex and highlight matches
5. **Filtering** - Show only lines matching a pattern
6. **Tail Mode** - Automatically scrolls to new entries
7. **Bookmarks** - Mark and jump between important lines
8. **Status Bar** - Shows current line, filter status, search results

## Log Format

The example generates logs in this format:

```
2024-01-15T10:30:45.123Z [MyApp.Server] INFO: Request processed successfully
```

The parser automatically extracts:
- Timestamp (ISO8601 format)
- Source module (in brackets)
- Log level (DEBUG, INFO, WARNING, ERROR)
- Message text

## Implementation Notes

- Initial dataset contains 50 log entries
- Each "Add logs" action adds 5 new entries
- Logs are kept in a circular buffer (max 10,000 lines by default)
- Virtual scrolling renders only visible lines for performance
- Search and filter use regex patterns (case-insensitive)
