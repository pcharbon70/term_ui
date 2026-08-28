# StreamWidget Example

A demonstration of the TermUI StreamWidget with a bounded buffer and a GenStage consumer adapter.

## Widget Overview

The StreamWidget provides real-time display of streaming data with built-in
buffer management. The example connects a GenStage consumer to the root runtime,
which forwards event batches into the embedded widget state.

**Key Features:**
- GenStage consumer integration using normal subscription demand
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
  - `:block` - Compatibility name that rejects/counts new items when full in 1.0
  - `:sliding` - Same as `:drop_oldest`
- `:demand` - Reserved widget metadata (default: 10); configure actual demand
  with `max_demand`/`min_demand` when subscribing
- `:show_stats` - Display statistics bar (default: true)
- `:render_rate_ms` - Reserved widget metadata (default: 100); it does not
  throttle the runtime render loop in 1.0
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

### Raw Mode (Full TUI Experience)

For the best experience with full terminal control and alternate screen:

```bash
cd examples/stream_widget
mix termui.run
```

Or manually:

```bash
cd examples/stream_widget
mix run -e "StreamWidgetExample.App.run()" --no-halt
```

### TTY Mode (IEx Compatible)

To run from IEx without taking over the shell:

```bash
cd examples/stream_widget
iex -S mix
```

Then in IEx:

```elixir
StreamWidgetExample.App.run()
```

**Note:** TTY mode works inside IEx but has limitations:
- Input is read through the shell; some terminals buffer keys until Enter is pressed
- For full TUI, use raw mode instead

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
2. A Consumer (`StreamWidget.Consumer`) subscribes to the producer and sends
   batches to the root runtime process
3. The root's `handle_info/2` forwards batches into the embedded widget state
4. GenStage applies configured subscription demand; the widget independently
   applies its buffer capacity and overflow strategy
