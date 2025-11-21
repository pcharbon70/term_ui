defmodule TermUI.Widget.Label do
  @moduledoc """
  A stateless widget for displaying text.

  Label is the simplest widget - it renders text with optional styling,
  alignment, wrapping, and truncation.

  ## Usage

      Label.render(%{text: "Hello, World!"}, area)

      Label.render(%{
        text: "Centered text",
        align: :center,
        style: %{fg: :blue, bold: true}
      }, area)

  ## Props

  - `:text` - The text to display (required)
  - `:align` - Text alignment: `:left`, `:center`, `:right` (default: `:left`)
  - `:wrap` - Whether to wrap text (default: `false`)
  - `:truncate` - Whether to truncate with ellipsis (default: `true`)
  - `:style` - Style options (fg, bg, bold, etc.)
  """

  use TermUI.Component

  alias TermUI.Renderer.Style
  alias TermUI.Component.RenderNode

  @doc """
  Renders the label text within the given area.
  """
  @impl true
  def render(props, area) do
    text = Map.get(props, :text, "")
    align = Map.get(props, :align, :left)
    wrap = Map.get(props, :wrap, false)
    truncate = Map.get(props, :truncate, true)
    style_opts = Map.get(props, :style, %{})

    style = build_style(style_opts)

    lines =
      if wrap do
        wrap_text(text, area.width)
      else
        [text]
      end

    cells =
      lines
      |> Enum.with_index()
      |> Enum.flat_map(fn {line, y} ->
        if y < area.height do
          render_line(line, y, area.width, align, truncate, style)
        else
          []
        end
      end)

    RenderNode.cells(cells)
  end

  @doc """
  Returns a description of this component.
  """
  @impl true
  def describe do
    "Label widget for displaying text"
  end

  # Private Functions

  defp build_style(opts) when is_map(opts) do
    style_list =
      opts
      |> Enum.map(fn
        {:fg, color} -> {:fg, color}
        {:bg, color} -> {:bg, color}
        {:bold, true} -> {:attrs, [:bold]}
        {:italic, true} -> {:attrs, [:italic]}
        {:underline, true} -> {:attrs, [:underline]}
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)

    Style.new(style_list)
  end

  defp build_style(_), do: Style.new()

  defp render_line(text, y, width, align, truncate, style) do
    # Process the text for display
    display_text =
      if truncate && String.length(text) > width do
        do_truncate(text, width)
      else
        text
      end

    # Align the text
    aligned = align_text(display_text, width, align)

    # Create cells for each character
    aligned
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.map(fn {char, x} ->
      positioned_cell(x, y, char, style)
    end)
  end

  defp do_truncate(text, width) when width <= 3 do
    String.slice(text, 0, width)
  end

  defp do_truncate(text, width) do
    if String.length(text) > width do
      String.slice(text, 0, width - 1) <> "…"
    else
      text
    end
  end

  defp align_text(text, width, :left) do
    String.pad_trailing(text, width)
  end

  defp align_text(text, width, :right) do
    String.pad_leading(text, width)
  end

  defp align_text(text, width, :center) do
    len = String.length(text)

    if len >= width do
      text
    else
      padding = div(width - len, 2)
      text |> String.pad_leading(len + padding) |> String.pad_trailing(width)
    end
  end

  defp wrap_text(text, width) when width <= 0, do: [text]

  defp wrap_text(text, width) do
    text
    |> String.graphemes()
    |> Enum.chunk_every(width)
    |> Enum.map(&Enum.join/1)
  end
end
