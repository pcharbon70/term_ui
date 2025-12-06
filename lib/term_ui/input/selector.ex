defmodule TermUI.Input.Selector do
  @moduledoc """
  Selects the appropriate input handler based on the active backend mode.

  This module bridges the gap between backend selection and input handling,
  providing a way to choose the correct input handler for the current
  terminal mode.

  ## Relationship with Backend.Selector

  The `TermUI.Backend.Selector` determines which terminal backend to use
  (Raw or TTY). This module, `TermUI.Input.Selector`, then selects the
  corresponding input handler:

  | Backend Mode | Backend Module | Input Handler |
  |--------------|----------------|---------------|
  | `:raw` | `TermUI.Backend.Raw` | `TermUI.Input.Raw` |
  | `:tty` | `TermUI.Backend.TTY` | `TermUI.Input.TTY` |

  ## Usage

  There are two ways to select an input handler:

  ### Explicit Selection

  When you know which mode you want, use `select/1`:

      # Get the Raw input handler
      handler = TermUI.Input.Selector.select(:raw)
      # => TermUI.Input.Raw

      # Get the TTY input handler
      handler = TermUI.Input.Selector.select(:tty)
      # => TermUI.Input.TTY

  ### Auto-Detection

  When you want to match the current backend, use `select/0`:

      # Automatically select based on current backend
      handler = TermUI.Input.Selector.select()
      # => TermUI.Input.Raw or TermUI.Input.TTY

  ## State-Based Selection

  For runtime code that already has a `Backend.State` struct, you can
  extract the mode and pass it directly:

      backend_state = %TermUI.Backend.State{mode: :tty, ...}
      handler = TermUI.Input.Selector.select(backend_state.mode)

  ## Input Handler Contract

  Both `TermUI.Input.Raw` and `TermUI.Input.TTY` implement the `TermUI.Input`
  behaviour, providing a consistent interface:

  - `new/0` - Create initial handler state
  - `poll/2` - Poll for input with timeout
  - `mode/1` - Return the handler's mode (`:raw` or `:tty`)

  ## Example Integration

      # Typical usage in runtime initialization
      case TermUI.Backend.Selector.select() do
        {:raw, backend_state} ->
          input_handler = TermUI.Input.Selector.select(:raw)
          input_state = input_handler.new()
          # ...

        {:tty, capabilities} ->
          input_handler = TermUI.Input.Selector.select(:tty)
          input_state = input_handler.new()
          # ...
      end

  ## Note on LineReader

  `TermUI.Input.LineReader` is **not** included in the selector. LineReader
  is a specialized module for line-based input (used by `TextInput.Line`)
  and does not implement the `TermUI.Input` behaviour. Use LineReader
  directly when you need line-based input with shell editing.
  """

  @typedoc """
  Valid input mode atoms.

  - `:raw` - Select `TermUI.Input.Raw` for raw mode input
  - `:tty` - Select `TermUI.Input.TTY` for TTY mode input
  """
  @type mode :: :raw | :tty

  @typedoc """
  Input handler module that implements the `TermUI.Input` behaviour.
  """
  @type handler :: module()

  @doc """
  Selects the appropriate input handler based on the current backend mode.

  This function auto-detects the current backend mode by attempting to
  determine whether raw mode is active. If detection cannot determine
  the mode, it defaults to TTY mode as the safer fallback.

  ## Returns

  - `TermUI.Input.Raw` if raw mode is active
  - `TermUI.Input.TTY` if TTY mode is active or mode cannot be determined

  ## Examples

      handler = TermUI.Input.Selector.select()
      state = handler.new()
      {result, state} = handler.poll(state, 100)

  ## Implementation Note

  This function uses `TermUI.Backend.Selector.select/0` to determine the
  current mode. This means it will attempt raw mode detection each time
  it's called. For performance, prefer using `select/1` with an explicit
  mode when the mode is already known from backend initialization.
  """
  @spec select() :: handler()
  def select do
    case TermUI.Backend.Selector.select() do
      {:raw, _state} -> TermUI.Input.Raw
      {:tty, _capabilities} -> TermUI.Input.TTY
    end
  end

  @doc """
  Selects the input handler for the specified mode.

  This function provides explicit selection when the mode is already known,
  avoiding the overhead of backend detection.

  ## Arguments

  - `mode` - The input mode: `:raw` or `:tty`

  ## Returns

  - `TermUI.Input.Raw` for `:raw` mode
  - `TermUI.Input.TTY` for `:tty` mode

  ## Raises

  - `ArgumentError` if an invalid mode is provided

  ## Examples

      # Select Raw input handler
      handler = TermUI.Input.Selector.select(:raw)
      # => TermUI.Input.Raw

      # Select TTY input handler
      handler = TermUI.Input.Selector.select(:tty)
      # => TermUI.Input.TTY

      # Using with Backend.State
      backend_state = %TermUI.Backend.State{mode: :tty, ...}
      handler = TermUI.Input.Selector.select(backend_state.mode)

      # Invalid mode raises
      TermUI.Input.Selector.select(:invalid)
      # ** (ArgumentError) invalid input mode: :invalid, expected :raw or :tty
  """
  @spec select(mode()) :: handler()
  def select(:raw), do: TermUI.Input.Raw
  def select(:tty), do: TermUI.Input.TTY

  def select(mode) do
    raise ArgumentError, "invalid input mode: #{inspect(mode)}, expected :raw or :tty"
  end
end
