defmodule Tabs.App do
  @moduledoc """
  Tabs Widget Example

  This example demonstrates how to use the TermUI.Widgets.Tabs widget
  for organizing content into switchable panels.

  Features demonstrated:
  - Tab bar with multiple tabs
  - Content switching on tab selection
  - Disabled tabs
  - Keyboard navigation
  - Dynamic tab management

  Controls:
  - Left/Right: Navigate between tabs
  - Enter/Space: Select focused tab
  - Home/End: Jump to first/last tab
  - A: Add a new tab
  - D: Remove current tab
  - Q: Quit the application
  """

  use TermUI.Elm

  alias TermUI.Event
  alias TermUI.Renderer.Style

  # ----------------------------------------------------------------------------
  # Component Callbacks
  # ----------------------------------------------------------------------------

  @doc """
  Initialize the component state.
  """
  def init(_opts) do
    %{
      tabs: initial_tabs(),
      selected: :home,
      focused: :home,
      tab_counter: 0
    }
  end

  defp initial_tabs do
    [
      %{id: :home, label: "Home", disabled: false},
      %{id: :profile, label: "Profile", disabled: false},
      %{id: :settings, label: "Settings", disabled: false},
      %{id: :disabled, label: "Disabled", disabled: true}
    ]
  end

  @doc """
  Convert keyboard events to messages.
  """
  def event_to_msg(%Event.Key{key: :left}, _state), do: {:msg, {:move_focus, -1}}
  def event_to_msg(%Event.Key{key: :right}, _state), do: {:msg, {:move_focus, 1}}
  def event_to_msg(%Event.Key{key: :home}, _state), do: {:msg, :focus_first}
  def event_to_msg(%Event.Key{key: :end}, _state), do: {:msg, :focus_last}
  def event_to_msg(%Event.Key{key: :enter}, _state), do: {:msg, :select_focused}
  def event_to_msg(%Event.Key{key: " "}, _state), do: {:msg, :select_focused}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["a", "A"], do: {:msg, :add_tab}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["d", "D"], do: {:msg, :remove_tab}
  def event_to_msg(%Event.Key{key: key}, _state) when key in ["q", "Q"], do: {:msg, :quit}
  def event_to_msg(_event, _state), do: :ignore

  @doc """
  Update state based on messages.
  """
  def update({:move_focus, delta}, state) do
    enabled_tabs = Enum.filter(state.tabs, fn t -> not t.disabled end)
    ids = Enum.map(enabled_tabs, & &1.id)

    case Enum.find_index(ids, &(&1 == state.focused)) do
      nil ->
        {state, []}

      current_idx ->
        new_idx = rem(current_idx + delta + length(ids), length(ids))
        new_focused = Enum.at(ids, new_idx)
        {%{state | focused: new_focused}, []}
    end
  end

  def update(:focus_first, state) do
    first =
      state.tabs
      |> Enum.find(fn t -> not t.disabled end)
      |> case do
        nil -> state.focused
        tab -> tab.id
      end

    {%{state | focused: first}, []}
  end

  def update(:focus_last, state) do
    last =
      state.tabs
      |> Enum.filter(fn t -> not t.disabled end)
      |> List.last()
      |> case do
        nil -> state.focused
        tab -> tab.id
      end

    {%{state | focused: last}, []}
  end

  def update(:select_focused, state) do
    tab = Enum.find(state.tabs, &(&1.id == state.focused))

    if tab && not tab.disabled do
      {%{state | selected: state.focused}, []}
    else
      {state, []}
    end
  end

  def update(:add_tab, state) do
    counter = state.tab_counter + 1
    new_tab = %{id: :"tab_#{counter}", label: "Tab #{counter}", disabled: false}
    tabs = state.tabs ++ [new_tab]
    {%{state | tabs: tabs, tab_counter: counter}, []}
  end

  def update(:remove_tab, state) do
    # Don't remove if only one enabled tab left
    enabled_count = Enum.count(state.tabs, fn t -> not t.disabled end)

    if enabled_count > 1 do
      tabs = Enum.reject(state.tabs, &(&1.id == state.selected))

      # Select a new tab if needed
      {selected, focused} =
        if Enum.any?(tabs, &(&1.id == state.selected)) do
          {state.selected, state.focused}
        else
          first_enabled = Enum.find(tabs, fn t -> not t.disabled end)
          id = if first_enabled, do: first_enabled.id, else: nil
          {id, id}
        end

      {%{state | tabs: tabs, selected: selected, focused: focused}, []}
    else
      {state, []}
    end
  end

  def update(:quit, state) do
    {state, [:quit]}
  end

  @doc """
  Render the current state to a render tree.
  """
  def view(state) do
    stack(:vertical, [
      # Title
      text("Tabs Widget Example", Style.new(fg: :cyan, attrs: [:bold])),
      text("", nil),

      # Tab bar
      render_tab_bar(state),

      # Content area border
      text("┌" <> String.duplicate("─", 50) <> "┐", nil),

      # Content for selected tab
      render_content(state),

      # Content area border
      text("└" <> String.duplicate("─", 50) <> "┘", nil),
      text("", nil),

      # Status
      text("Selected: #{state.selected} | Focused: #{state.focused}", nil),
      text("Tab count: #{length(state.tabs)}", nil),
      text("", nil),

      # Controls
      text("Controls:", Style.new(fg: :yellow)),
      text("  ←/→       Navigate tabs", nil),
      text("  Enter     Select focused tab", nil),
      text("  Home/End  Jump to first/last", nil),
      text("  A         Add new tab", nil),
      text("  D         Remove current tab", nil),
      text("  Q         Quit", nil)
    ])
  end

  # ----------------------------------------------------------------------------
  # Private Helpers
  # ----------------------------------------------------------------------------

  defp render_tab_bar(state) do
    tabs =
      Enum.map(state.tabs, fn tab ->
        render_tab(tab, state)
      end)

    stack(:horizontal, tabs)
  end

  defp render_tab(tab, state) do
    label = " #{tab.label} "

    {decorated, style} =
      cond do
        tab.disabled ->
          {" #{label} ", Style.new(fg: :bright_black)}

        tab.id == state.selected ->
          {"[#{label}]", Style.new(fg: :cyan, attrs: [:bold])}

        tab.id == state.focused ->
          {"(#{label})", Style.new(fg: :white)}

        true ->
          {" #{label} ", Style.new(fg: :white)}
      end

    text(decorated, style)
  end

  defp render_content(state) do
    content_text =
      case state.selected do
        :home ->
          [
            "│  Welcome to the Home tab!                        │",
            "│                                                  │",
            "│  This example demonstrates the Tabs widget.      │",
            "│  Use arrow keys to navigate between tabs.        │"
          ]

        :profile ->
          [
            "│  Profile Tab                                     │",
            "│                                                  │",
            "│  Username: demo_user                             │",
            "│  Email: demo@example.com                         │"
          ]

        :settings ->
          [
            "│  Settings Tab                                    │",
            "│                                                  │",
            "│  Theme: Dark                                     │",
            "│  Language: English                               │"
          ]

        other ->
          [
            "│  #{String.pad_trailing("Content for #{other}", 48)} │",
            "│                                                  │",
            "│  This is a dynamically created tab.              │",
            "│                                                  │"
          ]
      end

    stack(:vertical, Enum.map(content_text, &text(&1, nil)))
  end

  # ----------------------------------------------------------------------------
  # Public API
  # ----------------------------------------------------------------------------

  @doc """
  Run the tabs example application.
  """
  def run do
    TermUI.Runtime.run(root: __MODULE__)
  end
end
