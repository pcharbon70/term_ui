defmodule TermUI.Backend.State do
  @moduledoc """
  Shared state structure for terminal backends.

  The State module provides a consistent wrapper around backend-specific state,
  enabling uniform state management across different backend implementations
  (Raw and TTY modes).

  ## Purpose

  When the backend selector determines which mode to use, it returns initialization
  data that gets wrapped in this state struct. This provides:

  - **Consistent interface**: All backends expose the same state structure
  - **Mode tracking**: Easy identification of current terminal mode
  - **Capability access**: Unified access to detected terminal capabilities
  - **Size caching**: Cached terminal dimensions to avoid repeated queries
  - **Lifecycle tracking**: Initialization status for proper cleanup

  ## Usage

  State structs are typically created by the runtime initialization code after
  backend selection:

      case Selector.select() do
        {:raw, raw_state} ->
          %State{
            backend_module: TermUI.Backend.Raw,
            backend_state: raw_state,
            mode: :raw,
            capabilities: %{},
            initialized: false
          }

        {:tty, capabilities} ->
          %State{
            backend_module: TermUI.Backend.TTY,
            backend_state: nil,
            mode: :tty,
            capabilities: capabilities,
            initialized: false
          }
      end

  ## Fields

  - `:backend_module` - The backend implementation module (required)
  - `:backend_state` - Backend-specific internal state
  - `:mode` - Current terminal mode, `:raw` or `:tty` (required)
  - `:capabilities` - Map of detected terminal capabilities
  - `:size` - Cached terminal dimensions as `{rows, cols}` or `nil`
  - `:initialized` - Whether the backend has been fully initialized

  ## State Updates

  State structs are immutable. Updates create new structs:

      state = %State{backend_module: MyBackend, mode: :tty}
      updated = %{state | initialized: true}

  For convenience functions to update state, see tasks 1.3.2 and 1.3.3.
  """

  @typedoc """
  Terminal mode indicating which backend type is active.
  """
  @type mode :: :raw | :tty

  @typedoc """
  Cached terminal dimensions as `{rows, cols}`.
  """
  @type dimensions :: {pos_integer(), pos_integer()} | nil

  @typedoc """
  The backend state struct.

  Contains all metadata needed to manage a terminal backend instance.
  """
  @type t :: %__MODULE__{
          backend_module: module(),
          backend_state: term(),
          mode: mode(),
          capabilities: map(),
          size: dimensions(),
          initialized: boolean()
        }

  @enforce_keys [:backend_module, :mode]
  defstruct [
    :backend_module,
    :backend_state,
    :mode,
    capabilities: %{},
    size: nil,
    initialized: false
  ]
end
