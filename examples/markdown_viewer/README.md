# Markdown Viewer Example

Demonstration of the `TermUI.Widgets.MarkdownViewer` widget.

## Running the Example

### Raw Mode (Full TUI Experience)

For the best experience with full terminal control and alternate screen:

```bash
cd examples/markdown_viewer
mix termui.run
```

Or manually:

```bash
cd examples/markdown_viewer
mix run -e "MarkdownViewer.App.run()" --no-halt
```

### TTY Mode (IEx Compatible)

To run from IEx without taking over the shell:

```bash
cd examples/markdown_viewer
iex -S mix
```

Then in IEx:

```elixir
MarkdownViewer.App.run()
```

**Note:** TTY mode works inside IEx but has limitations:
- No alternate screen buffer (output mixes with IEx prompt)
- Input is read through the shell; some terminals buffer keys until Enter is pressed
- For full TUI, use raw mode instead

## Controls

| Key | Action |
|-----|--------|
| `↑` / `↓` | Scroll up/down |
| `Page Up` / `Page Down` | Scroll by page |
| `Home` / `End` | Jump to top/bottom |
| `Tab` | Cycle focus through code blocks |
| `Enter` / `c` | Copy focused code block |
| `Q` | Quit |
