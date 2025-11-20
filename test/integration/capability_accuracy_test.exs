defmodule TermUI.Integration.CapabilityAccuracyTest do
  @moduledoc """
  Integration tests for capability detection accuracy.

  Validates that capability detection accurately reflects terminal features
  for various terminal emulators and configurations.
  """

  use ExUnit.Case, async: false

  alias TermUI.Capabilities
  alias TermUI.Capabilities.Fallbacks
  alias TermUI.IntegrationHelpers

  # These tests validate capability detection
  @moduletag :integration

  setup do
    IntegrationHelpers.stop_terminal()

    on_exit(fn ->
      IntegrationHelpers.cleanup_terminal()
    end)

    :ok
  end

  describe "1.6.3.1 color capability detection" do
    test "detects color mode from TERM variable" do
      IntegrationHelpers.with_env(IntegrationHelpers.mock_terminal_env(:xterm_256color), fn ->
        # Clear cache to force re-detection
        Capabilities.clear_cache()

        caps = Capabilities.detect()

        assert caps.color_mode in [:color_256, :true_color]
        assert caps.max_colors >= 256
      end)
    end

    test "detects truecolor from COLORTERM" do
      IntegrationHelpers.with_env(IntegrationHelpers.mock_terminal_env(:truecolor), fn ->
        Capabilities.clear_cache()

        caps = Capabilities.detect()

        assert caps.color_mode == :true_color
        assert caps.max_colors == 16_777_216
      end)
    end

    test "detects basic 16 colors from xterm" do
      IntegrationHelpers.with_env(IntegrationHelpers.mock_terminal_env(:basic), fn ->
        Capabilities.clear_cache()

        caps = Capabilities.detect()

        # Basic xterm defaults to 16 colors
        assert caps.color_mode in [:color_16, :color_256]
        assert caps.max_colors >= 16
      end)
    end

    test "iTerm2 detection from TERM_PROGRAM" do
      IntegrationHelpers.with_env(IntegrationHelpers.mock_terminal_env(:iterm2), fn ->
        Capabilities.clear_cache()

        caps = Capabilities.detect()

        # iTerm2 supports true color
        assert caps.color_mode == :true_color
        assert caps.max_colors == 16_777_216
        assert caps.terminal_program == "iTerm.app"
      end)
    end

    test "color mode hierarchy is correct" do
      modes = [:monochrome, :color_16, :color_256, :true_color]

      for {mode, index} <- Enum.with_index(modes) do
        color_count =
          case mode do
            :monochrome -> 2
            :color_16 -> 16
            :color_256 -> 256
            :true_color -> 16_777_216
          end

        assert color_count > 0, "#{mode} should have positive color count"

        if index > 0 do
          prev_mode = Enum.at(modes, index - 1)

          prev_count =
            case prev_mode do
              :monochrome -> 2
              :color_16 -> 16
              :color_256 -> 256
              :true_color -> 16_777_216
            end

          assert color_count > prev_count, "#{mode} should have more colors than #{prev_mode}"
        end
      end
    end
  end

  describe "1.6.3.2 mouse support detection" do
    test "capability hints include mouse support" do
      caps = Capabilities.detect()

      assert Map.has_key?(caps, :mouse)
      assert is_boolean(caps.mouse)
    end

    test "most terminals support mouse tracking" do
      IntegrationHelpers.with_env(IntegrationHelpers.mock_terminal_env(:xterm_256color), fn ->
        Capabilities.clear_cache()

        caps = Capabilities.detect()

        # xterm-based terminals support mouse
        assert caps.mouse == true
      end)
    end

    test "mouse capability consistent with terminal type" do
      IntegrationHelpers.with_env(IntegrationHelpers.mock_terminal_env(:iterm2), fn ->
        Capabilities.clear_cache()

        caps = Capabilities.detect()

        # iTerm2 supports mouse
        assert caps.mouse == true
      end)
    end
  end

  describe "1.6.3.3 Unicode detection" do
    test "detects Unicode support" do
      caps = Capabilities.detect()

      assert Map.has_key?(caps, :unicode)
      assert is_boolean(caps.unicode)
    end

    test "Unicode detection from LC_ALL" do
      original_lc = System.get_env("LC_ALL")
      original_lang = System.get_env("LANG")

      try do
        # Set UTF-8 locale
        System.put_env("LC_ALL", "en_US.UTF-8")
        System.put_env("LANG", "en_US.UTF-8")
        Capabilities.clear_cache()

        caps = Capabilities.detect()

        assert caps.unicode == true
      after
        # Restore
        if original_lc, do: System.put_env("LC_ALL", original_lc), else: System.delete_env("LC_ALL")
        if original_lang, do: System.put_env("LANG", original_lang), else: System.delete_env("LANG")
      end
    end

    test "Unicode fallbacks work correctly" do
      # Test box drawing fallbacks
      assert Fallbacks.unicode_to_ascii("┌") == "+"
      assert Fallbacks.unicode_to_ascii("─") == "-"
      assert Fallbacks.unicode_to_ascii("│") == "|"
      assert Fallbacks.unicode_to_ascii("┘") == "+"

      # Test arrows
      assert Fallbacks.unicode_to_ascii("→") == ">"
      assert Fallbacks.unicode_to_ascii("←") == "<"
      assert Fallbacks.unicode_to_ascii("↑") == "^"
      assert Fallbacks.unicode_to_ascii("↓") == "v"
    end

    test "Unicode to ASCII preserves ASCII" do
      ascii_string = "Hello, World!"
      assert Fallbacks.unicode_to_ascii(ascii_string) == ascii_string
    end
  end

  describe "1.6.3.4 capability query timeouts" do
    test "detection completes in reasonable time" do
      start = System.monotonic_time(:millisecond)
      _caps = Capabilities.detect()
      elapsed = System.monotonic_time(:millisecond) - start

      # Should complete within 1 second
      assert elapsed < 1000, "Detection took #{elapsed}ms, expected < 1000ms"
    end

    test "cached detection is fast" do
      # First call populates cache
      Capabilities.detect()

      # Second call should be near-instant (cached)
      start = System.monotonic_time(:millisecond)
      _caps = Capabilities.detect()
      elapsed = System.monotonic_time(:millisecond) - start

      # Should be under 10ms for cached result
      assert elapsed < 10, "Cached detection took #{elapsed}ms, expected < 10ms"
    end

    test "cache can be cleared" do
      # Populate cache
      caps1 = Capabilities.detect()

      # Clear and re-detect with different environment
      IntegrationHelpers.with_env(IntegrationHelpers.mock_terminal_env(:truecolor), fn ->
        Capabilities.clear_cache()
        caps2 = Capabilities.detect()

        # Results may differ based on environment
        # Just verify we got valid capabilities
        assert is_struct(caps1, Capabilities)
        assert is_struct(caps2, Capabilities)
      end)
    end
  end

  describe "color approximation accuracy" do
    test "RGB to 256 color approximation" do
      # Pure red should map to color 196 (bright red in cube)
      index = Fallbacks.rgb_to_256(255, 0, 0)
      assert index in [196, 9], "Expected red to map to 196 or 9, got #{index}"

      # Pure green
      index = Fallbacks.rgb_to_256(0, 255, 0)
      assert index in [46, 10], "Expected green to map to 46 or 10, got #{index}"

      # Pure blue
      index = Fallbacks.rgb_to_256(0, 0, 255)
      assert index in [21, 12], "Expected blue to map to 21 or 12, got #{index}"

      # White - grayscale 255 (232 + 23)
      index = Fallbacks.rgb_to_256(255, 255, 255)
      assert index in [231, 255, 15], "Expected white to map to grayscale, got #{index}"

      # Black - grayscale 232 (232 + 0)
      index = Fallbacks.rgb_to_256(0, 0, 0)
      assert index in [16, 232, 0], "Expected black to map to 16 or grayscale, got #{index}"
    end

    test "RGB to 16 color approximation" do
      # Red
      index = Fallbacks.rgb_to_16(255, 0, 0)
      assert index in [1, 9], "Expected red, got #{index}"

      # Green
      index = Fallbacks.rgb_to_16(0, 255, 0)
      assert index in [2, 10], "Expected green, got #{index}"

      # Blue
      index = Fallbacks.rgb_to_16(0, 0, 255)
      assert index in [4, 12], "Expected blue, got #{index}"

      # White
      index = Fallbacks.rgb_to_16(255, 255, 255)
      assert index in [7, 15], "Expected white, got #{index}"

      # Black
      index = Fallbacks.rgb_to_16(0, 0, 0)
      assert index == 0, "Expected black (0), got #{index}"
    end

    test "256 to 16 color degradation" do
      # Standard colors should map to themselves
      for i <- 0..15 do
        result = Fallbacks.color_256_to_16(i)
        assert result == i, "Standard color #{i} should map to itself, got #{result}"
      end

      # Cube colors should map to nearest 16
      result = Fallbacks.color_256_to_16(196)
      assert result in 0..15, "Color 196 should map to 0-15, got #{result}"
    end
  end

  describe "terminal feature detection" do
    test "bracketed paste capability" do
      caps = Capabilities.detect()

      assert Map.has_key?(caps, :bracketed_paste)
      assert is_boolean(caps.bracketed_paste)
    end

    test "focus events capability" do
      caps = Capabilities.detect()

      assert Map.has_key?(caps, :focus_events)
      assert is_boolean(caps.focus_events)
    end

    test "alternate screen capability" do
      caps = Capabilities.detect()

      assert Map.has_key?(caps, :alternate_screen)
      assert is_boolean(caps.alternate_screen)
    end

    test "all capabilities are populated" do
      caps = Capabilities.detect()

      required_fields = [
        :color_mode,
        :max_colors,
        :unicode,
        :mouse,
        :bracketed_paste,
        :focus_events,
        :alternate_screen,
        :terminal_type
      ]

      for field <- required_fields do
        assert Map.has_key?(caps, field), "Missing required field: #{field}"
      end
    end
  end

  describe "known terminal capabilities" do
    @known_terminals %{
      "xterm" => %{min_colors: 16},
      "xterm-256color" => %{min_colors: 256},
      "screen" => %{min_colors: 16},
      "screen-256color" => %{min_colors: 256},
      "tmux" => %{min_colors: 16},
      "tmux-256color" => %{min_colors: 256}
    }

    for {term, expected} <- @known_terminals do
      @term term
      @expected expected

      test "#{term} has at least #{expected.min_colors} colors" do
        IntegrationHelpers.with_env(%{"TERM" => @term, "COLORTERM" => nil}, fn ->
          Capabilities.clear_cache()

          caps = Capabilities.detect()

          assert caps.max_colors >= @expected.min_colors,
                 "#{@term} should have at least #{@expected.min_colors} colors, got #{caps.max_colors}"
        end)
      end
    end
  end
end
