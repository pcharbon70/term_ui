# TermUI Capabilities Detection Example
#
# This example demonstrates how to query and display
# detected terminal capabilities.
#
# Usage:
#   elixir -r examples/multi_renderer/capabilities.ex -e "CapabilitiesExample.run()"
#
# Or run with specific backend:
#   elixir -r examples/multi_renderer/capabilities.ex -e "CapabilitiesExample.run(backend: :tty)"

defmodule CapabilitiesExample do
  @moduledoc """
  Example showing how to query and display terminal capabilities.

  Demonstrates:
  - Backend mode detection (raw/tty)
  - Color support (true_color, color_256, color_16, monochrome)
  - Unicode support
  - Terminal dimensions
  - The published mouse-capability flag (which does not indicate whether mouse
    reporting is currently enabled)
  """

  use TermUI.Elm

  # State structure
  # %{
  #   capabilities: map() | nil,
  #   current_tab: :overview | :colors | :unicode | :dimensions
  # }

  def init(_opts) do
    # Get capabilities at init
    capabilities = get_capabilities()
    %{capabilities: capabilities, current_tab: :overview}
  end

  # Event handling
  def event_to_msg(%TermUI.Event.Key{key: :tab}, _state), do: {:msg, :next_tab}
  def event_to_msg(%TermUI.Event.Key{key: "1"}, _state), do: {:msg, :show_overview}
  def event_to_msg(%TermUI.Event.Key{key: "2"}, _state), do: {:msg, :show_colors}
  def event_to_msg(%TermUI.Event.Key{key: "3"}, _state), do: {:msg, :show_unicode}
  def event_to_msg(%TermUI.Event.Key{key: "4"}, _state), do: {:msg, :show_dimensions}
  def event_to_msg(%TermUI.Event.Key{key: :enter}, _state), do: {:msg, :refresh}
  def event_to_msg(%TermUI.Event.Key{key: "q"}, _state), do: {:msg, :quit}
  def event_to_msg(_event, _state), do: :ignore

  # State updates
  def update(:next_tab, state) do
    tabs = [:overview, :colors, :unicode, :dimensions]
    current_index = Enum.find_index(tabs, fn t -> t == state.current_tab end)
    next_index = rem(current_index + 1, length(tabs))
    {%{state | current_tab: Enum.at(tabs, next_index)}, []}
  end

  def update(:show_overview, state), do: {%{state | current_tab: :overview}, []}
  def update(:show_colors, state), do: {%{state | current_tab: :colors}, []}
  def update(:show_unicode, state), do: {%{state | current_tab: :unicode}, []}
  def update(:show_dimensions, state), do: {%{state | current_tab: :dimensions}, []}
  def update(:refresh, state), do: {%{state | capabilities: get_capabilities()}, []}
  def update(:quit, state), do: {state, [TermUI.Command.quit()]}

  # View rendering
  def view(state) do
    box([
      header(),
      text(""),
      render_tab_content(state),
      text(""),
      render_tabs(state),
      text(""),
      footer()
    ])
  end

  defp header do
    box([
      text(
        "TermUI Capabilities Detection",
        TermUI.Renderer.Style.new()
        |> TermUI.Renderer.Style.fg(:green)
        |> TermUI.Renderer.Style.bold()
      ),
      text("Displays detected terminal features and backend mode")
    ])
  end

  defp render_tab_content(%{current_tab: :overview, capabilities: caps}) do
    box([
      text("Backend Mode: " <> format_backend_mode(caps)),
      text("Terminal: " <> format_terminal(caps)),
      text("Color Support: " <> format_colors(caps)),
      text("Unicode: " <> format_unicode(caps)),
      text("Dimensions: " <> format_dimensions(caps)),
      text("Mouse capability flag: " <> format_mouse(caps))
    ])
  end

  defp render_tab_content(%{current_tab: :colors, capabilities: caps}) do
    color_mode = get_in(caps, [:colors]) || :unknown

    box([
      text(
        "Color Capabilities",
        TermUI.Renderer.Style.new()
        |> TermUI.Renderer.Style.fg(:green)
      ),
      text(""),
      color_capability_row("Detected Mode", color_mode, get_color_style(color_mode)),
      text(""),
      text("Support Levels:"),
      text("  • true_color  - 24-bit RGB (16.7 million colors)"),
      text("  • color_256  - 256-color palette"),
      text("  • color_16   - 16 basic colors"),
      text("  • monochrome - No color support"),
      text(""),
      color_examples(color_mode)
    ])
  end

  defp render_tab_content(%{current_tab: :unicode, capabilities: caps}) do
    unicode_supported = get_in(caps, [:unicode]) == true

    box([
      text(
        "Unicode Support",
        TermUI.Renderer.Style.new()
        |> TermUI.Renderer.Style.fg(:green)
      ),
      text(""),
      text("Detected: " <> if(unicode_supported, do: "Yes ✓", else: "No ✗")),
      text(""),
      if(unicode_supported,
        do: text("  Box drawing: ┌─┐│└┘"),
        else: text("  ASCII fallback: +-||")
      ),
      text(""),
      text("Note: TermUI automatically falls back to"),
      text("      ASCII when Unicode is not available.")
    ])
  end

  defp render_tab_content(%{current_tab: :dimensions, capabilities: caps}) do
    {rows, cols} = get_in(caps, [:dimensions]) || {nil, nil}

    box([
      text(
        "Terminal Dimensions",
        TermUI.Renderer.Style.new()
        |> TermUI.Renderer.Style.fg(:green)
      ),
      text(""),
      text("Rows: " <> format_value(rows)),
      text("Columns: " <> format_value(cols)),
      text(""),
      text("Total Cells: " <> format_total(rows, cols)),
      text(""),
      if(rows && cols,
        do: text("Terminal size: #{rows}×#{cols}"),
        else: text("Dimensions not available")
      )
    ])
  end

  defp render_tabs(state) do
    tabs = [
      {"1", :overview, "Overview"},
      {"2", :colors, "Colors"},
      {"3", :unicode, "Unicode"},
      {"4", :dimensions, "Dimensions"}
    ]

    tab_text =
      tabs
      |> Enum.map(fn {key, tab, label} ->
        style =
          if state.current_tab == tab do
            TermUI.Renderer.Style.new()
            |> TermUI.Renderer.Style.fg(:yellow)
            |> TermUI.Renderer.Style.bold()
            |> TermUI.Renderer.Style.underline()
          else
            TermUI.Renderer.Style.new()
            |> TermUI.Renderer.Style.fg(:bright_black)
          end

        text("[#{key}:#{label}] ", style)
      end)

    stack(:horizontal, tab_text)
  end

  defp footer do
    text(
      "Tab=switch | 1-4=jump | Enter=refresh | q=quit",
      TermUI.Renderer.Style.new()
      |> TermUI.Renderer.Style.fg(:bright_black)
    )
  end

  # Color formatting helpers
  defp get_color_style(:true_color),
    do: TermUI.Renderer.Style.new() |> TermUI.Renderer.Style.fg(:bright_green)

  defp get_color_style(:color_256),
    do: TermUI.Renderer.Style.new() |> TermUI.Renderer.Style.fg(:green)

  defp get_color_style(:color_16),
    do: TermUI.Renderer.Style.new() |> TermUI.Renderer.Style.fg(:yellow)

  defp get_color_style(:monochrome),
    do: TermUI.Renderer.Style.new() |> TermUI.Renderer.Style.fg(:white)

  defp get_color_style(_), do: TermUI.Renderer.Style.new()

  defp color_capability_row(label, value, style) do
    stack(:horizontal, [
      text(label <> ": "),
      text(inspect(value), style)
    ])
  end

  defp color_examples(:true_color) do
    box([
      text("True Color Gradient Example:"),
      text(""),
      rainbow_gradient("True Color (24-bit RGB)"),
      text(""),
      text("Your terminal supports over 16 million colors!")
    ])
  end

  defp color_examples(:color_256) do
    box([
      text("256-Color Palette Example:"),
      text(""),
      sample_palette_256(),
      text(""),
      text("Your terminal supports 256 colors.")
    ])
  end

  defp color_examples(:color_16) do
    box([
      text("16-Color Example:"),
      text(""),
      sample_colors_16(),
      text(""),
      text("Your terminal supports 16 basic colors.")
    ])
  end

  defp color_examples(:monochrome) do
    box([
      text("Monochrome Display"),
      text(""),
      text("Your terminal does not support color."),
      text("All output will be in a single color.")
    ])
  end

  defp color_examples(_), do: text("Color detection not available")

  # Sample color displays
  defp rainbow_gradient(label) do
    colors = [:red, :yellow, :green, :cyan, :blue, :magenta]

    nodes =
      Enum.map(colors, fn color ->
        text("■ ", TermUI.Renderer.Style.new() |> TermUI.Renderer.Style.fg(color))
      end)

    stack(:horizontal, [text(label <> ": ") | nodes])
  end

  defp sample_palette_256 do
    # Sample of the 256-color palette
    indices = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]

    nodes =
      Enum.map(indices, fn i ->
        style = TermUI.Renderer.Style.new() |> TermUI.Renderer.Style.bg(i)
        text("  ", style)
      end)

    stack(:horizontal, nodes)
  end

  defp sample_colors_16 do
    colors = [
      {:black, "K "},
      {:red, "R "},
      {:green, "G "},
      {:yellow, "Y "},
      {:blue, "B "},
      {:magenta, "M "},
      {:cyan, "C "},
      {:white, "W "}
    ]

    nodes =
      Enum.map(colors, fn {color, label} ->
        text(label, TermUI.Renderer.Style.new() |> TermUI.Renderer.Style.bg(color))
      end)

    stack(:horizontal, nodes)
  end

  # Formatting helpers
  defp format_backend_mode(%{backend_mode: mode}) when mode, do: inspect(mode)
  defp format_backend_mode(_), do: "unknown"

  defp format_terminal(%{terminal: true}), do: "Yes (terminal detected)"
  defp format_terminal(%{terminal: false}), do: "No (piped/file)"
  defp format_terminal(_), do: "unknown"

  defp format_colors(%{colors: mode}) when mode, do: inspect(mode)
  defp format_colors(_), do: "unknown"

  defp format_unicode(%{unicode: true}), do: "Yes ✓"
  defp format_unicode(%{unicode: false}), do: "No (ASCII fallback)"
  defp format_unicode(_), do: "unknown"

  defp format_dimensions(%{dimensions: {rows, cols}}) when rows and cols do
    "#{rows} rows × #{cols} cols"
  end

  defp format_dimensions(_), do: "unknown"

  defp format_mouse(%{mouse: true}), do: "true"
  defp format_mouse(%{mouse: false}), do: "false"
  defp format_mouse(_), do: "unknown"

  defp format_value(nil), do: "N/A"
  defp format_value(value), do: to_string(value)

  defp format_total(nil, _), do: "N/A"
  defp format_total(_, nil), do: "N/A"
  defp format_total(rows, cols), do: to_string(rows * cols)

  # Get capabilities from the running system
  defp get_capabilities do
    %{
      backend_mode: TermUI.App.backend_mode(),
      colors: get_color_mode(),
      unicode: TermUI.App.supports?(:unicode),
      dimensions: get_dimensions(),
      terminal: get_terminal(),
      mouse: TermUI.App.supports?(:mouse)
    }
  end

  defp get_color_mode do
    cond do
      TermUI.App.supports?(:true_color) -> :true_color
      TermUI.App.supports?(:color_256) -> :color_256
      TermUI.App.supports?(:color_16) -> :color_16
      TermUI.App.supports?(:monochrome) -> :monochrome
      true -> nil
    end
  end

  defp get_dimensions do
    case TermUI.PersistentTerms.capabilities() do
      %{dimensions: dims} -> dims
      _ -> nil
    end
  end

  defp get_terminal do
    case TermUI.PersistentTerms.capabilities() do
      %{terminal: term} when is_boolean(term) -> term
      _ -> nil
    end
  end

  # Run the application
  def run(opts \\ []) do
    all_opts = Keyword.put_new(opts, :name, :capabilities_example)

    # Check if we should show a demo or run the full app
    if Keyword.get(opts, :demo, false) do
      run_demo()
    else
      try do
        TermUI.App.run(__MODULE__, all_opts)
      rescue
        e ->
          IO.puts("Could not start full UI: #{inspect(e)}")
          IO.puts("\nRunning in demo mode instead...\n")
          run_demo()
      end
    end
  end

  # Demo mode that shows capabilities without full UI
  defp run_demo do
    caps = get_capabilities()

    IO.puts("""
    TermUI Capabilities Detection Demo
    =================================

    Backend Mode: #{format_backend_mode(caps)}
    Terminal: #{format_terminal(caps)}
    Color Support: #{format_colors(caps)}
    Unicode: #{format_unicode(caps)}
    Dimensions: #{format_dimensions(caps)}
    Mouse capability flag: #{format_mouse(caps)}

    This demo shows the capabilities that would be detected
    when running a full TermUI application.

    To run the full interactive example, use OTP 28+ and ensure
    you're in a terminal that supports raw mode.
    """)
  end
end
