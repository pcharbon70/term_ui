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

  ## Constructors

  Instead of creating structs directly, use the constructor functions:

      # General constructor with explicit backend module
      State.new(MyBackend, mode: :tty, capabilities: %{colors: :true_color})

      # Convenience constructor for raw mode
      State.new_raw()
      State.new_raw(%{raw_mode_started: true})

      # Convenience constructor for TTY mode
      State.new_tty(%{colors: :color_256, unicode: true})

  ## State Updates

  State structs are immutable. Use update functions for convenience:

      state = State.new_tty(%{colors: :true_color})
      state = State.put_size(state, {24, 80})
      state = State.mark_initialized(state)
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

  @doc """
  Creates a new backend state with the given module and options.

  ## Arguments

  - `backend_module` - The backend implementation module
  - `opts` - Keyword list of options:
    - `:mode` - Required. The terminal mode (`:raw` or `:tty`)
    - `:backend_state` - Optional. Backend-specific internal state
    - `:capabilities` - Optional. Map of terminal capabilities (default: `%{}`)
    - `:size` - Optional. Cached dimensions as `{rows, cols}` (default: `nil`)
    - `:initialized` - Optional. Initialization status (default: `false`)

  ## Examples

      iex> State.new(MyBackend, mode: :tty)
      %State{backend_module: MyBackend, mode: :tty, ...}

      iex> State.new(MyBackend, mode: :tty, capabilities: %{colors: :true_color})
      %State{backend_module: MyBackend, mode: :tty, capabilities: %{colors: :true_color}, ...}

  ## Raises

  - `ArgumentError` if `:mode` is not provided in options
  """
  @spec new(module(), keyword()) :: t()
  def new(backend_module, opts \\ []) do
    unless Keyword.has_key?(opts, :mode) do
      raise ArgumentError, "the :mode option is required"
    end

    struct!(__MODULE__, [{:backend_module, backend_module} | opts])
  end

  @doc """
  Creates a new raw mode backend state.

  This is a convenience function that sets:
  - `backend_module` to `TermUI.Backend.Raw`
  - `mode` to `:raw`
  - `capabilities` to `%{}`

  ## Arguments

  - `backend_state` - Optional. Backend-specific internal state (default: `nil`)

  ## Examples

      iex> State.new_raw()
      %State{backend_module: TermUI.Backend.Raw, mode: :raw, ...}

      iex> State.new_raw(%{raw_mode_started: true})
      %State{backend_module: TermUI.Backend.Raw, mode: :raw, backend_state: %{raw_mode_started: true}, ...}
  """
  @spec new_raw(term()) :: t()
  def new_raw(backend_state \\ nil) do
    %__MODULE__{
      backend_module: TermUI.Backend.Raw,
      backend_state: backend_state,
      mode: :raw,
      capabilities: %{},
      size: nil,
      initialized: false
    }
  end

  @doc """
  Creates a new TTY mode backend state with the given capabilities.

  This is a convenience function that sets:
  - `backend_module` to `TermUI.Backend.TTY`
  - `mode` to `:tty`

  ## Arguments

  - `capabilities` - Map of detected terminal capabilities
  - `backend_state` - Optional. Backend-specific internal state (default: `nil`)

  ## Examples

      iex> State.new_tty(%{colors: :color_256, unicode: true})
      %State{backend_module: TermUI.Backend.TTY, mode: :tty, capabilities: %{colors: :color_256, unicode: true}, ...}

      iex> State.new_tty(%{colors: :true_color}, %{some: :state})
      %State{backend_module: TermUI.Backend.TTY, mode: :tty, capabilities: %{colors: :true_color}, backend_state: %{some: :state}, ...}
  """
  @spec new_tty(map(), term()) :: t()
  def new_tty(capabilities, backend_state \\ nil) when is_map(capabilities) do
    %__MODULE__{
      backend_module: TermUI.Backend.TTY,
      backend_state: backend_state,
      mode: :tty,
      capabilities: capabilities,
      size: nil,
      initialized: false
    }
  end

  # ============================================================================
  # Update Functions
  # ============================================================================

  @doc """
  Updates the backend-specific state.

  ## Arguments

  - `state` - The current state struct
  - `backend_state` - The new backend-specific state value

  ## Examples

      iex> state = State.new_raw()
      iex> state = State.put_backend_state(state, %{cursor: {1, 1}})
      iex> state.backend_state
      %{cursor: {1, 1}}
  """
  @spec put_backend_state(t(), term()) :: t()
  def put_backend_state(%__MODULE__{} = state, backend_state) do
    %{state | backend_state: backend_state}
  end

  @doc """
  Updates the cached terminal dimensions.

  ## Arguments

  - `state` - The current state struct
  - `size` - The new size as `{rows, cols}` tuple or `nil`

  ## Examples

      iex> state = State.new_tty(%{})
      iex> state = State.put_size(state, {24, 80})
      iex> state.size
      {24, 80}

      iex> state = State.put_size(state, nil)
      iex> state.size
      nil
  """
  @spec put_size(t(), dimensions()) :: t()
  def put_size(%__MODULE__{} = state, size) do
    %{state | size: size}
  end

  @doc """
  Updates the capabilities map.

  Note: This replaces the entire capabilities map, it does not merge.

  ## Arguments

  - `state` - The current state struct
  - `capabilities` - The new capabilities map

  ## Examples

      iex> state = State.new_tty(%{colors: :basic})
      iex> state = State.put_capabilities(state, %{colors: :true_color, unicode: true})
      iex> state.capabilities
      %{colors: :true_color, unicode: true}
  """
  @spec put_capabilities(t(), map()) :: t()
  def put_capabilities(%__MODULE__{} = state, capabilities) when is_map(capabilities) do
    %{state | capabilities: capabilities}
  end

  @doc """
  Marks the state as initialized.

  This function is idempotent - calling it on an already initialized state
  has no effect.

  ## Arguments

  - `state` - The current state struct

  ## Examples

      iex> state = State.new_tty(%{})
      iex> state.initialized
      false
      iex> state = State.mark_initialized(state)
      iex> state.initialized
      true
  """
  @spec mark_initialized(t()) :: t()
  def mark_initialized(%__MODULE__{} = state) do
    %{state | initialized: true}
  end
end
