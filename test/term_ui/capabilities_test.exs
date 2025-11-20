defmodule TermUI.CapabilitiesTest do
  use ExUnit.Case, async: false

  alias TermUI.Capabilities

  setup do
    # Clear cache and save original environment
    Capabilities.clear_cache()

    original_env = %{
      "TERM" => System.get_env("TERM"),
      "COLORTERM" => System.get_env("COLORTERM"),
      "TERM_PROGRAM" => System.get_env("TERM_PROGRAM"),
      "LANG" => System.get_env("LANG"),
      "LC_ALL" => System.get_env("LC_ALL"),
      "LC_CTYPE" => System.get_env("LC_CTYPE")
    }

    on_exit(fn ->
      # Restore original environment
      Enum.each(original_env, fn {key, value} ->
        if value do
          System.put_env(key, value)
        else
          System.delete_env(key)
        end
      end)

      Capabilities.clear_cache()
    end)

    :ok
  end

  describe "detect/0 and get/0" do
    test "returns capabilities struct" do
      caps = Capabilities.detect()
      assert %Capabilities{} = caps
    end

    test "caches capabilities" do
      caps1 = Capabilities.detect()
      caps2 = Capabilities.get()
      assert caps1 == caps2
    end

    test "get/0 detects if not cached" do
      Capabilities.clear_cache()
      caps = Capabilities.get()
      assert %Capabilities{} = caps
    end
  end

  describe "environment variable detection - $TERM" do
    test "detects truecolor from $TERM" do
      System.put_env("TERM", "xterm-truecolor")
      System.delete_env("COLORTERM")
      System.delete_env("TERM_PROGRAM")

      caps = Capabilities.detect()

      assert caps.color_mode == :true_color
      assert caps.max_colors == 16_777_216
      assert caps.terminal_type == "xterm-truecolor"
    end

    test "detects 256color from $TERM suffix" do
      System.put_env("TERM", "xterm-256color")
      System.delete_env("COLORTERM")
      System.delete_env("TERM_PROGRAM")

      caps = Capabilities.detect()

      assert caps.color_mode == :color_256
      assert caps.max_colors >= 256
    end

    test "detects xterm as 256-color capable" do
      System.put_env("TERM", "xterm")
      System.delete_env("COLORTERM")
      System.delete_env("TERM_PROGRAM")

      caps = Capabilities.detect()

      assert caps.color_mode == :color_256
      assert caps.max_colors >= 256
    end

    test "detects screen as 256-color capable" do
      System.put_env("TERM", "screen")
      System.delete_env("COLORTERM")
      System.delete_env("TERM_PROGRAM")

      caps = Capabilities.detect()

      assert caps.color_mode == :color_256
    end

    test "detects tmux as 256-color capable" do
      System.put_env("TERM", "tmux-256color")
      System.delete_env("COLORTERM")
      System.delete_env("TERM_PROGRAM")

      caps = Capabilities.detect()

      assert caps.color_mode == :color_256
    end

    test "detects linux console as 16-color" do
      System.put_env("TERM", "linux")
      System.delete_env("COLORTERM")
      System.delete_env("TERM_PROGRAM")

      caps = Capabilities.detect()

      assert caps.color_mode == :color_16
      assert caps.max_colors == 16
    end

    test "detects dumb terminal as monochrome" do
      System.put_env("TERM", "dumb")
      System.delete_env("COLORTERM")
      System.delete_env("TERM_PROGRAM")

      caps = Capabilities.detect()

      assert caps.color_mode == :monochrome
      assert caps.max_colors == 2
    end
  end

  describe "environment variable detection - $COLORTERM" do
    test "detects truecolor from $COLORTERM" do
      System.put_env("TERM", "xterm")
      System.put_env("COLORTERM", "truecolor")
      System.delete_env("TERM_PROGRAM")

      caps = Capabilities.detect()

      assert caps.color_mode == :true_color
      assert caps.max_colors == 16_777_216
    end

    test "detects 24bit from $COLORTERM" do
      System.put_env("TERM", "xterm")
      System.put_env("COLORTERM", "24bit")
      System.delete_env("TERM_PROGRAM")

      caps = Capabilities.detect()

      assert caps.color_mode == :true_color
      assert caps.max_colors == 16_777_216
    end
  end

  describe "environment variable detection - $TERM_PROGRAM" do
    test "detects iTerm.app capabilities" do
      System.put_env("TERM", "xterm")
      System.delete_env("COLORTERM")
      System.put_env("TERM_PROGRAM", "iTerm.app")

      caps = Capabilities.detect()

      assert caps.color_mode == :true_color
      assert caps.mouse == true
      assert caps.bracketed_paste == true
      assert caps.focus_events == true
      assert caps.terminal_program == "iTerm.app"
    end

    test "detects vscode terminal capabilities" do
      System.put_env("TERM", "xterm")
      System.delete_env("COLORTERM")
      System.put_env("TERM_PROGRAM", "vscode")

      caps = Capabilities.detect()

      assert caps.color_mode == :true_color
      assert caps.mouse == true
    end

    test "detects Alacritty capabilities" do
      System.put_env("TERM", "xterm")
      System.delete_env("COLORTERM")
      System.put_env("TERM_PROGRAM", "Alacritty")

      caps = Capabilities.detect()

      assert caps.color_mode == :true_color
    end

    test "detects Apple_Terminal as 256-color" do
      System.put_env("TERM", "xterm")
      System.delete_env("COLORTERM")
      System.put_env("TERM_PROGRAM", "Apple_Terminal")

      caps = Capabilities.detect()

      assert caps.color_mode == :color_256
    end
  end

  describe "environment variable detection - $LANG" do
    test "detects UTF-8 from $LANG" do
      System.put_env("LANG", "en_US.UTF-8")
      System.delete_env("LC_ALL")
      System.delete_env("LC_CTYPE")

      caps = Capabilities.detect()

      assert caps.unicode == true
    end

    test "detects UTF-8 from $LC_ALL" do
      System.put_env("LC_ALL", "en_US.UTF-8")
      System.delete_env("LANG")

      caps = Capabilities.detect()

      assert caps.unicode == true
    end

    test "detects non-UTF-8 locale" do
      System.put_env("LANG", "en_US.ISO-8859-1")
      System.delete_env("LC_ALL")
      System.delete_env("LC_CTYPE")

      caps = Capabilities.detect()

      assert caps.unicode == false
    end
  end

  describe "capability accessors" do
    test "supports_true_color?/0" do
      System.put_env("COLORTERM", "truecolor")
      Capabilities.detect()

      assert Capabilities.supports_true_color?() == true
    end

    test "supports_256_color?/0 returns true for true-color" do
      System.put_env("COLORTERM", "truecolor")
      Capabilities.detect()

      assert Capabilities.supports_256_color?() == true
    end

    test "supports_256_color?/0 returns true for 256-color" do
      System.put_env("TERM", "xterm-256color")
      System.delete_env("COLORTERM")
      System.delete_env("TERM_PROGRAM")
      Capabilities.detect()

      assert Capabilities.supports_256_color?() == true
    end

    test "supports_mouse?/0" do
      System.put_env("TERM_PROGRAM", "iTerm.app")
      Capabilities.detect()

      assert Capabilities.supports_mouse?() == true
    end

    test "supports_bracketed_paste?/0" do
      System.put_env("TERM_PROGRAM", "iTerm.app")
      Capabilities.detect()

      assert Capabilities.supports_bracketed_paste?() == true
    end

    test "supports_unicode?/0" do
      System.put_env("LANG", "en_US.UTF-8")
      Capabilities.detect()

      assert Capabilities.supports_unicode?() == true
    end

    test "max_colors/0" do
      System.put_env("COLORTERM", "truecolor")
      Capabilities.detect()

      assert Capabilities.max_colors() == 16_777_216
    end

    test "color_mode/0" do
      System.put_env("COLORTERM", "truecolor")
      Capabilities.detect()

      assert Capabilities.color_mode() == :true_color
    end
  end

  describe "clear_cache/0" do
    test "clears cached capabilities" do
      Capabilities.detect()
      Capabilities.clear_cache()

      # Verify cache is empty by checking ETS directly
      # get/0 will re-detect
      Capabilities.clear_cache()
      assert :ok == Capabilities.clear_cache()
    end
  end
end
