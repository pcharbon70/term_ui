defmodule TermUI.PersistentTermsTest do
  use ExUnit.Case, async: false

  alias TermUI.PersistentTerms

  describe "store_backend_context/2" do
    test "stores backend mode" do
      # Clean up before test
      PersistentTerms.cleanup()

      PersistentTerms.store_backend_context(:raw, nil)
      assert PersistentTerms.backend_mode() == :raw

      PersistentTerms.store_backend_context(:tty, %{colors: :true_color})
      assert PersistentTerms.backend_mode() == :tty

      # Clean up after test
      PersistentTerms.cleanup()
    end

    test "stores capabilities" do
      PersistentTerms.cleanup()

      capabilities = %{colors: :true_color, unicode: true, dimensions: {24, 80}}
      PersistentTerms.store_backend_context(:tty, capabilities)

      assert PersistentTerms.capabilities() == capabilities

      PersistentTerms.cleanup()
    end

    test "detects capabilities when backend is :raw" do
      PersistentTerms.cleanup()

      # When raw mode is used, capabilities should still be detected
      PersistentTerms.store_backend_context(:raw, nil)

      caps = PersistentTerms.capabilities()
      assert is_map(caps)
      # Should have detected some capabilities
      assert Map.has_key?(caps, :colors) or Map.has_key?(caps, :unicode)

      PersistentTerms.cleanup()
    end

    test "sets character set based on capabilities" do
      PersistentTerms.cleanup()

      # Unicode supported
      PersistentTerms.store_backend_context(:tty, %{unicode: true})
      assert PersistentTerms.character_set() == :unicode

      # Unicode not supported
      PersistentTerms.store_backend_context(:tty, %{unicode: false})
      assert PersistentTerms.character_set() == :ascii

      # No capabilities info - defaults to unicode
      PersistentTerms.store_backend_context(:tty, nil)
      assert PersistentTerms.character_set() == :unicode

      PersistentTerms.cleanup()
    end
  end

  describe "backend_mode/0" do
    test "returns nil when not set" do
      PersistentTerms.cleanup()
      assert PersistentTerms.backend_mode() == nil
    end

    test "returns stored backend mode" do
      PersistentTerms.cleanup()
      :persistent_term.put(:term_ui_backend_mode, :raw)
      assert PersistentTerms.backend_mode() == :raw
      PersistentTerms.cleanup()
    end
  end

  describe "capabilities/0" do
    test "returns nil when not set" do
      PersistentTerms.cleanup()
      assert PersistentTerms.capabilities() == nil
    end

    test "returns stored capabilities" do
      PersistentTerms.cleanup()
      caps = %{colors: :true_color, unicode: true}
      :persistent_term.put(:term_ui_capabilities, caps)
      assert PersistentTerms.capabilities() == caps
      PersistentTerms.cleanup()
    end
  end

  describe "character_set/0" do
    test "falls back to application config when not set" do
      PersistentTerms.cleanup()

      # Set application config
      Application.put_env(:term_ui, :character_set, :ascii)

      assert PersistentTerms.character_set() == :ascii

      # Clean up
      Application.delete_env(:term_ui, :character_set)
    end

    test "returns stored character set" do
      PersistentTerms.cleanup()
      :persistent_term.put(:term_ui_character_set, :unicode)
      assert PersistentTerms.character_set() == :unicode
      PersistentTerms.cleanup()
    end

    test "defaults to unicode when neither persistent_term nor config is set" do
      PersistentTerms.cleanup()
      Application.delete_env(:term_ui, :character_set)

      assert PersistentTerms.character_set() == :unicode
    end
  end

  describe "cleanup/0" do
    test "removes all persistent terms" do
      # Set up all terms
      :persistent_term.put(:term_ui_backend_mode, :raw)
      :persistent_term.put(:term_ui_capabilities, %{colors: :true_color})
      :persistent_term.put(:term_ui_character_set, :unicode)

      # Verify they're set
      assert :persistent_term.get(:term_ui_backend_mode, :not_set) == :raw
      assert :persistent_term.get(:term_ui_capabilities, :not_set) == %{colors: :true_color}
      assert :persistent_term.get(:term_ui_character_set, :not_set) == :unicode

      # Clean up
      PersistentTerms.cleanup()

      # Verify they're gone (using default to avoid exception)
      assert :persistent_term.get(:term_ui_backend_mode, :gone) == :gone
      assert :persistent_term.get(:term_ui_capabilities, :gone) == :gone
      assert :persistent_term.get(:term_ui_character_set, :gone) == :gone
    end

    test "does not crash when called multiple times" do
      PersistentTerms.cleanup()
      assert :ok = PersistentTerms.cleanup()
      assert :ok = PersistentTerms.cleanup()
    end
  end

  describe "any_terms?/0" do
    test "returns false when no terms are set" do
      PersistentTerms.cleanup()
      refute PersistentTerms.any_terms?()
    end

    test "returns true when any term is set" do
      PersistentTerms.cleanup()

      refute PersistentTerms.any_terms?()

      :persistent_term.put(:term_ui_backend_mode, :raw)
      assert PersistentTerms.any_terms?()

      PersistentTerms.cleanup()
    end

    test "returns false after cleanup" do
      :persistent_term.put(:term_ui_backend_mode, :raw)
      assert PersistentTerms.any_terms?()

      PersistentTerms.cleanup()
      refute PersistentTerms.any_terms?()
    end
  end

  describe "integration with Runtime" do
    test "cleanup is called when Runtime terminates" do
      # Set up terms before starting Runtime
      :persistent_term.put(:term_ui_backend_mode, :raw)
      :persistent_term.put(:term_ui_capabilities, %{colors: :true_color})
      :persistent_term.put(:term_ui_character_set, :unicode)

      # Start a Runtime (with skip_terminal to avoid terminal setup in tests)
      # We don't name it so we can control its lifecycle
      {:ok, pid} =
        TermUI.Runtime.start_link(
          root: TermUI.Test.Components.Counter,
          skip_terminal: true
        )

      # Runtime should have overwritten the terms during init
      assert :persistent_term.get(:term_ui_backend_mode, :not_set) == :skip
      assert PersistentTerms.any_terms?()

      # Monitor the process and stop it
      ref = Process.monitor(pid)
      GenServer.stop(pid)

      # Wait for terminate/2 to complete
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 500

      # Give a small additional delay for cleanup
      Process.sleep(50)

      # Terms should be cleaned up
      refute PersistentTerms.any_terms?()
      assert :persistent_term.get(:term_ui_backend_mode, :gone) == :gone
      assert :persistent_term.get(:term_ui_capabilities, :gone) == :gone
      assert :persistent_term.get(:term_ui_character_set, :gone) == :gone
    end
  end
end
