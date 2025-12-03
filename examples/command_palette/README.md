# CommandPalette Widget Example

This example demonstrates the TermUI CommandPalette widget, a simple command dropdown for filtering and selecting commands with keyboard input.

## Widget Overview

The CommandPalette widget provides a searchable command menu similar to typing `/` in applications like Claude Code, Slack, or Discord to see available commands. It features:

- **Prefix filtering** - Type to narrow down command list
- **Keyboard navigation** - Arrow keys to select commands
- **Quick execution** - Enter to select command
- **Visible/hidden states** - Toggle dropdown display
- **Scrollable results** - Handle many commands with viewport scrolling

Use CommandPalette when you want to provide a quick-access command menu, implement slash commands, or create a searchable action list without cluttering the UI with buttons or menus.

## Widget Options

The `CommandPalette.new/1` function accepts the following options:

- `:commands` - List of command maps (required), each with:
  - `:id` - Unique identifier (atom)
  - `:label` - Display text shown in dropdown (string)
  - `:action` - Function to execute when selected (0-arity function)
- `:max_visible` - Maximum visible results in dropdown (default: 8)

## Example Structure

The example consists of:

- `lib/command_palette/app.ex` - Main application demonstrating:
  - Opening palette with `/` key
  - Filtering commands as user types
  - Selecting and "executing" commands
  - Displaying execution results
  - Managing palette visibility state

The example includes sample commands like `/help`, `/save`, `/quit`, `/settings`, etc.

## Running the Example

```bash
cd examples/command_palette
mix deps.get
iex -S mix
```

Then in the IEx shell:

```elixir
CommandPalette.App.run()
```

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
- **Result display** - Showing last executed command

### Implementation Pattern

The example shows a common pattern for command palettes:

1. User presses trigger key (`/`)
2. Palette opens with all commands visible
3. User types to filter commands
4. Arrow keys navigate filtered results
5. Enter selects command (in this example, it populates the query rather than executing)
6. Application handles the selected command

### Extending the Example

To make commands executable immediately (instead of just populating the query):

```elixir
def update({:palette_event, %Event.Key{key: :enter}}, state) do
  case CommandPalette.get_selected(state.palette) do
    nil ->
      {state, []}
    command ->
      command.action.()  # Execute the action
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
