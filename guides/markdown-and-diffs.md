# Markdown and diff viewers

## Markdown

`TermUI.Markdown` parses Markdown with MDEx. It returns styled frame rows.

```elixir
rows = TermUI.Markdown.render(markdown, 80)
frame = TermUI.Frame.from_rows(rows, 80, 24)
```

Use `TermUI.Widget.MarkdownViewer` for scrolling and code-block selection. A
copy action returns `{:copy, code}` to the parent. The widget does not access
the system clipboard.

```elixir
viewer = TermUI.Widget.MarkdownViewer.init(content: markdown)
{viewer, messages} = TermUI.Widget.MarkdownViewer.update(event, viewer)
frame = TermUI.Widget.MarkdownViewer.view(viewer, {80, 24})
```

The viewer supports headings, emphasis, strong and strike-through text, inline
code, links, images, quotes, ordered and unordered lists, task lists, code
blocks, rules, and tables. Raw HTML is reduced to terminal-safe text.

## Diffs

Create a diff from two texts:

```elixir
viewer =
  TermUI.Widget.DiffViewer.init(
    before: old_text,
    after: new_text,
    old_label: "a/file.ex",
    new_label: "b/file.ex"
  )
```

Or supply an existing unified diff with `:unified_diff`. Press `s` to switch
between unified and side-by-side views. The viewer uses line-based Myers
comparison and bounds input to 5,000 lines by default.
