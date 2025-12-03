# StreamWidget Example

A demonstration of the TermUI StreamWidget for displaying backpressure-aware streaming data with GenStage integration.

## Widget Overview

The StreamWidget provides real-time display of streaming data with built-in buffer management and GenStage integration. It handles backpressure automatically and provides controls for stream management, making it ideal for applications that need to display continuous data flows like logs, events, or sensor readings.

**Key Features:**
- GenStage integration for demand-based streaming
- Configurable buffer with overflow strategies
- Pause/resume controls
- Real-time statistics (items/sec, buffer usage)
- Scrollable buffer navigation
- Multiple overflow strategies (drop oldest, drop newest, block, sliding)

**When to Use:**
- Log viewers and monitoring applications
- Real-time event streams
- Data pipeline visualization
- Any application displaying continuous data flows

## Widget Options

The `StreamWidget.new/1` function accepts these options:

- `:buffer_size` - Maximum items in buffer (default: 1000)
- `:overflow_strategy` - What to do when buffer is full (default: `:drop_oldest`)
  - `:drop_oldest` - Remove oldest items to make room
  - `:drop_newest` - Discard new items when full
  - `:block` - Stop accepting items until space is available
  - `:sliding` - Same as `:drop_oldest`
- `:demand` - How many items to request at a time from producer (default: 10)
- `:show_stats` - Display statistics bar (default: true)
- `:render_rate_ms` - Minimum time between renders in ms (default: 100)
- `:item_renderer` - Function to render each item: `fn item -> String.t()`
- `:on_item` - Callback when item is received: `fn item -> ... end`
- `:on_error` - Callback when error occurs: `fn error -> ... end`

## Example Structure

This example consists of:

- `lib/stream_widget/app.ex` - Main application demonstrating:
  - StreamWidget initialization
  - GenStage producer/consumer integration
  - Pause/resume controls
  - Buffer management
  - Overflow strategy switching
  - Real-time statistics display
- `lib/stream_widget/producer.ex` - GenStage producer that generates sample events
- `lib/stream_widget/application.ex` - Application supervisor
- `mix.exs` - Mix project configuration
- `run.exs` - Helper script to run the example

## Running the Example

From this directory:

```bash
# Run with the helper script
elixir run.exs

# Or run directly with mix
mix run -e "StreamWidget.App.run()" --no-halt
```

## Controls

### Stream Control
- **Space** - Start/pause/resume streaming

### Buffer Management
- **c** - Clear buffer
- **s** - Toggle statistics display

### Overflow Strategy
- **1** - Set strategy to drop oldest items
- **2** - Set strategy to drop newest items
- **3** - Set strategy to block when full
- **4** - Set strategy to sliding window

### Event Rate
- **+** - Increase event rate (decrease interval)
- **-** - Decrease event rate (increase interval)

### Navigation
- **Up/Down** - Scroll through buffer items
- **Page Up/Page Down** - Scroll by page
- **Home** - Jump to first item
- **End** - Jump to last item

### Application
- **Q** or **Escape** - Quit

## Statistics Display

When enabled, the widget shows:
- **Status** - Current stream state (IDLE, RUNNING, PAUSED)
- **Buffer** - Current items / maximum capacity
- **Strategy** - Active overflow strategy
- **Received** - Total items received
- **Dropped** - Total items dropped due to overflow
- **Rate** - Current items per second

## GenStage Integration

The example demonstrates proper GenStage integration:

1. A Producer (`StreamWidgetExample.Producer`) generates events at a configurable interval
2. A Consumer (`StreamWidget.Consumer`) subscribes to the producer
3. The StreamWidget manages demand and backpressure
4. Events flow through the pipeline respecting the buffer capacity and overflow strategy
