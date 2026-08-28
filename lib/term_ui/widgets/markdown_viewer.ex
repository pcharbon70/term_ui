defmodule TermUI.Widgets.MarkdownViewer do
  @moduledoc """
  A scrollable markdown viewer component for TermUI.

  Renders markdown content with syntax highlighting, scrolling support,
  and interactive code blocks that can be focused and copied.

  ## Usage

      MarkdownViewer.new(content: "# Hello\\n\\nThis is **bold** text.")

  ## Keyboard Navigation

  - `↑` / `↓` - Scroll up/down by line
  - `Page Up` / `Page Down` - Scroll by page
  - `Home` / `End` - Jump to top/bottom
  - `Tab` - Cycle focus through code blocks
  - `Enter` / `c` - Copy focused code block

  ## Props

  - `:content` - Markdown content to display (default: `""`)
  - `:width` - Display width (default: 80)
  - `:height` - Display height (default: 24)
  - `:on_copy` - Callback called when code block is copied (optional)

  """

  use TermUI.StatefulComponent

  alias TermUI.Component.RenderNode
  alias TermUI.Event
  alias TermUI.Markdown

  # Dialyzer: Functions return specific map types
  @dialyzer {:nowarn_function, new: 1}

  @doc """
  Creates new MarkdownViewer props.
  """
  @spec new(keyword()) :: map()
  def new(opts) do
    %{
      content: Keyword.get(opts, :content, ""),
      width: Keyword.get(opts, :width, 80),
      height: Keyword.get(opts, :height, 24),
      on_copy: Keyword.get(opts, :on_copy)
    }
  end

  @impl true
  def init(props) do
    state = %{
      content: props.content,
      width: props.width,
      height: props.height,
      scroll_y: 0,
      on_copy: props.on_copy,
      render_cache: nil,
      content_height: 0,
      elements: [],
      focused_element_index: 0,
      focused_element_id: nil
    }

    {:ok, refresh_render_cache(state)}
  end

  @impl true
  def update(new_props, state) do
    state =
      state
      |> maybe_update_content(new_props)
      |> maybe_update_size(new_props)

    {:ok, state}
  end

  @impl true
  def handle_event(%Event.Key{key: :up}, state) do
    scroll_by(state, -1)
  end

  def handle_event(%Event.Key{key: :down}, state) do
    scroll_by(state, 1)
  end

  def handle_event(%Event.Key{key: :page_up}, state) do
    scroll_by(state, -state.height)
  end

  def handle_event(%Event.Key{key: :page_down}, state) do
    scroll_by(state, state.height)
  end

  def handle_event(%Event.Key{key: :home}, state) do
    scroll_to_line(state, 0)
  end

  def handle_event(%Event.Key{key: :end}, state) do
    max_scroll = max(0, state.content_height - state.height)
    scroll_to_line(state, max_scroll)
  end

  def handle_event(%Event.Key{key: :tab, modifiers: []}, state) do
    focus_next_code_block(state)
  end

  def handle_event(%Event.Key{key: :tab, modifiers: [:shift]}, state) do
    focus_prev_code_block(state)
  end

  def handle_event(%Event.Key{key: :enter}, state) do
    copy_focused_code_block(state)
  end

  def handle_event(%Event.Key{char: "c"}, state) do
    copy_focused_code_block(state)
  end

  def handle_event(%Event.Mouse{action: :scroll_up}, state) do
    scroll_by(state, -3)
  end

  def handle_event(%Event.Mouse{action: :scroll_down}, state) do
    scroll_by(state, 3)
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  @impl true
  def render(state, _area) do
    %{lines: lines} =
      state.render_cache || %{lines: [[{"", nil}]], elements: [], content_height: 1}

    start_line = state.scroll_y

    visible_lines =
      lines
      |> Enum.slice(start_line, state.height)
      |> Enum.map(&render_line_to_node/1)

    if visible_lines == [] do
      RenderNode.text("")
    else
      RenderNode.stack(:vertical, visible_lines)
    end
  end

  # Public API

  @doc """
  Sets the markdown content.
  """
  @spec set_content(pid(), String.t()) :: :ok
  def set_content(pid, content) when is_pid(pid) do
    GenServer.call(pid, {:set_content, content})
  end

  def set_content(_pid, _content), do: :ok

  # GenServer callbacks

  @impl true
  def handle_call({:set_content, content}, _from, state) do
    state = refresh_render_cache(%{state | content: content, scroll_y: 0})
    {:reply, :ok, state}
  end

  def handle_call(_request, _from, state) do
    {:reply, :ok, state}
  end

  # Private helpers

  defp maybe_update_content(state, %{content: content}) when is_binary(content) do
    if content != state.content do
      refresh_render_cache(%{state | content: content})
    else
      state
    end
  end

  defp maybe_update_content(state, _new_props), do: state

  defp maybe_update_size(state, new_props) do
    width = Map.get(new_props, :width, state.width)
    height = Map.get(new_props, :height, state.height)

    if width != state.width or height != state.height do
      state = %{state | width: width, height: height}

      if width != state.width do
        refresh_render_cache(state)
      else
        state
      end
    else
      state
    end
  end

  defp refresh_render_cache(state) do
    %{lines: lines, elements: elements, content_height: height} =
      Markdown.render_with_elements(state.content, state.width,
        focused_element_id: state.focused_element_id
      )

    max_scroll = max(0, height - state.height)
    scroll_y = min(state.scroll_y, max_scroll)

    %{
      state
      | render_cache: %{lines: lines, elements: elements, content_height: height},
        content_height: height,
        elements: elements,
        scroll_y: scroll_y
    }
  end

  defp scroll_by(state, delta) do
    new_y = clamp_scroll(state.scroll_y + delta, state.content_height, state.height)
    {:ok, %{state | scroll_y: new_y}}
  end

  defp scroll_to_line(state, y) do
    new_y = clamp_scroll(y, state.content_height, state.height)
    {:ok, %{state | scroll_y: new_y}}
  end

  defp clamp_scroll(scroll, content_height, viewport_height) do
    max_scroll = max(0, content_height - viewport_height)
    min(max(0, scroll), max_scroll)
  end

  defp focus_next_code_block(state) do
    elements = state.elements

    if elements == [] do
      {:ok, state}
    else
      new_index = rem(state.focused_element_index + 1, length(elements))
      focus_element_at_index(state, new_index)
    end
  end

  defp focus_prev_code_block(state) do
    elements = state.elements

    if elements == [] do
      {:ok, state}
    else
      count = length(elements)
      new_index = rem(state.focused_element_index - 1 + count, count)
      focus_element_at_index(state, new_index)
    end
  end

  defp focus_element_at_index(state, index) do
    element = Enum.at(state.elements, index)

    if element do
      state = %{state | focused_element_index: index}
      element_id = element.id

      state =
        if state.focused_element_id != element_id do
          new_cache =
            Markdown.render_with_elements(state.content, state.width,
              focused_element_id: element_id
            )

          %{state | focused_element_id: element_id, render_cache: new_cache}
        else
          state
        end

      target_line = element.start_line
      scroll_to_line(state, target_line)
    else
      {:ok, state}
    end
  end

  defp copy_focused_code_block(state) do
    if state.elements == [] do
      {:ok, state}
    else
      element = Enum.at(state.elements, state.focused_element_index)

      if element do
        if state.on_copy do
          state.on_copy.(element.content)
        end

        {:ok, state}
      else
        {:ok, state}
      end
    end
  end

  defp render_line_to_node([]), do: RenderNode.text("", nil)

  defp render_line_to_node([{text, style}]) do
    RenderNode.text(text, style)
  end

  defp render_line_to_node(segments) when is_list(segments) do
    nodes =
      Enum.map(segments, fn {text, style} ->
        RenderNode.text(text, style)
      end)

    RenderNode.stack(:horizontal, nodes)
  end
end
