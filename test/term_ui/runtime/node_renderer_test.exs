defmodule TermUI.Runtime.NodeRendererTest do
  use ExUnit.Case, async: true

  alias TermUI.Renderer.Buffer
  alias TermUI.Renderer.BufferManager
  alias TermUI.Runtime.NodeRenderer

  setup do
    # Generate a unique name for each test to avoid conflicts
    name = :"buffer_manager_#{System.unique_integer([:positive])}"
    {:ok, pid} = BufferManager.start_link(rows: 30, cols: 50, name: name)

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    {:ok, bm: pid}
  end

  describe "render_to_buffer/4" do
    test "renders text node", %{bm: bm} do
      NodeRenderer.render_to_buffer({:text, "Hello"}, bm, 1, 1)

      buffer = BufferManager.get_current_buffer(bm)
      assert Buffer.get_cell(buffer, 1, 1).char == "H"
      assert Buffer.get_cell(buffer, 1, 2).char == "e"
      assert Buffer.get_cell(buffer, 1, 3).char == "l"
      assert Buffer.get_cell(buffer, 1, 4).char == "l"
      assert Buffer.get_cell(buffer, 1, 5).char == "o"
    end

    test "renders list of text nodes vertically", %{bm: bm} do
      NodeRenderer.render_to_buffer([{:text, "Line1"}, {:text, "Line2"}], bm, 1, 1)

      buffer = BufferManager.get_current_buffer(bm)
      assert Buffer.get_cell(buffer, 1, 1).char == "L"
      assert Buffer.get_cell(buffer, 2, 1).char == "L"
    end
  end

  describe "viewport rendering" do
    test "renders viewport content without scroll", %{bm: bm} do
      viewport_node = %{
        type: :viewport,
        content: {:text, "Hello World"},
        scroll_x: 0,
        scroll_y: 0,
        width: 20,
        height: 5
      }

      {width, height} = NodeRenderer.render_to_buffer(viewport_node, bm, 1, 1)

      assert width == 20
      assert height == 5

      buffer = BufferManager.get_current_buffer(bm)
      assert Buffer.get_cell(buffer, 1, 1).char == "H"
      assert Buffer.get_cell(buffer, 1, 2).char == "e"
      assert Buffer.get_cell(buffer, 1, 5).char == "o"
    end

    test "renders viewport content with horizontal scroll", %{bm: bm} do
      viewport_node = %{
        type: :viewport,
        content: {:text, "Hello World"},
        scroll_x: 6,
        scroll_y: 0,
        width: 10,
        height: 5
      }

      NodeRenderer.render_to_buffer(viewport_node, bm, 1, 1)

      buffer = BufferManager.get_current_buffer(bm)
      # After scrolling 6 chars, "World" should be at position 1
      assert Buffer.get_cell(buffer, 1, 1).char == "W"
      assert Buffer.get_cell(buffer, 1, 2).char == "o"
      assert Buffer.get_cell(buffer, 1, 3).char == "r"
    end

    test "renders viewport content with vertical scroll", %{bm: bm} do
      # Multi-line content
      content = [{:text, "Line 1"}, {:text, "Line 2"}, {:text, "Line 3"}, {:text, "Line 4"}]

      viewport_node = %{
        type: :viewport,
        content: content,
        scroll_x: 0,
        scroll_y: 2,
        width: 20,
        height: 2
      }

      NodeRenderer.render_to_buffer(viewport_node, bm, 1, 1)

      buffer = BufferManager.get_current_buffer(bm)
      # After scrolling 2 lines, "Line 3" should be at row 1
      assert Buffer.get_cell(buffer, 1, 1).char == "L"
      assert Buffer.get_cell(buffer, 1, 6).char == "3"
      # And "Line 4" at row 2
      assert Buffer.get_cell(buffer, 2, 6).char == "4"
    end

    test "clips content to viewport dimensions", %{bm: bm} do
      # Content that exceeds viewport
      viewport_node = %{
        type: :viewport,
        content: {:text, "This is a very long line that should be clipped"},
        scroll_x: 0,
        scroll_y: 0,
        width: 10,
        height: 1
      }

      {width, height} = NodeRenderer.render_to_buffer(viewport_node, bm, 5, 5)

      assert width == 10
      assert height == 1

      buffer = BufferManager.get_current_buffer(bm)
      # Content starts at (5, 5)
      assert Buffer.get_cell(buffer, 5, 5).char == "T"
      assert Buffer.get_cell(buffer, 5, 14).char == " "
    end

    test "handles empty content", %{bm: bm} do
      viewport_node = %{
        type: :viewport,
        content: {:text, ""},
        scroll_x: 0,
        scroll_y: 0,
        width: 10,
        height: 5
      }

      {width, height} = NodeRenderer.render_to_buffer(viewport_node, bm, 1, 1)

      assert width == 10
      assert height == 5
    end

    test "combined horizontal and vertical scroll", %{bm: bm} do
      # Create a grid-like content
      content = [
        {:text, "ABCDEFGHIJ"},
        {:text, "KLMNOPQRST"},
        {:text, "UVWXYZ0123"},
        {:text, "4567890abc"}
      ]

      viewport_node = %{
        type: :viewport,
        content: content,
        scroll_x: 2,
        scroll_y: 1,
        width: 5,
        height: 2
      }

      NodeRenderer.render_to_buffer(viewport_node, bm, 1, 1)

      buffer = BufferManager.get_current_buffer(bm)
      # Row 1 should show "MNOPQ" (from "KLMNOPQRST" starting at col 3)
      assert Buffer.get_cell(buffer, 1, 1).char == "M"
      assert Buffer.get_cell(buffer, 1, 2).char == "N"
      # Row 2 should show "WXYZ0" (from "UVWXYZ0123" starting at col 3)
      assert Buffer.get_cell(buffer, 2, 1).char == "W"
      assert Buffer.get_cell(buffer, 2, 2).char == "X"
    end
  end
end
