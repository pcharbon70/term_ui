defmodule TermUI.Widgets.Tabs do
  @moduledoc """
  Tabs widget for organizing content into switchable panels.

  Tabs display a tab bar with labels and switch between content panels
  when tabs are selected.

  ## Usage

      Tabs.new(
        tabs: [
          %{id: :home, label: "Home", content: home_content()},
          %{id: :settings, label: "Settings", content: settings_content()},
          %{id: :about, label: "About", content: about_content(), disabled: true}
        ],
        on_change: fn tab_id -> IO.puts("Selected: \#{tab_id}") end
      )

  ## Tab Options

  - `:id` - Unique identifier for the tab (required)
  - `:label` - Display text in tab bar (required)
  - `:content` - Content to display when selected (render node)
  - `:disabled` - Whether tab can be selected (default: false)
  - `:closeable` - Whether tab shows close button (default: false)

  ## Keyboard Navigation

  - Left/Right: Move between tabs
  - Enter/Space: Select focused tab
  - Home/End: Jump to first/last tab
  """

  use TermUI.StatefulComponent

  alias TermUI.Event

  @doc """
  Creates new Tabs widget props.

  ## Options

  - `:tabs` - List of tab definitions (required)
  - `:selected` - Initially selected tab ID
  - `:on_change` - Callback when selection changes
  - `:on_close` - Callback when tab is closed
  - `:tab_style` - Style for inactive tabs
  - `:selected_style` - Style for selected tab
  - `:disabled_style` - Style for disabled tabs
  """
  @spec new(keyword()) :: map()
  def new(opts) do
    tabs = Keyword.fetch!(opts, :tabs)

    %{
      tabs: tabs,
      selected: Keyword.get(opts, :selected, get_first_enabled_id(tabs)),
      on_change: Keyword.get(opts, :on_change),
      on_close: Keyword.get(opts, :on_close),
      tab_style: Keyword.get(opts, :tab_style),
      selected_style: Keyword.get(opts, :selected_style),
      disabled_style: Keyword.get(opts, :disabled_style)
    }
  end

  defp get_first_enabled_id(tabs) do
    tabs
    |> Enum.find(fn tab -> not Map.get(tab, :disabled, false) end)
    |> case do
      nil -> nil
      tab -> tab.id
    end
  end

  @impl true
  def init(props) do
    state = %{
      tabs: props.tabs,
      selected: props.selected,
      focused: props.selected,
      on_change: props.on_change,
      on_close: props.on_close,
      tab_style: props.tab_style,
      selected_style: props.selected_style,
      disabled_style: props.disabled_style
    }

    {:ok, state}
  end

  @impl true
  def update(new_props, state) do
    state = %{state | tabs: new_props.tabs}
    {:ok, state}
  end

  @impl true
  def handle_event(%Event.Key{key: :left}, state) do
    state = move_focus(state, -1)
    {:ok, state}
  end

  def handle_event(%Event.Key{key: :right}, state) do
    state = move_focus(state, 1)
    {:ok, state}
  end

  def handle_event(%Event.Key{key: :home}, state) do
    first_id = get_first_enabled_id(state.tabs)
    state = %{state | focused: first_id}
    {:ok, state}
  end

  def handle_event(%Event.Key{key: :end}, state) do
    last_id = get_last_enabled_id(state.tabs)
    state = %{state | focused: last_id}
    {:ok, state}
  end

  def handle_event(%Event.Key{key: key}, state) when key in [:enter, " "] do
    state = select_focused(state)
    {:ok, state}
  end

  def handle_event(%Event.Mouse{action: :click, x: x}, state) do
    # Determine which tab was clicked based on x position
    case find_tab_at_position(state.tabs, x) do
      nil ->
        {:ok, state}

      tab_id ->
        if tab_enabled?(state.tabs, tab_id) do
          state = %{state | selected: tab_id, focused: tab_id}
          notify_change(state)
          {:ok, state}
        else
          {:ok, state}
        end
    end
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  @impl true
  def render(state, area) do
    tab_bar = render_tab_bar(state)
    content = render_content(state, %{area | height: area.height - 1})

    stack(:vertical, [tab_bar, content])
  end

  # Private functions

  defp move_focus(state, direction) do
    enabled_tabs = Enum.filter(state.tabs, fn tab -> not Map.get(tab, :disabled, false) end)
    ids = Enum.map(enabled_tabs, & &1.id)

    case Enum.find_index(ids, &(&1 == state.focused)) do
      nil ->
        state

      current_idx ->
        new_idx = rem(current_idx + direction + length(ids), length(ids))
        %{state | focused: Enum.at(ids, new_idx)}
    end
  end

  defp get_last_enabled_id(tabs) do
    tabs
    |> Enum.filter(fn tab -> not Map.get(tab, :disabled, false) end)
    |> List.last()
    |> case do
      nil -> nil
      tab -> tab.id
    end
  end

  defp select_focused(state) do
    if tab_enabled?(state.tabs, state.focused) do
      state = %{state | selected: state.focused}
      notify_change(state)
      state
    else
      state
    end
  end

  defp tab_enabled?(tabs, tab_id) do
    case Enum.find(tabs, &(&1.id == tab_id)) do
      nil -> false
      tab -> not Map.get(tab, :disabled, false)
    end
  end

  defp notify_change(state) do
    if state.on_change do
      state.on_change.(state.selected)
    end
  end

  defp find_tab_at_position(tabs, x) do
    {result, _} =
      Enum.reduce_while(tabs, {nil, 0}, fn tab, {_, offset} ->
        label_len = String.length(tab.label) + 4  # " label " + borders
        if x >= offset and x < offset + label_len do
          {:halt, {tab.id, offset}}
        else
          {:cont, {nil, offset + label_len}}
        end
      end)

    result
  end

  defp render_tab_bar(state) do
    tabs =
      Enum.map(state.tabs, fn tab ->
        label = " #{tab.label} "

        # Add close button if closeable
        label =
          if Map.get(tab, :closeable, false) do
            label <> "×"
          else
            label
          end

        # Determine style
        style =
          cond do
            Map.get(tab, :disabled, false) ->
              state.disabled_style

            tab.id == state.selected ->
              state.selected_style

            tab.id == state.focused ->
              # Could add focused style
              state.tab_style

            true ->
              state.tab_style
          end

        # Add visual indicator for selected/focused
        label =
          cond do
            tab.id == state.selected -> "[#{label}]"
            tab.id == state.focused -> "(#{label})"
            true -> " #{label} "
          end

        if style do
          styled(text(label), style)
        else
          text(label)
        end
      end)

    stack(:horizontal, tabs)
  end

  defp render_content(state, _area) do
    case Enum.find(state.tabs, &(&1.id == state.selected)) do
      nil ->
        empty()

      tab ->
        Map.get(tab, :content, empty())
    end
  end

  # Public API

  @doc """
  Gets the currently selected tab ID.
  """
  @spec get_selected(map()) :: term()
  def get_selected(state) do
    state.selected
  end

  @doc """
  Selects a tab by ID.
  """
  @spec select(map(), term()) :: map()
  def select(state, tab_id) do
    if tab_enabled?(state.tabs, tab_id) do
      %{state | selected: tab_id, focused: tab_id}
    else
      state
    end
  end

  @doc """
  Adds a new tab.
  """
  @spec add_tab(map(), map()) :: map()
  def add_tab(state, tab) do
    %{state | tabs: state.tabs ++ [tab]}
  end

  @doc """
  Removes a tab by ID.
  """
  @spec remove_tab(map(), term()) :: map()
  def remove_tab(state, tab_id) do
    tabs = Enum.reject(state.tabs, &(&1.id == tab_id))

    # If removed tab was selected, select first enabled
    selected =
      if state.selected == tab_id do
        get_first_enabled_id(tabs)
      else
        state.selected
      end

    %{state | tabs: tabs, selected: selected}
  end

  @doc """
  Returns the number of tabs.
  """
  @spec tab_count(map()) :: non_neg_integer()
  def tab_count(state) do
    length(state.tabs)
  end
end
