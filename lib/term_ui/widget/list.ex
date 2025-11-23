defmodule TermUI.Widget.List do
  @moduledoc """
  A scrollable list widget with selection support.

  List displays items and allows navigation with arrow keys.
  Supports single and multi-select modes.

  ## Usage

      List.render(%{
        items: ["Apple", "Banana", "Cherry"],
        on_select: fn item -> IO.puts("Selected: \#{item}") end
      }, state, area)

  ## Props

  - `:items` - List of items to display (required)
  - `:on_select` - Callback when selection changes
  - `:multi_select` - Enable multi-select mode (default: `false`)
  - `:highlight_style` - Style for selected items
  - `:style` - Default item style
  """

  use TermUI.StatefulComponent

  alias TermUI.Component.RenderNode
  alias TermUI.Event
  alias TermUI.Renderer.Style

  @doc """
  Initializes the list state.
  """
  @impl true
  def init(props) do
    items = Map.get(props, :items, [])

    state = %{
      selected_index: 0,
      selected_indices: MapSet.new(),
      scroll_offset: 0,
      item_count: length(items),
      props: props
    }

    {:ok, state}
  end

  @doc """
  Handles events for the list.
  """
  @impl true
  def handle_event(%Event.Key{key: :up}, state) do
    new_index = max(0, state.selected_index - 1)
    {:ok, %{state | selected_index: new_index}}
  end

  def handle_event(%Event.Key{key: :down}, state) do
    new_index = min(state.item_count - 1, state.selected_index + 1)
    {:ok, %{state | selected_index: max(0, new_index)}}
  end

  def handle_event(%Event.Key{key: :home}, state) do
    {:ok, %{state | selected_index: 0}}
  end

  def handle_event(%Event.Key{key: :end}, state) do
    {:ok, %{state | selected_index: max(0, state.item_count - 1)}}
  end

  def handle_event(%Event.Key{key: :page_up}, state) do
    new_index = max(0, state.selected_index - 10)
    {:ok, %{state | selected_index: new_index}}
  end

  def handle_event(%Event.Key{key: :page_down}, state) do
    new_index = min(state.item_count - 1, state.selected_index + 10)
    {:ok, %{state | selected_index: max(0, new_index)}}
  end

  def handle_event(%Event.Key{key: :enter}, state) do
    # Trigger selection callback
    {:ok, state, [{:send, self(), {:select, state.selected_index}}]}
  end

  def handle_event(%Event.Key{key: :space}, state) do
    # Toggle selection in multi-select mode
    {:ok, state, [{:send, self(), {:toggle, state.selected_index}}]}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  @doc """
  Handles messages to the list.
  """
  @impl true
  def handle_info({:select, index}, state) do
    props = state.props
    items = Map.get(props, :items, [])
    on_select = Map.get(props, :on_select)

    if is_function(on_select, 1) && index < length(items) do
      item = Enum.at(items, index)
      on_select.(item)
    end

    {:ok, state}
  end

  def handle_info({:toggle, index}, state) do
    props = state.props
    multi_select = Map.get(props, :multi_select, false)

    if multi_select do
      selected =
        if MapSet.member?(state.selected_indices, index) do
          MapSet.delete(state.selected_indices, index)
        else
          MapSet.put(state.selected_indices, index)
        end

      {:ok, %{state | selected_indices: selected}}
    else
      {:ok, state}
    end
  end

  def handle_info({:set_items, items}, state) do
    count = length(items)
    new_index = min(state.selected_index, max(0, count - 1))

    {:ok, %{state | item_count: count, selected_index: new_index}}
  end

  def handle_info(_msg, state) do
    {:ok, state}
  end

  @doc """
  Renders the list.
  """
  @impl true
  def render(state, area) do
    props = state.props
    items = Map.get(props, :items, [])
    multi_select = Map.get(props, :multi_select, false)
    style_opts = Map.get(props, :style, %{})
    highlight_opts = Map.get(props, :highlight_style, %{fg: :black, bg: :white})

    style = build_style(style_opts)
    highlight_style = build_style(highlight_opts)

    # Calculate scroll offset to keep selection visible
    scroll_offset = calculate_scroll(state.selected_index, state.scroll_offset, area.height)

    # Render visible items
    cells =
      items
      |> Enum.with_index()
      |> Enum.drop(scroll_offset)
      |> Enum.take(area.height)
      |> Enum.with_index()
      |> Enum.flat_map(fn {{item, item_index}, display_y} ->
        is_selected = item_index == state.selected_index
        is_multi_selected = MapSet.member?(state.selected_indices, item_index)

        item_style = get_item_style(is_selected, is_multi_selected, highlight_style, style)
        text = format_item_text(item, multi_select, is_multi_selected)

        render_item(text, display_y, area.width, item_style)
      end)

    RenderNode.cells(cells)
  end

  # Private Functions

  defp get_item_style(true, _is_multi_selected, highlight_style, _style), do: highlight_style
  defp get_item_style(_is_selected, true, highlight_style, _style), do: highlight_style
  defp get_item_style(_is_selected, _is_multi_selected, _highlight_style, style), do: style

  defp format_item_text(item, true, true), do: "[x] " <> to_string(item)
  defp format_item_text(item, true, false), do: "[ ] " <> to_string(item)
  defp format_item_text(item, false, _is_multi_selected), do: to_string(item)

  defp render_item(text, y, width, style) do
    display_text =
      if String.length(text) > width do
        String.slice(text, 0, width - 1) <> "…"
      else
        String.pad_trailing(text, width)
      end

    display_text
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.filter(fn {_char, x} -> x < width end)
    |> Enum.map(fn {char, x} ->
      positioned_cell(x, y, char, style)
    end)
  end

  defp calculate_scroll(selected, current_scroll, visible_height) do
    cond do
      # Selection above visible area
      selected < current_scroll ->
        selected

      # Selection below visible area
      selected >= current_scroll + visible_height ->
        selected - visible_height + 1

      # Selection visible
      true ->
        current_scroll
    end
  end

  defp build_style(opts) when is_map(opts) do
    style_list =
      opts
      |> Enum.map(fn
        {:fg, color} -> {:fg, color}
        {:bg, color} -> {:bg, color}
        {:bold, true} -> {:attrs, [:bold]}
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)

    Style.new(style_list)
  end

  defp build_style(_), do: Style.new()
end
