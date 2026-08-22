defmodule TermUI.Widget.MarkdownViewerTest do
  use ExUnit.Case, async: true

  alias TermUI.{Event, Frame, Markdown}
  alias TermUI.Widget.MarkdownViewer

  @markdown """
  # Heading

  **bold** and *italic* with `code` and [link](https://example.com).

  > quoted

  - [x] done
  - [ ] next

  ```elixir
  IO.puts(:ok)
  ```

  | Name | Value |
  | --- | ---: |
  | one | 1 |
  """

  test "MDEx renders the supported block and inline forms as styled rows" do
    result = Markdown.render_with_elements(@markdown, 50)
    frame = Frame.from_rows(result.lines, 50, result.content_height)
    text = Enum.map_join(1..frame.height, "\n", &Frame.row_text(frame, &1))

    assert text =~ "Heading"
    assert text =~ "bold and italic with code and link"
    assert text =~ "│ quoted"
    assert text =~ "[x] done"
    assert text =~ "IO.puts(:ok)"
    assert text =~ "│Name"
    assert [%{type: :code_block, language: "elixir", content: content}] = result.elements
    assert content =~ "IO.puts"

    heading = Frame.cell(frame, 1, 1)
    assert :bold in heading.attrs
    assert heading.fg == :cyan
  end

  test "viewer scrolls, selects code, and emits copy data without side effects" do
    state = MarkdownViewer.init(content: @markdown, page_size: 3)
    assert %Frame{} = MarkdownViewer.view(state, {30, 5})

    assert {state, [{:focused, element}]} = MarkdownViewer.update(Event.key(:tab), state)
    assert element.type == :code_block
    assert {_state, [{:copy, content}]} = MarkdownViewer.update(Event.key(:enter), state)
    assert content =~ "IO.puts"
  end

  test "raw HTML and control strings do not reach terminal cells" do
    rows = Markdown.render("<script>bad</script>\n\n\e]52;c;payload\a", 30)
    frame = Frame.from_rows(rows, 30, length(rows))
    rendered = Enum.map_join(1..frame.height, &Frame.row_text(frame, &1))

    refute rendered =~ "<script>"
    refute rendered =~ "\e"
    refute rendered =~ "\a"
  end

  test "bounded append keeps valid UTF-8 and follows the document end" do
    state = MarkdownViewer.init(content: "éé", content_limit: 5, page_size: 2)
    state = MarkdownViewer.append(state, "abc")

    assert state.content == "éabc"
    assert state.scroll == :end
    assert String.valid?(state.content)
    assert %Frame{} = MarkdownViewer.view(state, {8, 2})

    state = MarkdownViewer.set_content(state, "0123456789")
    assert state.content == "56789"
    assert state.scroll == 0
  end

  test "all navigation paths remain bounded with and without code blocks" do
    state =
      MarkdownViewer.init(content: Enum.map_join(1..20, "\n\n", &"line #{&1}"), page_size: 3)

    assert {^state, []} = MarkdownViewer.update(Event.key(:tab), state)
    assert {^state, []} = MarkdownViewer.update(Event.key(:enter), state)
    assert {^state, []} = MarkdownViewer.update(Event.text("c"), state)
    assert {state, [{:scrolled, 1}]} = MarkdownViewer.update(Event.key(:down), state)
    assert {state, [{:scrolled, 4}]} = MarkdownViewer.update(Event.key(:page_down), state)
    assert {state, [{:scrolled, 1}]} = MarkdownViewer.update(Event.key(:page_up), state)
    assert {state, [{:scrolled, 0}]} = MarkdownViewer.update(Event.key(:up), state)
    assert {state, []} = MarkdownViewer.update(Event.key(:end), state)
    assert state.scroll == :end

    assert {state, [{:scrolled, 3}]} =
             MarkdownViewer.update(Event.mouse(:scroll_down, nil, 0, 0), state)

    assert {state, [{:scrolled, 0}]} =
             MarkdownViewer.update(Event.mouse(:scroll_up, nil, 0, 0), state)

    assert {state, []} = MarkdownViewer.update(Event.key(:home), state)
    assert state.scroll == 0
  end

  test "shift-tab wraps code focus and selected rendering marks the block" do
    markdown = "```elixir\none\n```\n\n```erlang\ntwo\n```"
    state = MarkdownViewer.init(content: markdown)

    assert {state, [{:focused, element}]} =
             MarkdownViewer.update(Event.key(:tab, modifiers: [:shift]), state)

    assert element.language == "erlang"
    assert state.focused == 1
    assert {_state, [{:copy, "two\n"}]} = MarkdownViewer.update(Event.text("c"), state)

    rendered = state |> MarkdownViewer.view({30, 8}) |> Frame.row_text(5)
    assert rendered =~ "selected"
  end
end
