# CommandPalette Widget Example

This example demonstrates the TermUI CommandPalette widget, a simple command dropdown for filtering and selecting commands with keyboard input.

## Widget Overview

The CommandPalette widget provides a searchable command menu similar to typing `/` in applications like Claude Code, Slack, or Discord to see available commands. It features:

- **Substring filtering** - Type to narrow the command list case-insensitively
- **Keyboard navigation** - Arrow keys to select commands
- **Selection handoff** - Enter selects a command for the root application
- **Visible/hidden states** - Toggle dropdown display
- **Scrollable results** - Handle many commands with viewport scrolling

Use CommandPalette when you want to provide a quick-access command menu, implement slash commands, or create a searchable action list without cluttering the UI with buttons or menus.

## Widget Options

The `CommandPalette.new/1` function accepts the following options:

- `:commands` - List of command maps (required), each with:
  - `:id` - Unique identifier (atom)
  - `:label` - Display text shown in dropdown (string)
  - Additional fields are optional application metadata; the widget does not
    execute callbacks
- `:max_visible` - Maximum visible results in dropdown (default: 8)

## Example Structure

The example consists of:

- `lib/command_palette/app.ex` - Main application demonstrating:
  - Opening palette with `/` key
  - Filtering commands as user types
  - Selecting commands and interpreting the selected label in the Elm root
  - Displaying the root's handling result
  - Managing palette visibility state

The example includes sample commands like `/help`, `/save`, `/quit`, `/settings`, etc.

## Running the Example

### Raw Mode (Full TUI Experience)

For the best experience with full terminal control and alternate screen:

```bash
cd examples/command_palette
mix termui.run
```

Or manually:

```bash
cd examples/command_palette
mix run -e "CommandPalette.run()" --no-halt
```

### TTY Mode (IEx Compatible)

To run from IEx without taking over the shell:

```bash
cd examples/command_palette
iex -S mix
```

Then in IEx:

```elixir
CommandPalette.run()
```

**Note:** TTY mode works inside IEx but has limitations:
- Input is read through the shell; some terminals buffer keys until Enter is pressed
- For full TUI, use raw mode instead

## Controls

**When palette is closed:**
- `/` - Open command dropdown

**When palette is open:**
- Type any character - Add to search query and filter commands
- `Backspace` - Remove last character from query
- `↑` / `↓` - Navigate through filtered results
- `Enter` - Select command (closes palette and sets query)
- `Escape` - Close palette without selecting

**General:**
- `Q` - Quit application (when palette closed)

## Implementation Notes

The example demonstrates:

- **Dynamic filtering** - Commands are filtered in real-time as the user types
- **State management** - Tracking query, filtered results, selection, and visibility
- **Keyboard handling** - Different event handling based on palette state
- **Scroll management** - Keeping selected item visible in viewport
- **Result display** - Showing the last command handled by the root

### Implementation Pattern

The example shows a common pattern for command palettes:

1. User presses trigger key (`/`)
2. Palette opens with all commands visible
3. User types to filter commands
4. Arrow keys navigate filtered results
5. Enter selects command (in this example, it populates the query rather than executing)
6. Application handles the selected command

### Extending the Example

To make commands executable immediately, attach application-owned `:action`
metadata and invoke it in the root. The widget never invokes that field itself:

```elixir
def update({:palette_event, %Event.Key{key: :enter}}, state) do
  case CommandPalette.get_selected(state.palette) do
    nil ->
      {state, []}
    %{action: action} when is_function(action, 0) ->
      action.()
      {state, []}

    _command ->
      {state, []}
  end
end
```

## Use Cases

- Slash command interfaces (like Slack, Discord)
- Quick command launchers
- Action menus without permanent UI elements
- Searchable function lists
- Keyboard-driven navigation systems
