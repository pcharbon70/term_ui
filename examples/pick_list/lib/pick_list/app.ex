defmodule PickList.App do
  @moduledoc """
  PickList Widget Example

  This example demonstrates how to use the TermUI.Widget.PickList widget
  for modal selection dialogs with filtering support.

  Features demonstrated:
  - Modal overlay with centered positioning
  - Scrollable list navigation
  - Type-ahead filtering
  - Selection and cancel callbacks
  - Multiple pick lists for different use cases

  Controls:
  - Up/Down: Navigate items
  - Page Up/Down: Jump 10 items
  - Home/End: Jump to first/last item
  - Enter: Confirm selection
  - Escape: Cancel/close picker
  - Typing: Filter items
  - Backspace: Remove filter character
  - 1/2/3: Open different pickers
  - Q: Quit the application
  """

  use TermUI.Elm

  alias TermUI.Event
  alias TermUI.Renderer.Style
  alias TermUI.Widget.PickList

  # Sample data for different pick lists
  @fruits ["Apple", "Apricot", "Avocado", "Banana", "Blackberry", "Blueberry",
           "Cherry", "Coconut", "Cranberry", "Date", "Dragon Fruit", "Fig",
           "Grape", "Grapefruit", "Guava", "Honeydew", "Kiwi", "Lemon",
           "Lime", "Lychee", "Mango", "Melon", "Nectarine", "Orange",
           "Papaya", "Passion Fruit", "Peach", "Pear", "Pineapple", "Plum",
           "Pomegranate", "Raspberry", "Strawberry", "Tangerine", "Watermelon"]

  @colors ["Red", "Orange", "Yellow", "Green", "Blue", "Indigo", "Violet",
           "Pink", "Cyan", "Magenta", "Brown", "Black", "White", "Gray",
           "Teal", "Navy", "Maroon", "Olive", "Coral", "Salmon"]

  @countries ["Argentina", "Australia", "Brazil", "Canada", "China", "Egypt",
              "France", "Germany", "India", "Italy", "Japan", "Kenya",
              "Mexico", "Netherlands", "Norway", "Portugal", "Russia",
              "Spain", "Sweden", "Thailand", "United Kingdom", "United States",
              "Vietnam", "Zimbabwe"]

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.
  """
  def init(_opts) do
    %{
      # Current picker state (nil when no picker open)
      picker: nil,
      picker_state: nil,

      # Selected values
      selected_fruit: nil,
      selected_color: nil,
      selected_country: nil,

      # Status message
      last_action: "Press 1, 2, or 3 to open a picker"
    }
  end

  @doc """
  Convert events to messages.
  """
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"] do
    {:msg, :quit}
  end

  def event_to_msg(%Event.Key{key: "1"}, %{picker: nil}) do
    {:msg, :open_fruit_picker}
  end

  def event_to_msg(%Event.Key{key: "2"}, %{picker: nil}) do
    {:msg, :open_color_picker}
  end

  def event_to_msg(%Event.Key{key: "3"}, %{picker: nil}) do
    {:msg, :open_country_picker}
  end

  def event_to_msg(event, %{picker: picker}) when picker != nil do
    {:msg, {:picker_event, event}}
  end

  def event_to_msg(_event, _state) do
    :ignore
  end

  @doc """
  Update state based on messages.
  """
  def update(:quit, state) do
    {state, [:quit]}
  end

  def update(:open_fruit_picker, state) do
    props = %{
      items: @fruits,
      title: "Select a Fruit",
      width: 35,
      height: 12
    }

    {:ok, picker_state} = PickList.init(props)

    {%{state |
      picker: :fruit,
      picker_state: picker_state,
      last_action: "Fruit picker opened - type to filter"
    }, []}
  end

  def update(:open_color_picker, state) do
    props = %{
      items: @colors,
      title: "Select a Color",
      width: 30,
      height: 10
    }

    {:ok, picker_state} = PickList.init(props)

    {%{state |
      picker: :color,
      picker_state: picker_state,
      last_action: "Color picker opened - type to filter"
    }, []}
  end

  def update(:open_country_picker, state) do
    props = %{
      items: @countries,
      title: "Select a Country",
      width: 40,
      height: 15
    }

    {:ok, picker_state} = PickList.init(props)

    {%{state |
      picker: :country,
      picker_state: picker_state,
      last_action: "Country picker opened - type to filter"
    }, []}
  end

  def update({:picker_event, event}, state) do
    case PickList.handle_event(event, state.picker_state) do
      {:ok, new_picker_state} ->
        {%{state | picker_state: new_picker_state}, []}

      {:ok, new_picker_state, commands} ->
        # Process commands from picker
        state = %{state | picker_state: new_picker_state}
        process_picker_commands(state, commands)
    end
  end

  def update({:selected, item}, state) do
    state =
      case state.picker do
        :fruit -> %{state | selected_fruit: item}
        :color -> %{state | selected_color: item}
        :country -> %{state | selected_country: item}
      end

    {%{state |
      picker: nil,
      picker_state: nil,
      last_action: "Selected: #{item}"
    }, []}
  end

  def update(:cancelled, state) do
    {%{state |
      picker: nil,
      picker_state: nil,
      last_action: "Selection cancelled"
    }, []}
  end

  def update(_msg, state) do
    {state, []}
  end

  defp process_picker_commands(state, commands) do
    Enum.reduce(commands, {state, []}, fn cmd, {s, cmds} ->
      case cmd do
        {:send, _pid, {:select, item}} ->
          {s, [{:send_msg, {:selected, item}} | cmds]}

        {:send, _pid, :cancel} ->
          {s, [{:send_msg, :cancelled} | cmds]}

        _ ->
          {s, cmds}
      end
    end)
  end

  @doc """
  Handle info messages.
  """
  def handle_info(_msg, state) do
    {state, []}
  end

  @doc """
  Render the current state.
  """
  def view(state) do
    stack(:vertical, [
      # Title
      text("PickList Widget Example", Style.new(fg: :cyan, attrs: [:bold])),
      text(""),

      # Instructions
      render_instructions(),
      text(""),

      # Current selections
      render_selections(state),
      text(""),

      # Status
      render_status(state),

      # Picker overlay (if open)
      render_picker(state)
    ])
  end

  # ----------------------------------------------------------------------------
  # Private Helpers
  # ----------------------------------------------------------------------------

  defp render_instructions do
    stack(:vertical, [
      text("Controls:", Style.new(fg: :yellow)),
      text("  1          Open fruit picker"),
      text("  2          Open color picker"),
      text("  3          Open country picker"),
      text(""),
      text("When picker is open:", Style.new(fg: :yellow)),
      text("  Up/Down    Navigate items"),
      text("  PgUp/PgDn  Jump 10 items"),
      text("  Home/End   Jump to first/last"),
      text("  Enter      Confirm selection"),
      text("  Escape     Cancel"),
      text("  Typing     Filter items"),
      text("  Backspace  Remove filter char"),
      text(""),
      text("  Q          Quit")
    ])
  end

  defp render_selections(state) do
    stack(:vertical, [
      text("Current Selections:", Style.new(fg: :green, attrs: [:bold])),
      text(""),
      render_selection("Fruit", state.selected_fruit),
      render_selection("Color", state.selected_color),
      render_selection("Country", state.selected_country)
    ])
  end

  defp render_selection(label, nil) do
    stack(:horizontal, [
      text("  #{String.pad_trailing(label <> ":", 10)}", Style.new(fg: :white)),
      text("(none)", Style.new(fg: :bright_black))
    ])
  end

  defp render_selection(label, value) do
    stack(:horizontal, [
      text("  #{String.pad_trailing(label <> ":", 10)}", Style.new(fg: :white)),
      text(value, Style.new(fg: :cyan, attrs: [:bold]))
    ])
  end

  defp render_status(state) do
    stack(:horizontal, [
      text("Status: ", Style.new(fg: :yellow)),
      text(state.last_action, Style.new(fg: :white))
    ])
  end

  defp render_picker(%{picker: nil}), do: text("")

  defp render_picker(state) do
    # Render the picker with a reasonable area
    area = %{x: 0, y: 0, width: 80, height: 24}
    PickList.render(state.picker_state, area)
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Run the pick list example application.
  """
  def run do
    TermUI.Runtime.run(root: __MODULE__)
  end
end
