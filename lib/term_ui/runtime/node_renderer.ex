defmodule TermUI.Runtime.NodeRenderer do
  @moduledoc """
  Converts render trees to buffer cells for terminal output.

  This module bridges the gap between the component's render tree output
  and the low-level buffer cell representation needed for terminal rendering.

  Supports both tuple-based render nodes (from TermUI.Elm.Helpers) and
  struct-based RenderNodes (from TermUI.Component.RenderNode).
  """

  alias TermUI.Component.RenderNode
  alias TermUI.Renderer.Buffer
  alias TermUI.Renderer.BufferManager
  alias TermUI.Renderer.Cell
  alias TermUI.Renderer.Style

  @doc """
  Renders a node tree to the buffer starting at the given position.

  Returns the bounds of the rendered content as {width, height}.
  """
  @spec render_to_buffer(term(), BufferManager.t() | pid(), pos_integer(), pos_integer()) ::
          {non_neg_integer(), non_neg_integer()}
  def render_to_buffer(node, buffer_manager, start_row \\ 1, start_col \\ 1) do
    buffer = BufferManager.get_current_buffer(buffer_manager)
    render_node(node, buffer, start_row, start_col, nil)
  end

  # Handle RenderNode structs
  defp render_node(%RenderNode{type: :empty}, _buffer, _row, _col, _style), do: {0, 0}

  defp render_node(
         %RenderNode{type: :text, content: content, style: style},
         buffer,
         row,
         col,
         parent_style
       ) do
    effective_style = merge_styles(parent_style, style)
    render_text(content, buffer, row, col, effective_style)
  end

  defp render_node(
         %RenderNode{type: :box, children: children, style: style, width: width, height: height},
         buffer,
         row,
         col,
         parent_style
       ) do
    effective_style = merge_styles(parent_style, style)
    {rendered_width, rendered_height} = render_children_vertical(children, buffer, row, col, effective_style)

    # Return specified dimensions if provided, otherwise use rendered dimensions
    final_width = width || rendered_width
    final_height = height || rendered_height
    {final_width, final_height}
  end

  defp render_node(
         %RenderNode{type: :stack, direction: :vertical, children: children, style: style},
         buffer,
         row,
         col,
         parent_style
       ) do
    effective_style = merge_styles(parent_style, style)
    render_children_vertical(children, buffer, row, col, effective_style)
  end

  defp render_node(
         %RenderNode{type: :stack, direction: :horizontal, children: children, style: style},
         buffer,
         row,
         col,
         parent_style
       ) do
    effective_style = merge_styles(parent_style, style)
    render_children_horizontal(children, buffer, row, col, effective_style)
  end

  defp render_node(%RenderNode{type: :cells, cells: cells}, buffer, row, col, parent_style) do
    render_positioned_cells(cells, buffer, row, col, parent_style)
  end

  # Handle viewport nodes (from Viewport widget)
  # Viewport clips content to a region and applies scroll offsets
  defp render_node(
         %{
           type: :viewport,
           content: content,
           scroll_x: scroll_x,
           scroll_y: scroll_y,
           width: width,
           height: height
         },
         buffer,
         row,
         col,
         style
       ) do
    render_viewport(content, buffer, row, col, style, scroll_x, scroll_y, width, height)
  end

  # Handle overlay nodes (from AlertDialog, Dialog, ContextMenu, Toast widgets)
  # Overlay renders content at an absolute position on screen
  # Optional: width, height, bg for opaque background fill
  defp render_node(
         %{
           type: :overlay,
           content: content,
           x: x,
           y: y
         } = overlay,
         buffer,
         _row,
         _col,
         style
       ) do
    # Overlay uses absolute positioning - x and y are 0-indexed screen coordinates
    # Convert to 1-indexed buffer coordinates
    buf_row = y + 1
    buf_col = x + 1

    # If width, height, and bg are provided, fill background first
    case overlay do
      %{width: width, height: height, bg: bg} when is_integer(width) and is_integer(height) ->
        fill_background(buffer, buf_row, buf_col, width, height, bg)

      _ ->
        :ok
    end

    render_node(content, buffer, buf_row, buf_col, style)
  end

  # Handle tuple-based render nodes from Elm.Helpers
  defp render_node({:text, content}, buffer, row, col, style) do
    render_text(content, buffer, row, col, style)
  end

  defp render_node({:styled, content, style}, buffer, row, col, parent_style) do
    effective_style = merge_styles(parent_style, style)
    render_node(content, buffer, row, col, effective_style)
  end

  defp render_node({:box, _opts, children}, buffer, row, col, style) do
    render_node(children, buffer, row, col, style)
  end

  defp render_node({:row, _opts, children}, buffer, row, col, style) do
    render_children_horizontal(children, buffer, row, col, style)
  end

  defp render_node({:column, _opts, children}, buffer, row, col, style) do
    render_children_vertical(children, buffer, row, col, style)
  end

  defp render_node({:fragment, children}, buffer, row, col, style) do
    render_children_vertical(children, buffer, row, col, style)
  end

  # Handle lists of children (from stack(:vertical, [...]))
  defp render_node(children, buffer, row, col, style) when is_list(children) do
    render_children_vertical(children, buffer, row, col, style)
  end

  # Fallback for unknown node types
  defp render_node(_node, _buffer, _row, _col, _style), do: {0, 0}

  # Text rendering
  defp render_text(nil, _buffer, _row, _col, _style), do: {0, 0}
  # Empty string should still take up one line (for blank lines)
  defp render_text("", _buffer, _row, _col, _style), do: {0, 1}

  defp render_text(text, buffer, row, col, style) when is_binary(text) do
    lines = String.split(text, "\n")
    max_width = 0
    height = length(lines)

    {max_width, _final_row} =
      Enum.reduce(lines, {max_width, row}, fn line, {max_w, current_row} ->
        width = render_line(line, buffer, current_row, col, style)
        {max(max_w, width), current_row + 1}
      end)

    {max_width, height}
  end

  defp render_text(content, buffer, row, col, style) do
    render_text(to_string(content), buffer, row, col, style)
  end

  defp render_line(line, buffer, row, col, style) do
    graphemes = String.graphemes(line)
    width = length(graphemes)

    graphemes
    |> Enum.with_index()
    |> Enum.each(fn {char, idx} ->
      cell = create_cell(char, style)
      Buffer.set_cell(buffer, row, col + idx, cell)
    end)

    width
  end

  # Children rendering
  defp render_children_vertical(children, buffer, row, col, style) when is_list(children) do
    {max_width, final_row} =
      Enum.reduce(children, {0, row}, fn child, {max_w, current_row} ->
        {width, height} = render_node(child, buffer, current_row, col, style)
        {max(max_w, width), current_row + height}
      end)

    {max_width, final_row - row}
  end

  defp render_children_horizontal(children, buffer, row, col, style) when is_list(children) do
    {max_height, final_col} =
      Enum.reduce(children, {0, col}, fn child, {max_h, current_col} ->
        {width, height} = render_node(child, buffer, row, current_col, style)
        {max(max_h, height), current_col + width}
      end)

    {final_col - col, max_height}
  end

  # Positioned cells rendering (for widgets like Gauge that pre-render cells)
  defp render_positioned_cells(cells, buffer, offset_row, offset_col, parent_style) do
    max_x = 0
    max_y = 0

    {max_x, max_y} =
      Enum.reduce(cells, {max_x, max_y}, fn %{x: x, y: y, cell: cell}, {mx, my} ->
        # Apply parent style if cell doesn't have its own
        cell = apply_parent_style_to_cell(cell, parent_style)
        Buffer.set_cell(buffer, offset_row + y, offset_col + x, cell)
        {max(mx, x + 1), max(my, y + 1)}
      end)

    {max_x, max_y}
  end

  # Viewport rendering - clips content to a region with scroll offsets
  # Creates a temporary buffer to render content, then copies visible portion
  defp render_viewport(
         content,
         buffer,
         dest_row,
         dest_col,
         style,
         scroll_x,
         scroll_y,
         vp_width,
         vp_height
       ) do
    # Estimate content size - we need a buffer large enough to hold the content
    # Use a reasonable maximum to avoid excessive memory usage
    content_width = scroll_x + vp_width + 100
    content_height = scroll_y + vp_height + 100

    # Cap at reasonable limits
    content_width = min(content_width, Buffer.max_cols())
    content_height = min(content_height, Buffer.max_rows())

    # Create temporary buffer for content
    case Buffer.new(content_height, content_width) do
      {:ok, temp_buffer} ->
        # Render content to temporary buffer
        render_node(content, temp_buffer, 1, 1, style)

        # Copy visible region to destination buffer
        # Source region starts at (scroll_y + 1, scroll_x + 1) in temp buffer (1-indexed)
        # Destination starts at (dest_row, dest_col) in main buffer
        for dy <- 0..(vp_height - 1), dx <- 0..(vp_width - 1) do
          src_row = scroll_y + 1 + dy
          src_col = scroll_x + 1 + dx

          cell = Buffer.get_cell(temp_buffer, src_row, src_col)

          # Only copy non-empty cells (or copy all for consistent background)
          Buffer.set_cell(buffer, dest_row + dy, dest_col + dx, cell)
        end

        # Clean up temporary buffer
        Buffer.destroy(temp_buffer)

        {vp_width, vp_height}

      {:error, _reason} ->
        # If we can't create a buffer, just return the viewport dimensions
        {vp_width, vp_height}
    end
  end

  # Fill a rectangular region with a background color
  defp fill_background(buffer, row, col, width, height, bg_style) do
    cell = create_cell(" ", bg_style)

    for dy <- 0..(height - 1), dx <- 0..(width - 1) do
      Buffer.set_cell(buffer, row + dy, col + dx, cell)
    end

    :ok
  end

  # Cell creation
  defp create_cell(char, nil) do
    Cell.new(char)
  end

  defp create_cell(char, %Style{fg: fg, bg: bg, attrs: attrs}) do
    opts = []
    opts = if fg && fg != :default, do: [{:fg, fg} | opts], else: opts
    opts = if bg && bg != :default, do: [{:bg, bg} | opts], else: opts
    opts = if MapSet.size(attrs) > 0, do: [{:attrs, MapSet.to_list(attrs)} | opts], else: opts
    Cell.new(char, opts)
  end

  defp apply_parent_style_to_cell(%Cell{fg: nil, bg: nil, attrs: []} = cell, %Style{} = style) do
    opts = []
    opts = if style.fg && style.fg != :default, do: [{:fg, style.fg} | opts], else: opts
    opts = if style.bg && style.bg != :default, do: [{:bg, style.bg} | opts], else: opts

    opts =
      if MapSet.size(style.attrs) > 0,
        do: [{:attrs, MapSet.to_list(style.attrs)} | opts],
        else: opts

    if opts == [] do
      cell
    else
      %{cell | fg: style.fg, bg: style.bg, attrs: MapSet.to_list(style.attrs)}
    end
  end

  defp apply_parent_style_to_cell(cell, _style), do: cell

  # Style merging
  defp merge_styles(nil, nil), do: nil
  defp merge_styles(nil, style), do: style
  defp merge_styles(style, nil), do: style

  defp merge_styles(%Style{} = parent, %Style{} = child) do
    Style.merge(parent, child)
  end

  # Handle non-Style types (in case of raw maps or tuples)
  defp merge_styles(_parent, child), do: child
end
