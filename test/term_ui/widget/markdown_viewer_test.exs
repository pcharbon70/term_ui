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
end
