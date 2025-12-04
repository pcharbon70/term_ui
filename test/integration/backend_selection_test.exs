defmodule TermUI.Integration.BackendSelectionTest do
  @moduledoc """
  Integration tests for Phase 1 backend selection flow.

  These tests verify that the Config, Selector, and State modules work together
  correctly to provide a complete backend selection flow.
  """

  use ExUnit.Case, async: false

  alias TermUI.Backend.Config
  alias TermUI.Backend.Selector
  alias TermUI.Backend.State

  # Note: async: false because we modify Application env and system environment

  setup do
    # Store original Application env values
    original_backend = Application.get_env(:term_ui, :backend)
    original_character_set = Application.get_env(:term_ui, :character_set)
    original_fallback = Application.get_env(:term_ui, :fallback_character_set)
    original_tty_opts = Application.get_env(:term_ui, :tty_opts)
    original_raw_opts = Application.get_env(:term_ui, :raw_opts)

    # Store original environment variables
    original_colorterm = System.get_env("COLORTERM")
    original_term = System.get_env("TERM")
    original_lang = System.get_env("LANG")

    on_exit(fn ->
      # Restore Application env
      restore_app_env(:backend, original_backend)
      restore_app_env(:character_set, original_character_set)
      restore_app_env(:fallback_character_set, original_fallback)
      restore_app_env(:tty_opts, original_tty_opts)
      restore_app_env(:raw_opts, original_raw_opts)

      # Restore environment variables
      restore_sys_env("COLORTERM", original_colorterm)
      restore_sys_env("TERM", original_term)
      restore_sys_env("LANG", original_lang)
    end)

    # Clear Application env for clean test state
    Application.delete_env(:term_ui, :backend)
    Application.delete_env(:term_ui, :character_set)
    Application.delete_env(:term_ui, :fallback_character_set)
    Application.delete_env(:term_ui, :tty_opts)
    Application.delete_env(:term_ui, :raw_opts)

    :ok
  end

  defp restore_app_env(key, nil), do: Application.delete_env(:term_ui, key)
  defp restore_app_env(key, value), do: Application.put_env(:term_ui, key, value)

  defp restore_sys_env(key, nil), do: System.delete_env(key)
  defp restore_sys_env(key, value), do: System.put_env(key, value)

  # ===========================================================================
  # Task 1.5.1: Backend Selection Flow Tests
  # ===========================================================================

  describe "backend selection flow (Task 1.5.1)" do
    test "configuration with :auto backend triggers selector" do
      # 1.5.1.1 - Config :auto should result in selector being used
      Application.put_env(:term_ui, :backend, :auto)

      # Verify config returns :auto
      assert Config.get_backend() == :auto

      # When config is :auto, selector should be invoked
      # In test environment, this will return {:tty, capabilities}
      # because we can't start raw mode in a running shell
      result = Selector.select(:auto)

      # Result should be either {:raw, _} or {:tty, _}
      assert match?({:raw, _}, result) or match?({:tty, _}, result)
    end

    test "selector result provides correct backend module and init options" do
      # 1.5.1.2 - Selector returns usable data for backend initialization
      case Selector.select() do
        {:raw, state} ->
          # Raw mode returns state with raw_mode_started flag
          assert is_map(state)
          assert Map.has_key?(state, :raw_mode_started)
          assert state.raw_mode_started == true

        {:tty, capabilities} ->
          # TTY mode returns capabilities map
          assert is_map(capabilities)
          assert Map.has_key?(capabilities, :colors)
          assert Map.has_key?(capabilities, :unicode)
          assert Map.has_key?(capabilities, :dimensions)
          assert Map.has_key?(capabilities, :terminal)
      end
    end

    test "explicit backend configuration bypasses selector" do
      # 1.5.1.3 - Explicit module config bypasses auto-detection
      Application.put_env(:term_ui, :backend, TermUI.Backend.TTY)

      # Config returns the explicit module
      assert Config.get_backend() == TermUI.Backend.TTY

      # Using select/1 with explicit module returns {:explicit, module, opts}
      assert {:explicit, TermUI.Backend.TTY, []} = Selector.select(TermUI.Backend.TTY)
    end

    test "explicit backend with options bypasses selector" do
      # 1.5.1.3 continued - Explicit module with options
      result = Selector.select({TermUI.Backend.TTY, line_mode: :incremental})

      assert {:explicit, TermUI.Backend.TTY, [line_mode: :incremental]} = result
    end

    test "invalid configuration is caught before selector runs" do
      # 1.5.1.4 - Invalid config raises before selection
      Application.put_env(:term_ui, :backend, :invalid_backend)

      # validate! raises for invalid backend
      assert_raise ArgumentError, ~r/invalid :backend value/, fn ->
        Config.validate!()
      end

      # valid? returns false
      assert Config.valid?() == false
    end

    test "configuration validation runs before runtime_config returns" do
      # 1.5.1.4 continued - runtime_config validates before returning
      Application.put_env(:term_ui, :character_set, :invalid)

      assert_raise ArgumentError, ~r/invalid :character_set value/, fn ->
        Config.runtime_config()
      end
    end
  end

  # ===========================================================================
  # Task 1.5.2: Capability Integration Tests
  # ===========================================================================

  describe "capability integration (Task 1.5.2)" do
    test "TTY capability detection produces compatible capability format" do
      # 1.5.2.1 - Capabilities have expected structure
      capabilities = Selector.detect_capabilities()

      # Verify structure matches expected format
      assert is_map(capabilities)
      assert Map.has_key?(capabilities, :colors)
      assert Map.has_key?(capabilities, :unicode)
      assert Map.has_key?(capabilities, :dimensions)
      assert Map.has_key?(capabilities, :terminal)

      # Verify value types
      assert capabilities.colors in [:true_color, :color_256, :color_16, :monochrome]
      assert is_boolean(capabilities.unicode)
      assert capabilities.dimensions == nil or match?({_, _}, capabilities.dimensions)
      assert is_boolean(capabilities.terminal)
    end

    test "capability map can be passed to State.new_tty" do
      # 1.5.2.2 - Capabilities are usable for backend init
      capabilities = Selector.detect_capabilities()

      # Should successfully create state with detected capabilities
      state = State.new_tty(capabilities)

      assert state.mode == :tty
      assert state.backend_module == TermUI.Backend.TTY
      assert state.capabilities == capabilities
    end

    test "environment variable changes affect color depth detection" do
      # 1.5.2.3 - Environment changes are reflected in capability detection

      # Test true color detection via COLORTERM
      System.put_env("COLORTERM", "truecolor")
      caps = Selector.detect_capabilities()
      assert caps.colors == :true_color

      System.put_env("COLORTERM", "24bit")
      caps = Selector.detect_capabilities()
      assert caps.colors == :true_color

      # Test 256 color detection via TERM
      System.delete_env("COLORTERM")
      System.put_env("TERM", "xterm-256color")
      caps = Selector.detect_capabilities()
      assert caps.colors == :color_256

      # Test 16 color detection via TERM
      System.put_env("TERM", "xterm")
      caps = Selector.detect_capabilities()
      assert caps.colors == :color_16

      # Test monochrome fallback
      System.put_env("TERM", "")
      caps = Selector.detect_capabilities()
      assert caps.colors == :monochrome
    end

    test "environment variable changes affect unicode detection" do
      # 1.5.2.3 continued - LANG affects unicode detection
      System.put_env("LANG", "en_US.UTF-8")
      caps = Selector.detect_capabilities()
      assert caps.unicode == true

      System.put_env("LANG", "C")
      caps = Selector.detect_capabilities()
      assert caps.unicode == false

      System.put_env("LANG", "ja_JP.utf8")
      caps = Selector.detect_capabilities()
      assert caps.unicode == true
    end

    test "capabilities flow from selector to state" do
      # Verify complete flow: selector -> capabilities -> state
      case Selector.select() do
        {:tty, capabilities} ->
          state = State.new_tty(capabilities)
          assert state.capabilities == capabilities
          assert state.mode == :tty

        {:raw, raw_state} ->
          state = State.new_raw(raw_state)
          assert state.backend_state == raw_state
          assert state.mode == :raw
      end
    end
  end

  # ===========================================================================
  # Task 1.5.3: State Management Tests
  # ===========================================================================

  describe "state management integration (Task 1.5.3)" do
    test "Backend.State correctly wraps raw selector result" do
      # 1.5.3.1 - State wraps raw mode result correctly
      raw_state = %{raw_mode_started: true}
      state = State.new_raw(raw_state)

      assert state.backend_module == TermUI.Backend.Raw
      assert state.backend_state == raw_state
      assert state.mode == :raw
      assert state.capabilities == %{}
      assert state.initialized == false
    end

    test "Backend.State correctly wraps tty selector result" do
      # 1.5.3.1 continued - State wraps TTY mode result correctly
      capabilities = %{
        colors: :true_color,
        unicode: true,
        dimensions: {24, 80},
        terminal: true
      }

      state = State.new_tty(capabilities)

      assert state.backend_module == TermUI.Backend.TTY
      assert state.backend_state == nil
      assert state.mode == :tty
      assert state.capabilities == capabilities
      assert state.initialized == false
    end

    test "state updates preserve backend-specific state" do
      # 1.5.3.2 - Updates preserve existing fields
      initial_backend_state = %{cursor: {1, 1}, buffer: []}
      state = State.new_raw(initial_backend_state)

      # Update size should preserve backend_state
      state = State.put_size(state, {24, 80})
      assert state.backend_state == initial_backend_state
      assert state.size == {24, 80}

      # Update capabilities should preserve backend_state
      state = State.put_capabilities(state, %{colors: :true_color})
      assert state.backend_state == initial_backend_state
      assert state.capabilities == %{colors: :true_color}

      # Mark initialized should preserve all state
      state = State.mark_initialized(state)
      assert state.backend_state == initial_backend_state
      assert state.size == {24, 80}
      assert state.capabilities == %{colors: :true_color}
      assert state.initialized == true
    end

    test "state updates to backend_state work correctly" do
      # 1.5.3.2 continued - Backend state can be updated
      state = State.new_raw(%{initial: true})

      new_backend_state = %{cursor: {5, 10}, screen_cleared: true}
      state = State.put_backend_state(state, new_backend_state)

      assert state.backend_state == new_backend_state
      assert state.mode == :raw
      assert state.backend_module == TermUI.Backend.Raw
    end

    test "mode field correctly reflects raw selection result" do
      # 1.5.3.3 - Mode is :raw for raw mode state
      state = State.new_raw()
      assert state.mode == :raw

      state = State.new_raw(%{raw_mode_started: true})
      assert state.mode == :raw
    end

    test "mode field correctly reflects tty selection result" do
      # 1.5.3.3 continued - Mode is :tty for TTY mode state
      state = State.new_tty(%{colors: :color_256})
      assert state.mode == :tty

      state = State.new_tty(%{}, %{some: :state})
      assert state.mode == :tty
    end

    test "complete selection to state workflow" do
      # Full integration: config -> selector -> state -> updates
      Application.put_env(:term_ui, :backend, :auto)

      # Validate configuration
      assert Config.valid?() == true
      config = Config.runtime_config()
      assert config.backend == :auto

      # Perform selection based on config
      selection_result =
        case config.backend do
          :auto -> Selector.select()
          module -> Selector.select(module)
        end

      # Wrap result in state
      state =
        case selection_result do
          {:raw, raw_state} ->
            State.new_raw(raw_state)

          {:tty, capabilities} ->
            State.new_tty(capabilities)

          {:explicit, _module, _opts} ->
            # For explicit selection, create appropriate state
            State.new_tty(%{})
        end

      # Apply updates
      state = State.put_size(state, {30, 120})
      state = State.mark_initialized(state)

      # Verify final state
      assert state.size == {30, 120}
      assert state.initialized == true
      assert state.mode in [:raw, :tty]
    end
  end

  # ===========================================================================
  # Additional Integration Tests
  # ===========================================================================

  describe "configuration and state integration" do
    test "runtime_config values match individual getters" do
      Application.put_env(:term_ui, :backend, TermUI.Backend.TTY)
      Application.put_env(:term_ui, :character_set, :ascii)
      Application.put_env(:term_ui, :tty_opts, line_mode: :incremental)

      config = Config.runtime_config()

      assert config.backend == Config.get_backend()
      assert config.character_set == Config.get_character_set()
      assert config.fallback_character_set == Config.get_fallback_character_set()
      assert config.tty_opts == Config.get_tty_opts()
      assert config.raw_opts == Config.get_raw_opts()
    end

    test "State.new with explicit module and mode" do
      # Test the general constructor with different backends
      state = State.new(TermUI.Backend.Test, mode: :tty, capabilities: %{test: true})

      assert state.backend_module == TermUI.Backend.Test
      assert state.mode == :tty
      assert state.capabilities == %{test: true}
    end

    test "full lifecycle: config validation -> selection -> state creation" do
      # Set up valid configuration
      Application.put_env(:term_ui, :backend, :auto)
      Application.put_env(:term_ui, :character_set, :unicode)
      Application.put_env(:term_ui, :tty_opts, line_mode: :full_redraw)
      Application.put_env(:term_ui, :raw_opts, alternate_screen: true)

      # Step 1: Validate configuration
      assert :ok = Config.validate!()
      config = Config.runtime_config()

      # Step 2: Select backend
      result = Selector.select(config.backend)

      # Step 3: Create state based on selection
      state =
        case result do
          {:raw, raw_state} ->
            State.new_raw(raw_state)

          {:tty, capabilities} ->
            State.new_tty(capabilities)

          {:explicit, module, _opts} ->
            State.new(module, mode: :tty)
        end

      # Step 4: Initialize state
      state = State.mark_initialized(state)

      # Verify the complete flow worked
      assert state.initialized == true
      assert state.backend_module in [TermUI.Backend.Raw, TermUI.Backend.TTY, TermUI.Backend.Test]
    end
  end
end
