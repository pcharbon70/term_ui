defmodule TermUI.Backend.ConfigTest do
  use ExUnit.Case, async: false

  alias TermUI.Backend.Config

  # Note: async: false because we modify Application env

  setup do
    # Store original values
    original_backend = Application.get_env(:term_ui, :backend)
    original_character_set = Application.get_env(:term_ui, :character_set)
    original_fallback = Application.get_env(:term_ui, :fallback_character_set)
    original_tty_opts = Application.get_env(:term_ui, :tty_opts)
    original_raw_opts = Application.get_env(:term_ui, :raw_opts)

    on_exit(fn ->
      # Restore original values
      restore_env(:backend, original_backend)
      restore_env(:character_set, original_character_set)
      restore_env(:fallback_character_set, original_fallback)
      restore_env(:tty_opts, original_tty_opts)
      restore_env(:raw_opts, original_raw_opts)
    end)

    # Clear all config for clean test state
    Application.delete_env(:term_ui, :backend)
    Application.delete_env(:term_ui, :character_set)
    Application.delete_env(:term_ui, :fallback_character_set)
    Application.delete_env(:term_ui, :tty_opts)
    Application.delete_env(:term_ui, :raw_opts)

    :ok
  end

  defp restore_env(key, nil), do: Application.delete_env(:term_ui, key)
  defp restore_env(key, value), do: Application.put_env(:term_ui, key, value)

  describe "module structure" do
    test "module compiles successfully" do
      assert Code.ensure_loaded?(Config)
    end

    test "exports expected functions" do
      assert function_exported?(Config, :get_backend, 0)
      assert function_exported?(Config, :get_character_set, 0)
      assert function_exported?(Config, :get_fallback_character_set, 0)
      assert function_exported?(Config, :get_tty_opts, 0)
      assert function_exported?(Config, :get_raw_opts, 0)
    end
  end

  describe "get_backend/0" do
    test "returns :auto when no config present" do
      assert Config.get_backend() == :auto
    end

    test "returns :auto when explicitly configured" do
      Application.put_env(:term_ui, :backend, :auto)
      assert Config.get_backend() == :auto
    end

    test "returns configured module when set to Raw backend" do
      Application.put_env(:term_ui, :backend, TermUI.Backend.Raw)
      assert Config.get_backend() == TermUI.Backend.Raw
    end

    test "returns configured module when set to TTY backend" do
      Application.put_env(:term_ui, :backend, TermUI.Backend.TTY)
      assert Config.get_backend() == TermUI.Backend.TTY
    end

    test "returns configured module when set to Test backend" do
      Application.put_env(:term_ui, :backend, TermUI.Backend.Test)
      assert Config.get_backend() == TermUI.Backend.Test
    end

    test "returns any configured atom value" do
      Application.put_env(:term_ui, :backend, SomeCustomBackend)
      assert Config.get_backend() == SomeCustomBackend
    end
  end

  describe "get_character_set/0" do
    test "returns :unicode when no config present" do
      assert Config.get_character_set() == :unicode
    end

    test "returns :unicode when explicitly configured" do
      Application.put_env(:term_ui, :character_set, :unicode)
      assert Config.get_character_set() == :unicode
    end

    test "returns :ascii when configured" do
      Application.put_env(:term_ui, :character_set, :ascii)
      assert Config.get_character_set() == :ascii
    end
  end

  describe "get_fallback_character_set/0" do
    test "returns :ascii when no config present" do
      assert Config.get_fallback_character_set() == :ascii
    end

    test "returns :ascii when explicitly configured" do
      Application.put_env(:term_ui, :fallback_character_set, :ascii)
      assert Config.get_fallback_character_set() == :ascii
    end

    test "returns :unicode when configured" do
      Application.put_env(:term_ui, :fallback_character_set, :unicode)
      assert Config.get_fallback_character_set() == :unicode
    end
  end

  describe "get_tty_opts/0" do
    test "returns [line_mode: :full_redraw] when no config present" do
      assert Config.get_tty_opts() == [line_mode: :full_redraw]
    end

    test "returns configured keyword list" do
      Application.put_env(:term_ui, :tty_opts, line_mode: :incremental)
      assert Config.get_tty_opts() == [line_mode: :incremental]
    end

    test "returns custom options" do
      opts = [line_mode: :full_redraw, custom_option: :value]
      Application.put_env(:term_ui, :tty_opts, opts)
      assert Config.get_tty_opts() == opts
    end

    test "returns empty list when configured as empty" do
      Application.put_env(:term_ui, :tty_opts, [])
      assert Config.get_tty_opts() == []
    end
  end

  describe "get_raw_opts/0" do
    test "returns [alternate_screen: true] when no config present" do
      assert Config.get_raw_opts() == [alternate_screen: true]
    end

    test "returns configured keyword list with alternate_screen: false" do
      Application.put_env(:term_ui, :raw_opts, alternate_screen: false)
      assert Config.get_raw_opts() == [alternate_screen: false]
    end

    test "returns custom options" do
      opts = [alternate_screen: true, mouse: :sgr]
      Application.put_env(:term_ui, :raw_opts, opts)
      assert Config.get_raw_opts() == opts
    end

    test "returns empty list when configured as empty" do
      Application.put_env(:term_ui, :raw_opts, [])
      assert Config.get_raw_opts() == []
    end
  end

  describe "documentation" do
    test "module has moduledoc" do
      {:docs_v1, _, :elixir, _, module_doc, _, _} = Code.fetch_docs(Config)
      assert module_doc != :none
      assert module_doc != :hidden
    end

    test "get_backend/0 has docs" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(Config)

      func_docs =
        docs
        |> Enum.filter(fn
          {{:function, :get_backend, 0}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(func_docs) == 1
    end

    test "get_character_set/0 has docs" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(Config)

      func_docs =
        docs
        |> Enum.filter(fn
          {{:function, :get_character_set, 0}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(func_docs) == 1
    end

    test "get_fallback_character_set/0 has docs" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(Config)

      func_docs =
        docs
        |> Enum.filter(fn
          {{:function, :get_fallback_character_set, 0}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(func_docs) == 1
    end

    test "get_tty_opts/0 has docs" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(Config)

      func_docs =
        docs
        |> Enum.filter(fn
          {{:function, :get_tty_opts, 0}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(func_docs) == 1
    end

    test "get_raw_opts/0 has docs" do
      {:docs_v1, _, :elixir, _, _, _, docs} = Code.fetch_docs(Config)

      func_docs =
        docs
        |> Enum.filter(fn
          {{:function, :get_raw_opts, 0}, _, _, _, _} -> true
          _ -> false
        end)

      assert length(func_docs) == 1
    end
  end

  describe "typical usage patterns" do
    test "all defaults work together" do
      assert Config.get_backend() == :auto
      assert Config.get_character_set() == :unicode
      assert Config.get_fallback_character_set() == :ascii
      assert Config.get_tty_opts() == [line_mode: :full_redraw]
      assert Config.get_raw_opts() == [alternate_screen: true]
    end

    test "full configuration example" do
      # Simulate a full config.exs setup
      Application.put_env(:term_ui, :backend, TermUI.Backend.Raw)
      Application.put_env(:term_ui, :character_set, :ascii)
      Application.put_env(:term_ui, :fallback_character_set, :ascii)
      Application.put_env(:term_ui, :tty_opts, line_mode: :incremental)
      Application.put_env(:term_ui, :raw_opts, alternate_screen: false)

      assert Config.get_backend() == TermUI.Backend.Raw
      assert Config.get_character_set() == :ascii
      assert Config.get_fallback_character_set() == :ascii
      assert Config.get_tty_opts() == [line_mode: :incremental]
      assert Config.get_raw_opts() == [alternate_screen: false]
    end
  end
end
