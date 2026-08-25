defmodule Showcase.Pages.Content do
  @moduledoc false

  @behaviour Showcase.Page

  alias Showcase.Layout
  alias TermUI.Event
  alias TermUI.Frame
  alias TermUI.Widget.{DiffViewer, MarkdownViewer, Stream}

  @views [:markdown, :diff, :stream]

  @impl true
  def init do
    %{
      active: :markdown,
      tick: 0,
      markdown: MarkdownViewer.init(content: markdown(), page_size: 18),
      diff:
        DiffViewer.init(
          before: "def hello(name) do\n  \"hello \#{name}\"\nend\n",
          after: "def hello(name \\ \"world\") do\n  \"Hello, \#{name}!\"\nend\n",
          old_label: "before.ex",
          new_label: "after.ex",
          page_size: 18
        ),
      stream:
        Stream.init(
          items: ["0001 runtime started", "0002 backend ready", "0003 first frame drawn"],
          limit: 40,
          page_size: 18
        )
    }
  end

  @impl true
  def update(%Event.Text{text: "]"}, state), do: {move_view(state, 1), []}
  def update(%Event.Text{text: "["}, state), do: {move_view(state, -1), []}

  def update(:tick, state) do
    tick = state.tick + 1
    stream = Stream.push(state.stream, "#{pad(tick + 3)} processed frame #{tick}")
    {%{state | tick: tick, stream: stream}, []}
  end

  def update(event, %{active: :markdown} = state) do
    {widget, messages} = MarkdownViewer.update(event, state.markdown)
    {%{state | markdown: widget}, messages}
  end

  def update(event, %{active: :diff} = state) do
    {widget, messages} = DiffViewer.update(event, state.diff)
    {%{state | diff: widget}, messages}
  end

  def update(event, %{active: :stream} = state) do
    {widget, messages} = Stream.update(event, state.stream)
    {%{state | stream: widget}, messages}
  end

  @impl true
  def view(state, {width, height}, theme) do
    selector =
      Layout.selector([markdown: "Markdown", diff: "Diff", stream: "Stream"], state.active, width)

    panel_height = max(height - 1, 1)
    inner = {max(width - 2, 1), max(panel_height - 2, 1)}

    {title, content} =
      case state.active do
        :markdown -> {"Markdown viewer", MarkdownViewer.view(state.markdown, inner)}
        :diff -> {"Diff viewer - press S to change mode", DiffViewer.view(state.diff, inner)}
        :stream -> {"Bounded stream - Space pauses", Stream.view(state.stream, inner)}
      end

    panel = Layout.panel(content, title, {width, panel_height}, active: true, theme: theme)

    Frame.new(width, height)
    |> Frame.overlay(selector, 1, 1)
    |> Frame.overlay(panel, 1, 2)
  end

  @impl true
  def help, do: "[ and ] change the content widget. Arrows scroll. Tab focuses Markdown code."

  defp move_view(state, delta) do
    index = Enum.find_index(@views, &(&1 == state.active)) || 0
    next = rem(index + delta + length(@views), length(@views))
    %{state | active: Enum.at(@views, next)}
  end

  defp pad(value), do: value |> Integer.to_string() |> String.pad_leading(4, "0")

  defp markdown do
    """
    # Rich terminal content

    TermUI uses **MDEx** and renders Markdown as styled terminal cells.

    - [x] CommonMark content
    - [x] Tables and task lists
    - [x] Selectable code blocks

    | Boundary | Owner |
    | --- | --- |
    | State | Application runtime |
    | Terminal | Backend manager |
    | Cells | Frame |

    ```elixir
    {widget, messages} = Widget.update(event, widget)
    frame = Widget.view(widget, dimensions)
    ```

    Press Tab to focus code blocks and Enter to copy one.
    """
  end
end
