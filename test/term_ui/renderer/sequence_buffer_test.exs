defmodule TermUI.Renderer.SequenceBufferTest do
  use ExUnit.Case, async: true

  alias TermUI.Renderer.SequenceBuffer
  alias TermUI.Renderer.Style

  describe "new/0 and new/1" do
    test "creates empty buffer with default threshold" do
      buffer = SequenceBuffer.new()
      assert SequenceBuffer.size(buffer) == 0
      assert SequenceBuffer.empty?(buffer)
    end

    test "creates buffer with custom threshold" do
      buffer = SequenceBuffer.new(threshold: 1024)
      assert buffer.threshold == 1024
    end
  end

  describe "append/2" do
    test "appends data to buffer" do
      buffer = SequenceBuffer.new()
      {:ok, buffer} = SequenceBuffer.append(buffer, "Hello")
      assert SequenceBuffer.size(buffer) == 5
    end

    test "accumulates multiple appends" do
      buffer = SequenceBuffer.new()
      {:ok, buffer} = SequenceBuffer.append(buffer, "Hello")
      {:ok, buffer} = SequenceBuffer.append(buffer, " ")
      {:ok, buffer} = SequenceBuffer.append(buffer, "World")
      assert SequenceBuffer.size(buffer) == 11
    end

    test "triggers auto-flush when threshold exceeded" do
      buffer = SequenceBuffer.new(threshold: 10)
      {:ok, buffer} = SequenceBuffer.append(buffer, "12345")
      {:flush, data, buffer} = SequenceBuffer.append(buffer, "67890!")

      assert IO.iodata_to_binary(data) == "1234567890!"
      assert SequenceBuffer.size(buffer) == 0
    end

    test "handles iolist data" do
      buffer = SequenceBuffer.new()
      {:ok, buffer} = SequenceBuffer.append(buffer, ["Hello", " ", "World"])
      assert SequenceBuffer.size(buffer) == 11
    end
  end

  describe "append!/2" do
    test "appends without returning flush status" do
      buffer = SequenceBuffer.new()
      buffer = SequenceBuffer.append!(buffer, "Test")
      assert SequenceBuffer.size(buffer) == 4
    end

    test "handles auto-flush silently" do
      buffer = SequenceBuffer.new(threshold: 5)
      buffer = SequenceBuffer.append!(buffer, "12345678")
      # Buffer was auto-flushed
      assert SequenceBuffer.size(buffer) == 0
    end
  end

  describe "flush/1" do
    test "returns accumulated data" do
      buffer = SequenceBuffer.new()
      buffer = SequenceBuffer.append!(buffer, "Hello")
      buffer = SequenceBuffer.append!(buffer, " World")

      {data, _buffer} = SequenceBuffer.flush(buffer)
      assert IO.iodata_to_binary(data) == "Hello World"
    end

    test "resets buffer after flush" do
      buffer = SequenceBuffer.new()
      buffer = SequenceBuffer.append!(buffer, "Test")
      {_data, buffer} = SequenceBuffer.flush(buffer)

      assert SequenceBuffer.size(buffer) == 0
      assert SequenceBuffer.empty?(buffer)
    end

    test "increments flush count" do
      buffer = SequenceBuffer.new()
      buffer = SequenceBuffer.append!(buffer, "Test")
      {_data, buffer} = SequenceBuffer.flush(buffer)

      {_bytes, count} = SequenceBuffer.stats(buffer)
      assert count == 1
    end

    test "tracks total bytes" do
      buffer = SequenceBuffer.new()
      buffer = SequenceBuffer.append!(buffer, "12345")
      {_data, buffer} = SequenceBuffer.flush(buffer)

      {bytes, _count} = SequenceBuffer.stats(buffer)
      assert bytes == 5
    end

    test "handles empty buffer" do
      buffer = SequenceBuffer.new()
      {data, buffer} = SequenceBuffer.flush(buffer)

      assert data == []
      {bytes, count} = SequenceBuffer.stats(buffer)
      assert bytes == 0
      assert count == 1
    end
  end

  describe "SGR combining" do
    test "add_sgr_param/2 accumulates parameters" do
      buffer = SequenceBuffer.new()
      buffer = SequenceBuffer.add_sgr_param(buffer, "1")
      buffer = SequenceBuffer.add_sgr_param(buffer, "31")

      assert length(buffer.pending_sgr) == 2
    end

    test "emit_pending_sgr/1 outputs combined sequence" do
      buffer = SequenceBuffer.new()
      buffer = SequenceBuffer.add_sgr_param(buffer, "1")
      buffer = SequenceBuffer.add_sgr_param(buffer, "31")
      buffer = SequenceBuffer.emit_pending_sgr(buffer)

      {data, _buffer} = SequenceBuffer.flush(buffer)
      binary = IO.iodata_to_binary(data)

      # Should be ESC[1;31m
      assert binary == "\e[1;31m"
    end

    test "emit_pending_sgr/1 clears pending" do
      buffer = SequenceBuffer.new()
      buffer = SequenceBuffer.add_sgr_param(buffer, "1")
      buffer = SequenceBuffer.emit_pending_sgr(buffer)

      assert buffer.pending_sgr == []
    end

    test "flush emits pending SGR" do
      buffer = SequenceBuffer.new()
      buffer = SequenceBuffer.add_sgr_param(buffer, "4")
      {data, _buffer} = SequenceBuffer.flush(buffer)

      binary = IO.iodata_to_binary(data)
      assert binary == "\e[4m"
    end
  end

  describe "append_style/2" do
    test "emits full SGR for first style" do
      buffer = SequenceBuffer.new()
      style = Style.new(fg: :red, attrs: [:bold])
      buffer = SequenceBuffer.append_style(buffer, style)

      {data, _buffer} = SequenceBuffer.flush(buffer)
      binary = IO.iodata_to_binary(data)

      assert String.contains?(binary, "31")
      assert String.contains?(binary, "1")
    end

    test "emits only delta for subsequent style" do
      buffer = SequenceBuffer.new()
      style1 = Style.new(fg: :red, attrs: [:bold])
      style2 = Style.new(fg: :blue, attrs: [:bold])

      buffer = SequenceBuffer.append_style(buffer, style1)
      {_data, buffer} = SequenceBuffer.flush(buffer)

      buffer = SequenceBuffer.append_style(buffer, style2)
      {data, _buffer} = SequenceBuffer.flush(buffer)
      binary = IO.iodata_to_binary(data)

      # Should only emit blue (34), not bold again
      assert String.contains?(binary, "34")
      refute String.contains?(binary, ";1")
    end

    test "emits nothing for identical style" do
      buffer = SequenceBuffer.new()
      style = Style.new(fg: :red)

      buffer = SequenceBuffer.append_style(buffer, style)
      {_data, buffer} = SequenceBuffer.flush(buffer)

      buffer = SequenceBuffer.append_style(buffer, style)
      {data, _buffer} = SequenceBuffer.flush(buffer)

      assert data == []
    end

    test "handles attribute removal" do
      buffer = SequenceBuffer.new()
      style1 = Style.new(attrs: [:bold, :underline])
      style2 = Style.new(attrs: [:bold])

      buffer = SequenceBuffer.append_style(buffer, style1)
      {_data, buffer} = SequenceBuffer.flush(buffer)

      buffer = SequenceBuffer.append_style(buffer, style2)
      {data, _buffer} = SequenceBuffer.flush(buffer)
      binary = IO.iodata_to_binary(data)

      # Should emit underline off (24)
      assert String.contains?(binary, "24")
    end
  end

  describe "size tracking" do
    test "size/1 returns current buffer size" do
      buffer = SequenceBuffer.new()
      assert SequenceBuffer.size(buffer) == 0

      buffer = SequenceBuffer.append!(buffer, "12345")
      assert SequenceBuffer.size(buffer) == 5
    end

    test "empty?/1 returns true for empty buffer" do
      buffer = SequenceBuffer.new()
      assert SequenceBuffer.empty?(buffer)
    end

    test "empty?/1 returns false for non-empty buffer" do
      buffer = SequenceBuffer.new()
      buffer = SequenceBuffer.append!(buffer, "x")
      refute SequenceBuffer.empty?(buffer)
    end
  end

  describe "to_iodata/1" do
    test "returns buffer contents without flushing" do
      buffer = SequenceBuffer.new()
      buffer = SequenceBuffer.append!(buffer, "Test")

      data = SequenceBuffer.to_iodata(buffer)
      assert IO.iodata_to_binary(data) == "Test"

      # Buffer still has content
      assert SequenceBuffer.size(buffer) == 4
    end
  end

  describe "reset_style/1" do
    test "clears last style tracking" do
      buffer = SequenceBuffer.new()
      style = Style.new(fg: :red)
      buffer = SequenceBuffer.append_style(buffer, style)

      buffer = SequenceBuffer.reset_style(buffer)
      assert buffer.last_style == nil
    end
  end

  describe "clear/1" do
    test "clears buffer without flushing" do
      buffer = SequenceBuffer.new()
      buffer = SequenceBuffer.append!(buffer, "Test")
      buffer = SequenceBuffer.clear(buffer)

      assert SequenceBuffer.empty?(buffer)

      # Stats unchanged
      {bytes, count} = SequenceBuffer.stats(buffer)
      assert bytes == 0
      assert count == 0
    end
  end

  describe "stats/1" do
    test "tracks cumulative bytes across flushes" do
      buffer = SequenceBuffer.new()
      buffer = SequenceBuffer.append!(buffer, "12345")
      {_data, buffer} = SequenceBuffer.flush(buffer)

      buffer = SequenceBuffer.append!(buffer, "67890")
      {_data, buffer} = SequenceBuffer.flush(buffer)

      {bytes, count} = SequenceBuffer.stats(buffer)
      assert bytes == 10
      assert count == 2
    end
  end

  describe "color SGR codes" do
    test "generates correct foreground color codes" do
      buffer = SequenceBuffer.new()

      for {color, code} <- [
            {:black, "30"},
            {:red, "31"},
            {:green, "32"},
            {:yellow, "33"},
            {:blue, "34"},
            {:magenta, "35"},
            {:cyan, "36"},
            {:white, "37"}
          ] do
        style = Style.new(fg: color)
        buf = SequenceBuffer.append_style(buffer, style)
        {data, _} = SequenceBuffer.flush(buf)
        binary = IO.iodata_to_binary(data)
        assert String.contains?(binary, code), "Expected #{code} for #{color}"
      end
    end

    test "generates correct background color codes" do
      buffer = SequenceBuffer.new()

      for {color, code} <- [
            {:black, "40"},
            {:red, "41"},
            {:green, "42"},
            {:yellow, "43"},
            {:blue, "44"},
            {:magenta, "45"},
            {:cyan, "46"},
            {:white, "47"}
          ] do
        style = Style.new(bg: color)
        buf = SequenceBuffer.append_style(buffer, style)
        {data, _} = SequenceBuffer.flush(buf)
        binary = IO.iodata_to_binary(data)
        assert String.contains?(binary, code), "Expected #{code} for #{color}"
      end
    end

    test "generates correct bright foreground color codes" do
      buffer = SequenceBuffer.new()

      for {color, code} <- [
            {:bright_black, "90"},
            {:bright_red, "91"},
            {:bright_green, "92"},
            {:bright_yellow, "93"},
            {:bright_blue, "94"},
            {:bright_magenta, "95"},
            {:bright_cyan, "96"},
            {:bright_white, "97"}
          ] do
        style = Style.new(fg: color)
        buf = SequenceBuffer.append_style(buffer, style)
        {data, _} = SequenceBuffer.flush(buf)
        binary = IO.iodata_to_binary(data)
        assert String.contains?(binary, code), "Expected #{code} for #{color}"
      end
    end

    test "generates correct bright background color codes" do
      buffer = SequenceBuffer.new()

      for {color, code} <- [
            {:bright_black, "100"},
            {:bright_red, "101"},
            {:bright_green, "102"},
            {:bright_yellow, "103"},
            {:bright_blue, "104"},
            {:bright_magenta, "105"},
            {:bright_cyan, "106"},
            {:bright_white, "107"}
          ] do
        style = Style.new(bg: color)
        buf = SequenceBuffer.append_style(buffer, style)
        {data, _} = SequenceBuffer.flush(buf)
        binary = IO.iodata_to_binary(data)
        assert String.contains?(binary, code), "Expected #{code} for #{color}"
      end
    end

    test "generates 256-color codes" do
      buffer = SequenceBuffer.new()
      style = Style.new(fg: 196)
      buffer = SequenceBuffer.append_style(buffer, style)
      {data, _buffer} = SequenceBuffer.flush(buffer)
      binary = IO.iodata_to_binary(data)

      assert String.contains?(binary, "38;5;196")
    end

    test "generates RGB color codes" do
      buffer = SequenceBuffer.new()
      style = Style.new(fg: {255, 128, 64})
      buffer = SequenceBuffer.append_style(buffer, style)
      {data, _buffer} = SequenceBuffer.flush(buffer)
      binary = IO.iodata_to_binary(data)

      assert String.contains?(binary, "38;2;255;128;64")
    end
  end

  describe "integration scenarios" do
    test "typical render frame" do
      buffer = SequenceBuffer.new()

      # Move cursor and set style
      buffer = SequenceBuffer.append!(buffer, "\e[1;1H")
      style = Style.new(fg: :green, attrs: [:bold])
      buffer = SequenceBuffer.append_style(buffer, style)
      buffer = SequenceBuffer.append!(buffer, "Status: OK")

      # Another styled section
      style2 = Style.new(fg: :red, attrs: [:bold])
      buffer = SequenceBuffer.append_style(buffer, style2)
      buffer = SequenceBuffer.append!(buffer, " Warning")

      # Flush frame
      {data, buffer} = SequenceBuffer.flush(buffer)
      binary = IO.iodata_to_binary(data)

      assert String.contains?(binary, "\e[1;1H")
      assert String.contains?(binary, "Status: OK")
      assert String.contains?(binary, "Warning")

      {bytes, count} = SequenceBuffer.stats(buffer)
      assert bytes > 0
      assert count == 1
    end

    test "multiple frames" do
      buffer = SequenceBuffer.new()

      # Frame 1
      buffer = SequenceBuffer.append!(buffer, "Frame 1")
      {_data, buffer} = SequenceBuffer.flush(buffer)

      # Frame 2
      buffer = SequenceBuffer.append!(buffer, "Frame 2")
      {_data, buffer} = SequenceBuffer.flush(buffer)

      {bytes, count} = SequenceBuffer.stats(buffer)
      assert bytes == 14
      assert count == 2
    end
  end

  describe "edge cases for coverage" do
    test "style with only attributes emits attribute codes" do
      buffer = SequenceBuffer.new()
      # Style with only attributes, no colors
      style = Style.new(attrs: [:bold])
      buffer = SequenceBuffer.append_style(buffer, style)
      {data, _buffer} = SequenceBuffer.flush(buffer)
      binary = IO.iodata_to_binary(data)

      # Should contain bold code but no color codes
      assert String.contains?(binary, "1")
      refute String.contains?(binary, "38;")
      refute String.contains?(binary, "48;")
    end

    test "style with nil colors does not emit SGR codes" do
      buffer = SequenceBuffer.new()
      # Style with nil colors (default new())
      style = Style.new()
      buffer = SequenceBuffer.append_style(buffer, style)
      {data, _buffer} = SequenceBuffer.flush(buffer)
      binary = IO.iodata_to_binary(data)

      # Empty style should produce no output
      assert binary == ""
    end

    test "removing multiple attributes emits correct off codes" do
      buffer = SequenceBuffer.new()

      # First style with multiple attributes
      style1 = Style.new(attrs: [:bold, :italic, :underline])
      buffer = SequenceBuffer.append_style(buffer, style1)
      {_data, buffer} = SequenceBuffer.flush(buffer)

      # Second style removes all attributes
      style2 = Style.new()
      buffer = SequenceBuffer.append_style(buffer, style2)
      {data, _buffer} = SequenceBuffer.flush(buffer)
      binary = IO.iodata_to_binary(data)

      # Should contain off codes for removed attributes
      # bold off
      assert String.contains?(binary, "22")
      # italic off
      assert String.contains?(binary, "23")
      # underline off
      assert String.contains?(binary, "24")
    end

    test "removing blink attribute emits correct off code" do
      buffer = SequenceBuffer.new()

      style1 = Style.new(attrs: [:blink])
      buffer = SequenceBuffer.append_style(buffer, style1)
      {_data, buffer} = SequenceBuffer.flush(buffer)

      style2 = Style.new()
      buffer = SequenceBuffer.append_style(buffer, style2)
      {data, _buffer} = SequenceBuffer.flush(buffer)
      binary = IO.iodata_to_binary(data)

      # blink off
      assert String.contains?(binary, "25")
    end

    test "removing reverse attribute emits correct off code" do
      buffer = SequenceBuffer.new()

      style1 = Style.new(attrs: [:reverse])
      buffer = SequenceBuffer.append_style(buffer, style1)
      {_data, buffer} = SequenceBuffer.flush(buffer)

      style2 = Style.new()
      buffer = SequenceBuffer.append_style(buffer, style2)
      {data, _buffer} = SequenceBuffer.flush(buffer)
      binary = IO.iodata_to_binary(data)

      # reverse off
      assert String.contains?(binary, "27")
    end

    test "removing hidden attribute emits correct off code" do
      buffer = SequenceBuffer.new()

      style1 = Style.new(attrs: [:hidden])
      buffer = SequenceBuffer.append_style(buffer, style1)
      {_data, buffer} = SequenceBuffer.flush(buffer)

      style2 = Style.new()
      buffer = SequenceBuffer.append_style(buffer, style2)
      {data, _buffer} = SequenceBuffer.flush(buffer)
      binary = IO.iodata_to_binary(data)

      # hidden off
      assert String.contains?(binary, "28")
    end

    test "removing strikethrough attribute emits correct off code" do
      buffer = SequenceBuffer.new()

      style1 = Style.new(attrs: [:strikethrough])
      buffer = SequenceBuffer.append_style(buffer, style1)
      {_data, buffer} = SequenceBuffer.flush(buffer)

      style2 = Style.new()
      buffer = SequenceBuffer.append_style(buffer, style2)
      {data, _buffer} = SequenceBuffer.flush(buffer)
      binary = IO.iodata_to_binary(data)

      # strikethrough off
      assert String.contains?(binary, "29")
    end

    test "removing dim attribute uses same off code as bold" do
      buffer = SequenceBuffer.new()

      style1 = Style.new(attrs: [:dim])
      buffer = SequenceBuffer.append_style(buffer, style1)
      {_data, buffer} = SequenceBuffer.flush(buffer)

      style2 = Style.new()
      buffer = SequenceBuffer.append_style(buffer, style2)
      {data, _buffer} = SequenceBuffer.flush(buffer)
      binary = IO.iodata_to_binary(data)

      # dim off (same as bold)
      assert String.contains?(binary, "22")
    end

    test "background color change emits new background code" do
      buffer = SequenceBuffer.new()

      style1 = Style.new(bg: :red)
      buffer = SequenceBuffer.append_style(buffer, style1)
      {_data, buffer} = SequenceBuffer.flush(buffer)

      style2 = Style.new(bg: :blue)
      buffer = SequenceBuffer.append_style(buffer, style2)
      {data, _buffer} = SequenceBuffer.flush(buffer)
      binary = IO.iodata_to_binary(data)

      # blue background
      assert String.contains?(binary, "44")
    end
  end
end
