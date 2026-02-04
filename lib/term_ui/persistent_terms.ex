defmodule TermUI.PersistentTerms do
  @moduledoc """
  Centralized management of persistent_term storage for TermUI.

  TermUI uses `:persistent_term` for fast global access to runtime configuration
  like backend mode, capabilities, and character set. This module provides a
  single interface for managing the lifecycle of these terms.

  ## Persistent Term Keys

  The following keys are used by TermUI:

  - `:term_ui_backend_mode` - Current backend mode (:raw, :tty, or nil)
  - `:term_ui_capabilities` - Detected terminal capabilities map
  - `term_ui_character_set` - Character set (:unicode or :ascii)

  BufferManager also uses persistent terms with its own name prefix:
  - `{TermUI.Renderer.BufferManager, name, :current}` - Current buffer reference
  - `{TermUI.Renderer.BufferManager, name, :previous}` - Previous buffer reference
  - `{TermUI.Renderer.BufferManager, name, :dirty}` - Dirty flag atomic

  ## Cleanup

  Always call `cleanup/0` when shutting down a TermUI application to prevent
  memory leaks from orphaned persistent terms.

  ## Usage

      # Store backend context
      PersistentTerms.store_backend_context(:raw, capabilities)

      # Query backend mode
      :raw = PersistentTerms.backend_mode()

      # Clean up on shutdown
      PersistentTerms.cleanup()
  """

  alias TermUI.Backend.Selector
  require Logger

  @doc """
  Stores backend context in persistent_term.

  This is called by Runtime during initialization to make backend information
  globally available to components that need to query capabilities.

  ## Parameters

  - `backend_mode` - The backend mode (:raw, :tty, etc.)
  - `capabilities` - The detected capabilities map
  """
  @spec store_backend_context(:raw | :tty | nil, map() | nil) :: :ok
  def store_backend_context(backend_mode, capabilities) do
    :persistent_term.put(:term_ui_backend_mode, backend_mode)

    caps_to_store =
      if backend_mode == :raw do
        # Detect capabilities even in raw mode for consistency
        detect_capabilities()
      else
        capabilities
      end

    :persistent_term.put(:term_ui_capabilities, caps_to_store)

    # Determine and store character set (:unicode or :ascii)
    charset = determine_character_set(caps_to_store)
    :persistent_term.put(:term_ui_character_set, charset)

    # Log capabilities at debug level
    log_capabilities(caps_to_store, charset)

    :ok
  end

  @doc """
  Gets the current backend mode from persistent_term.

  Returns `:raw`, `:tty`, or `nil` if not set.
  """
  @spec backend_mode() :: :raw | :tty | nil
  def backend_mode do
    :persistent_term.get(:term_ui_backend_mode, nil)
  end

  @doc """
  Gets the detected terminal capabilities from persistent_term.

  Returns a map with keys like `:colors`, `:unicode`, `:dimensions`, `:terminal`
  or `nil` if not set.
  """
  @spec capabilities() :: map() | nil
  def capabilities do
    :persistent_term.get(:term_ui_capabilities, nil)
  end

  @doc """
  Gets the current character set from persistent_term.

  Returns `:unicode` or `:ascii`.
  """
  @spec character_set() :: :unicode | :ascii
  def character_set do
    case :persistent_term.get(:term_ui_character_set, :fallback) do
      :fallback ->
        # Fall back to application config
        Application.get_env(:term_ui, :character_set, :unicode)

      charset ->
        charset
    end
  end

  @doc """
  Cleans up all TermUI persistent terms.

  This should be called during graceful shutdown to prevent memory leaks.
  BufferManager persistent terms are handled by BufferManager itself.

  ## Examples

      TermUI.PersistentTerms.cleanup()
  """
  @spec cleanup() :: :ok
  def cleanup do
    # Erase all TermUI global persistent terms
    :persistent_term.erase(:term_ui_backend_mode)
    :persistent_term.erase(:term_ui_capabilities)
    :persistent_term.erase(:term_ui_character_set)

    :ok
  end

  @doc """
  Checks if any TermUI persistent terms are currently set.

  Useful for testing and debugging to ensure cleanup is working.

  ## Examples

      iex> TermUI.PersistentTerms.any_terms?()
      false
  """
  @spec any_terms?() :: boolean()
  def any_terms? do
    :persistent_term.get(:term_ui_backend_mode, :not_set) != :not_set or
      :persistent_term.get(:term_ui_capabilities, :not_set) != :not_set or
      :persistent_term.get(:term_ui_character_set, :not_set) != :not_set
  end

  # Private Functions

  defp detect_capabilities do
    # Defer to Backend.Selector for capability detection
    case Selector.detect_capabilities() do
      caps when is_map(caps) -> caps
      _ -> %{}
    end
  rescue
    _ -> %{}
  end

  defp determine_character_set(capabilities) when is_map(capabilities) do
    case Map.get(capabilities, :unicode, true) do
      true -> :unicode
      false -> :ascii
      _ -> :unicode
    end
  end

  defp determine_character_set(_capabilities), do: :unicode

  # No-op - capabilities logging removed for cleaner console output
  defp log_capabilities(_capabilities, _charset), do: :ok
end
