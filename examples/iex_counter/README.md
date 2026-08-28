# IEx Counter Example

A simple counter example demonstrating TermUI's IEx compatibility.

## Running

### TTY Mode (IEx Compatible)

This example is designed to be run directly in IEx:

```bash
cd examples/iex_counter
iex -S mix
```

Once in IEx, run the counter:

```elixir
iex> IExCounter.App.run()
```

### Raw Mode (Full TUI Experience)

You can also run this as a standalone application with full terminal control:

```bash
cd examples/iex_counter
mix termui.run
```

## Controls

| Key | Action |
|-----|--------|
| ↑ | Increment counter |
| ↓ | Decrement counter |
| R | Reset counter to 0 |
| Q | Quit (returns to IEx prompt) |

IEx keeps the terminal in cooked mode. Some shells deliver these keys
immediately, while others buffer them until Enter is pressed.

## What This Demonstrates

1. **No code changes needed** - The same app works in IEx and standalone
2. **Keyboard input works** - Arrow keys, Q, R all work correctly
3. **Clean shutdown** - Terminal state is restored when you quit
4. **Return to IEx** - You're back at the IEx prompt, ready for more commands

## Detection

The app displays whether it's running in IEx or standalone mode at the top.

You can also check programmatically:

```elixir
iex> TermUI.iex_mode?()
true

iex> TermUI.running_mode()
:iex
```
