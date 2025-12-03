# PickList Example

A demonstration of the PickList widget for modal selection dialogs with filtering support.

## Widget Overview

The PickList widget displays a centered modal overlay with a scrollable list of items. It provides keyboard navigation and type-ahead filtering, making it ideal for selection dialogs where users choose from a list of options.

### Key Features

- Modal overlay with centered positioning
- Scrollable list navigation
- Type-ahead filtering (incremental search)
- Keyboard navigation (arrows, page up/down, home/end)
- Selection and cancel callbacks
- Automatic scroll adjustment to keep selection visible
- Border and status line display
- Handles empty results gracefully

### When to Use

Use PickList when you need to:
- Present a searchable list of options
- Create file or item picker dialogs
- Allow users to select from a large dataset
- Provide quick filtering via typing
- Create modal selection interfaces

## Widget Options

The PickList widget accepts the following options in its `init/1` function (via props map):

- `:items` - List of items to display (required)
- `:title` - Modal title (default: "Select")
- `:width` - Modal width in characters (default: 40)
- `:height` - Modal height in characters (default: 10)
- `:style` - Border/text style options (map)
- `:highlight_style` - Style for selected item (default: `%{fg: :black, bg: :white}`)
- `:on_select` - Callback when item selected (not used in this example)
- `:on_cancel` - Callback when cancelled (not used in this example)

### Example Usage

```elixir
props = %{
  items: ["Apple", "Banana", "Cherry"],
  title: "Select Fruit",
  width: 35,
  height: 12
}

{:ok, picker_state} = PickList.init(props)
```

## Example Structure

This example contains:

- `lib/pick_list/app.ex` - Main application demonstrating the PickList widget
  - Three different pickers: Fruits, Colors, and Countries
  - Type-ahead filtering demonstration
  - Selection handling with state updates
  - Cancel handling

The example maintains:
- Current picker state (which picker is open)
- Selected values for each picker
- Status messages for user feedback

## Running the Example

From the `examples/pick_list` directory:

```bash
mix deps.get
mix run -e "PickList.App.run()"
```

Or using the Mix task:

```bash
mix pick_list
```

## Controls

### Opening Pickers
- **1** - Open fruit picker (35 items)
- **2** - Open color picker (20 items)
- **3** - Open country picker (24 items)

### When Picker is Open

#### Navigation
- **Up/Down** - Navigate items
- **Page Up/Down** - Jump 10 items
- **Home/End** - Jump to first/last item

#### Selection
- **Enter** - Confirm selection
- **Escape** - Cancel and close picker

#### Filtering
- **Type any character** - Start/extend filter (case-insensitive)
- **Backspace** - Remove last filter character

### General
- **Q** - Quit the application (only when picker is closed)

## Features Demonstrated

1. **Multiple Pickers** - Three different pickers with different data sets
2. **Type-Ahead Filtering** - Real-time filtering as you type
3. **Selection Tracking** - Shows current selections for each picker
4. **Status Updates** - Displays feedback for actions
5. **Modal Positioning** - Automatically centers picker in terminal
6. **Scroll Management** - Keeps selected item visible during navigation
7. **Empty Results** - Handles "no matches" gracefully

## Sample Data

### Fruit Picker (35 items)
Apple, Apricot, Avocado, Banana, Blackberry, Blueberry, Cherry, Coconut, and more

### Color Picker (20 items)
Red, Orange, Yellow, Green, Blue, Indigo, Violet, Pink, Cyan, Magenta, and more

### Country Picker (24 items)
Argentina, Australia, Brazil, Canada, China, Egypt, France, Germany, India, and more

## Implementation Notes

- Picker state is managed via commands pattern
- Selection sends `{:send, pid, {:select, item}}` command
- Cancel sends `{:send, pid, :cancel}` command
- Filter resets selection to first matching item
- Modal is rendered as a cell-based overlay
- Status line shows current position (e.g., "Item 5 of 20")
- Filter line appears when typing
