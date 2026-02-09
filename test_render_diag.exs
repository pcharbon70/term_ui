#!/usr/bin/env elixir
# Diagnostic: capture actual bytes written during a gauge render frame
# Run: cd examples/gauge && mix run ../../test_render_diag.exs

# Intercept TerminalOutput.write to capture actual bytes
defmodule RenderCapture do
  def run do
    IO.puts("=== Render Diagnostic ===")
    IO.puts("WSL detected: #{TermUI.TerminalOutput.needs_hard_reset?()}")
    IO.puts("ONLCR active: #{TermUI.TerminalOutput.onlcr?()}")

    # Create a minimal raw backend without actual terminal
    {:ok, state} =
      TermUI.Backend.Raw.init(
        size: {24, 80},
        alternate_screen: false,
        hide_cursor: false,
        mouse_tracking: :none
      )

    # Build the gauge view
    view_tree = Gauge.App.view(%{value: 50, gauge_type: :bar})

    # Render to a buffer
    {:ok, buffer_pid} = TermUI.Renderer.BufferManager.start_link(rows: 24, cols: 80)
    TermUI.Renderer.BufferManager.clear_current(buffer_pid)
    TermUI.Runtime.NodeRenderer.render_to_buffer(view_tree, buffer_pid)

    current = TermUI.Renderer.BufferManager.get_current_buffer(buffer_pid)
    previous = TermUI.Renderer.BufferManager.get_previous_buffer(buffer_pid)

    # Get changed cells
    changed = TermUI.Renderer.Buffer.get_changed_cells(current, previous)
    sorted = Enum.sort_by(changed, fn {{row, col}, _} -> {row, col} end)

    IO.puts("Total cells to render: #{length(sorted)}")

    # Capture the draw output
    output =
      ExUnit.CaptureIO.capture_io(fn ->
        TermUI.Backend.Raw.draw_cells(state, sorted)
      end)

    binary = IO.iodata_to_binary(output)
    IO.puts("Output bytes: #{byte_size(binary)}")

    # Check for newlines
    newline_count = binary |> String.graphemes() |> Enum.count(&(&1 == "\n"))
    cr_count = binary |> String.graphemes() |> Enum.count(&(&1 == "\r"))
    IO.puts("Bare \\n (0x0A) count: #{newline_count}")
    IO.puts("Bare \\r (0x0D) count: #{cr_count}")

    if newline_count > 0 do
      IO.puts("\n!!! FOUND NEWLINES IN RENDER OUTPUT !!!")
      # Find positions of newlines
      binary
      |> :binary.bin_to_list()
      |> Enum.with_index()
      |> Enum.filter(fn {byte, _idx} -> byte == 0x0A end)
      |> Enum.each(fn {_byte, idx} ->
        start = max(0, idx - 10)
        len = min(21, byte_size(binary) - start)
        context = :binary.part(binary, start, len)
        IO.puts("  \\n at byte #{idx}: context=#{inspect(context)}")
      end)
    else
      IO.puts("\nNo newlines in render output - rendering is clean.")

      IO.puts(
        "If wrapping issues persist, the problem is elsewhere (ConPTY, terminal size, etc.)"
      )
    end

    # Also report terminal size detection
    IO.puts("\n=== Terminal Size ===")

    case TermUI.Terminal.SizeDetector.auto_detect() do
      {rows, cols} -> IO.puts("Detected: #{rows} rows x #{cols} cols")
      error -> IO.puts("Detection failed: #{inspect(error)}")
    end

    GenServer.stop(buffer_pid)
  end
end

RenderCapture.run()
