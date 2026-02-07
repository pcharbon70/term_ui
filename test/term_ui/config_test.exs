defmodule TermUI.ConfigTest do
  use ExUnit.Case, async: true

  alias TermUI.Config

  # Clean up application environment between tests
  setup do
    # Store original values
    original_backend = Application.get_env(:term_ui, :backend)
    original_color_mode = Application.get_env(:term_ui, :color_mode)
    original_character_set = Application.get_env(:term_ui, :character_set)
    original_render_interval = Application.get_env(:term_ui, :render_interval)

    on_exit(fn ->
      # Restore original values or erase
      if original_backend do
        Application.put_env(:term_ui, :backend, original_backend)
      else
        Application.delete_env(:term_ui, :backend)
      end

      if original_color_mode do
        Application.put_env(:term_ui, :color_mode, original_color_mode)
      else
        Application.delete_env(:term_ui, :color_mode)
      end

      if original_character_set do
        Application.put_env(:term_ui, :character_set, original_character_set)
      else
        Application.delete_env(:term_ui, :character_set)
      end

      if original_render_interval do
        Application.put_env(:term_ui, :render_interval, original_render_interval)
      else
        Application.delete_env(:term_ui, :render_interval)
      end
    end)

    :ok
  end

  describe "get/2" do
    test "returns default for backend when not configured" do
      Application.delete_env(:term_ui, :backend)
      assert Config.get(:backend) == :auto
    end

    test "returns default for color_mode when not configured" do
      Application.delete_env(:term_ui, :color_mode)
      assert Config.get(:color_mode) == :auto
    end

    test "returns default for character_set when not configured" do
      Application.delete_env(:term_ui, :character_set)
      assert Config.get(:character_set) == :auto
    end

    test "returns default for render_interval when not configured" do
      Application.delete_env(:term_ui, :render_interval)
      assert Config.get(:render_interval) == 16
    end

    test "returns configured value for backend" do
      Application.put_env(:term_ui, :backend, :raw)
      assert Config.get(:backend) == :raw
    end

    test "returns configured value for color_mode" do
      Application.put_env(:term_ui, :color_mode, :true_color)
      assert Config.get(:color_mode) == :true_color
    end

    test "returns configured value for character_set" do
      Application.put_env(:term_ui, :character_set, :ascii)
      assert Config.get(:character_set) == :ascii
    end

    test "returns configured value for render_interval" do
      Application.put_env(:term_ui, :render_interval, 33)
      assert Config.get(:render_interval) == 33
    end

    test "returns custom default when provided" do
      Application.delete_env(:term_ui, :backend)
      assert Config.get(:backend, :custom) == :custom
    end

    test "custom default is not used when value is configured" do
      Application.put_env(:term_ui, :backend, :tty)
      assert Config.get(:backend, :custom) == :tty
    end

    test "returns any key from application env" do
      Application.put_env(:term_ui, :custom_key, :custom_value)
      assert Config.get(:custom_key) == :custom_value
    end
  end

  describe "all/0" do
    test "returns all configuration values as keyword list" do
      Application.put_env(:term_ui, :backend, :tty)
      Application.put_env(:term_ui, :color_mode, :color_256)
      Application.put_env(:term_ui, :character_set, :ascii)
      Application.put_env(:term_ui, :render_interval, 60)

      all = Config.all()

      assert all[:backend] == :tty
      assert all[:color_mode] == :color_256
      assert all[:character_set] == :ascii
      assert all[:render_interval] == 60
    end

    test "returns defaults when nothing configured" do
      Application.delete_env(:term_ui, :backend)
      Application.delete_env(:term_ui, :color_mode)
      Application.delete_env(:term_ui, :character_set)
      Application.delete_env(:term_ui, :render_interval)

      all = Config.all()

      assert all[:backend] == :auto
      assert all[:color_mode] == :auto
      assert all[:character_set] == :auto
      assert all[:render_interval] == 16
    end

    test "contains all expected keys" do
      all = Config.all()

      keys = Keyword.keys(all)
      assert :backend in keys
      assert :color_mode in keys
      assert :character_set in keys
      assert :render_interval in keys
    end
  end

  describe "merge_options/2" do
    test "returns defaults when no config and no options" do
      Application.delete_env(:term_ui, :backend)
      Application.delete_env(:term_ui, :color_mode)

      merged = Config.merge_options([])

      assert merged[:backend] == :auto
      assert merged[:color_mode] == :auto
    end

    test "config values are used when no runtime option provided" do
      Application.put_env(:term_ui, :backend, :tty)
      Application.put_env(:term_ui, :render_interval, 60)

      merged = Config.merge_options([])

      assert merged[:backend] == :tty
      assert merged[:render_interval] == 60
    end

    test "runtime options override config values" do
      Application.put_env(:term_ui, :backend, :tty)

      merged = Config.merge_options(backend: :raw)

      assert merged[:backend] == :raw
    end

    test "runtime options override for multiple keys" do
      Application.put_env(:term_ui, :backend, :tty)
      Application.put_env(:term_ui, :render_interval, 60)

      merged = Config.merge_options(backend: :raw, render_interval: 33)

      assert merged[:backend] == :raw
      assert merged[:render_interval] == 33
    end

    test "runtime options and config can coexist" do
      Application.put_env(:term_ui, :backend, :tty)
      # render_interval not configured

      merged = Config.merge_options(backend: :raw, render_interval: 33)

      # Runtime override
      assert merged[:backend] == :raw
      # Runtime option
      assert merged[:render_interval] == 33
      # Default
      assert merged[:color_mode] == :auto
    end

    test "arbitrary options are passed through" do
      merged = Config.merge_options(custom_key: :custom_value)

      assert merged[:custom_key] == :custom_value
    end

    test "does not modify original options list" do
      Application.put_env(:term_ui, :backend, :tty)
      original_opts = [backend: :raw]

      merged = Config.merge_options(original_opts)

      # Should use runtime option
      assert merged[:backend] == :raw
      # Original unchanged
      assert original_opts[:backend] == :raw
    end

    test "handles nil values in config" do
      Application.put_env(:term_ui, :backend, nil)

      merged = Config.merge_options([])

      # nil in config should be treated as "not set", so default applies
      assert merged[:backend] == nil
    end

    test "skip_terminal option is preserved" do
      merged = Config.merge_options(skip_terminal: true)

      assert merged[:skip_terminal] == true
    end

    test "use_input_handler option is preserved" do
      merged = Config.merge_options(use_input_handler: true)

      assert merged[:use_input_handler] == true
    end
  end

  describe "defaults/0" do
    test "returns default options without reading config" do
      Application.put_env(:term_ui, :backend, :tty)
      Application.put_env(:term_ui, :render_interval, 60)

      defaults = Config.defaults()

      # Defaults should ignore application config
      assert defaults[:backend] == :auto
      assert defaults[:render_interval] == 16
      assert defaults[:color_mode] == :auto
      assert defaults[:character_set] == :auto
    end

    test "contains all expected default keys" do
      defaults = Config.defaults()

      keys = Keyword.keys(defaults)
      assert :backend in keys
      assert :color_mode in keys
      assert :character_set in keys
      assert :render_interval in keys
    end
  end
end
