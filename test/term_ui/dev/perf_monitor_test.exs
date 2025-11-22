defmodule TermUI.Dev.PerfMonitorTest do
  use ExUnit.Case, async: true

  alias TermUI.Dev.PerfMonitor

  describe "render/2" do
    test "renders performance panel" do
      metrics = %{
        fps: 60.0,
        frame_times: [16000, 17000, 15000],
        memory: 100_000_000,
        process_count: 200
      }

      result = PerfMonitor.render(metrics, %{width: 80, height: 24})

      assert result.type == :positioned
      assert result.z == 195
    end

    test "renders with empty frame times" do
      metrics = %{
        fps: 0.0,
        frame_times: [],
        memory: 50_000_000,
        process_count: 100
      }

      result = PerfMonitor.render(metrics, %{width: 80, height: 24})
      assert result.type == :positioned
    end
  end

  describe "format_bytes/1" do
    test "formats bytes" do
      assert PerfMonitor.format_bytes(500) == "500 B"
    end

    test "formats kilobytes" do
      assert PerfMonitor.format_bytes(1024) == "1.0 KB"
      assert PerfMonitor.format_bytes(2048) == "2.0 KB"
    end

    test "formats megabytes" do
      assert PerfMonitor.format_bytes(1024 * 1024) == "1.0 MB"
      assert PerfMonitor.format_bytes(100 * 1024 * 1024) == "100.0 MB"
    end

    test "formats gigabytes" do
      assert PerfMonitor.format_bytes(2 * 1024 * 1024 * 1024) == "2.0 GB"
    end
  end

  describe "format_time/1" do
    test "formats microseconds" do
      assert PerfMonitor.format_time(500) == "500μs"
    end

    test "formats milliseconds" do
      assert PerfMonitor.format_time(1500) == "1.5ms"
      assert PerfMonitor.format_time(500_000) == "500.0ms"
    end

    test "formats seconds" do
      assert PerfMonitor.format_time(2_500_000) == "2.5s"
    end
  end

  describe "get_memory_breakdown/0" do
    test "returns memory breakdown" do
      breakdown = PerfMonitor.get_memory_breakdown()

      assert is_map(breakdown)
      assert is_integer(breakdown.total)
      assert is_integer(breakdown.processes)
      assert is_integer(breakdown.atom)
      assert is_integer(breakdown.binary)
      assert is_integer(breakdown.code)
      assert is_integer(breakdown.ets)
    end
  end

  describe "get_message_queue_length/1" do
    test "returns queue length for process" do
      length = PerfMonitor.get_message_queue_length(self())
      assert is_integer(length)
      assert length >= 0
    end
  end

  describe "get_reductions/1" do
    test "returns reductions for process" do
      reductions = PerfMonitor.get_reductions(self())
      assert is_integer(reductions)
      assert reductions > 0
    end
  end

  describe "values_to_sparkline/3" do
    test "converts values to sparkline characters" do
      values = [0, 25, 50, 75, 100]
      result = PerfMonitor.values_to_sparkline(values, 0, 100)

      assert is_binary(result)
      assert String.length(result) == 5
    end

    test "handles empty values" do
      result = PerfMonitor.values_to_sparkline([], 0, 100)
      assert result == ""
    end

    test "maps min to lowest bar" do
      result = PerfMonitor.values_to_sparkline([0], 0, 100)
      assert result == "▁"
    end

    test "maps max to highest bar" do
      result = PerfMonitor.values_to_sparkline([100], 0, 100)
      assert result == "█"
    end
  end
end
