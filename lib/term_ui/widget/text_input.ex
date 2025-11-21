defmodule TermUI.Widget.TextInput do
  @moduledoc """
  A single-line text input widget.

  TextInput allows users to type text, navigate with arrow keys,
  and delete with backspace/delete.

  ## Usage

      TextInput.render(%{
        placeholder: "Enter name...",
        on_change: fn value -> IO.puts("Value: \#{value}") end,
        on_submit: fn value -> IO.puts("Submitted: \#{value}") end
      }, state, area)

  ## Props

  - `:value` - Initial value (default: `""`)
  - `:placeholder` - Placeholder text when empty
  - `:on_change` - Callback when value changes
  - `:on_submit` - Callback when Enter pressed
  - `:max_length` - Maximum input length
  - `:style` - Input style
  - `:cursor_style` - Cursor character style
  """

  use TermUI.StatefulComponent

  alias TermUI.Event
  alias TermUI.Renderer.Style
  alias TermUI.Component.RenderNode

  @doc """
  Initializes the text input state.
  """
  @impl true
  def init(props) do
    value = Map.get(props, :value, "")

    state = %{
      value: value,
      cursor: String.length(value),
      scroll_offset: 0,
      props: props
    }

    {:ok, state}
  end

  @doc """
  Handles events for the text input.
  """
  @impl true
  def handle_event(%Event.Key{key: :left}, state) do
    new_cursor = max(0, state.cursor - 1)
    {:ok, %{state | cursor: new_cursor}}
  end

  def handle_event(%Event.Key{key: :right}, state) do
    new_cursor = min(String.length(state.value), state.cursor + 1)
    {:ok, %{state | cursor: new_cursor}}
  end

  def handle_event(%Event.Key{key: :home}, state) do
    {:ok, %{state | cursor: 0}}
  end

  def handle_event(%Event.Key{key: :end}, state) do
    {:ok, %{state | cursor: String.length(state.value)}}
  end

  def handle_event(%Event.Key{key: :backspace}, state) do
    if state.cursor > 0 do
      {before, after_cursor} = String.split_at(state.value, state.cursor)
      new_value = String.slice(before, 0..-2//1) <> after_cursor
      new_cursor = state.cursor - 1

      {:ok, %{state | value: new_value, cursor: new_cursor},
       [{:send, self(), {:changed, new_value}}]}
    else
      {:ok, state}
    end
  end

  def handle_event(%Event.Key{key: :delete}, state) do
    if state.cursor < String.length(state.value) do
      {before, after_cursor} = String.split_at(state.value, state.cursor)
      new_value = before <> String.slice(after_cursor, 1..-1//1)

      {:ok, %{state | value: new_value}, [{:send, self(), {:changed, new_value}}]}
    else
      {:ok, state}
    end
  end

  def handle_event(%Event.Key{key: :enter}, state) do
    {:ok, state, [{:send, self(), {:submit, state.value}}]}
  end

  def handle_event(%Event.Key{char: char}, state) when is_binary(char) and char != "" do
    # Insert character at cursor
    {before, after_cursor} = String.split_at(state.value, state.cursor)
    new_value = before <> char <> after_cursor
    new_cursor = state.cursor + String.length(char)

    {:ok, %{state | value: new_value, cursor: new_cursor},
     [{:send, self(), {:changed, new_value}}]}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  @doc """
  Handles messages to the text input.
  """
  @impl true
  def handle_info({:changed, value}, state) do
    props = state.props
    on_change = Map.get(props, :on_change)
    max_length = Map.get(props, :max_length)

    # Enforce max length
    final_value =
      if max_length && String.length(value) > max_length do
        String.slice(value, 0, max_length)
      else
        value
      end

    if is_function(on_change, 1) do
      on_change.(final_value)
    end

    if final_value != value do
      {:ok, %{state | value: final_value, cursor: min(state.cursor, String.length(final_value))}}
    else
      {:ok, state}
    end
  end

  def handle_info({:submit, value}, state) do
    props = state.props
    on_submit = Map.get(props, :on_submit)

    if is_function(on_submit, 1) do
      on_submit.(value)
    end

    {:ok, state}
  end

  def handle_info({:set_value, value}, state) do
    {:ok, %{state | value: value, cursor: String.length(value)}}
  end

  def handle_info(_msg, state) do
    {:ok, state}
  end

  @doc """
  Renders the text input.
  """
  @impl true
  def render(state, area) do
    props = state.props
    placeholder = Map.get(props, :placeholder, "")
    style_opts = Map.get(props, :style, %{})
    cursor_style_opts = Map.get(props, :cursor_style, %{bg: :white, fg: :black})

    style = build_style(style_opts)
    cursor_style = build_style(cursor_style_opts)

    # Determine what to display
    {display_text, show_cursor} =
      if state.value == "" do
        {placeholder, false}
      else
        {state.value, true}
      end

    # Calculate scroll to keep cursor visible
    scroll_offset = calculate_scroll(state.cursor, state.scroll_offset, area.width)

    # Create visible portion
    visible_text =
      display_text
      |> String.slice(scroll_offset, area.width)
      |> String.pad_trailing(area.width)

    # Render cells
    cells =
      visible_text
      |> String.graphemes()
      |> Enum.with_index()
      |> Enum.map(fn {char, x} ->
        cursor_pos = state.cursor - scroll_offset

        cell_style =
          if show_cursor && x == cursor_pos do
            cursor_style
          else
            if state.value == "" do
              # Placeholder style (dimmed)
              Style.new(fg: :bright_black)
            else
              style
            end
          end

        positioned_cell(x, 0, char, cell_style)
      end)

    RenderNode.cells(cells)
  end

  # Private Functions

  defp calculate_scroll(cursor, current_scroll, visible_width) do
    cond do
      # Cursor before visible area
      cursor < current_scroll ->
        cursor

      # Cursor after visible area
      cursor >= current_scroll + visible_width ->
        cursor - visible_width + 1

      # Cursor visible
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
