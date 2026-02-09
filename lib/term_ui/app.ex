defmodule TermUI.App do
  @moduledoc """
  High-level application API for TermUI applications.

  This module provides a convenient API for starting and running TermUI
  applications with automatic backend selection (raw mode or TTY mode).

  ## Application Lifecycle

  TermUI applications follow The Elm Architecture:
  1. Model (state) - Application state
  2. View - Renders UI based on state
  3. Update - Handles events, returns new state
  4. Messages - Events that trigger updates

  ## Backend Selection

  The API automatically selects the appropriate backend:
  - **Raw mode**: Full terminal control (mouse, colors, Unicode) - OTP 28+
  - **TTY mode**: Line-based input with graceful degradation

  ## IEx Compatibility

  TermUI applications work directly in IEx with no code changes. This enables:
  - Interactive debugging and development
  - Admin tools and dashboards in production IEx sessions
  - Prototyping and testing TUI interfaces

  ### Running in IEx

  Start any TermUI application from an IEx session:

      iex> TermUI.App.run(MyApp.Counter)
      # Use keyboard input, press Q to quit
      # Returns to IEx prompt when done

  All keyboard input works correctly in IEx:
  - Arrow keys for navigation (no Enter required)
  - Tab for field switching
  - Function keys (F1-F12)
  - Ctrl+key combinations
  - Alt+key combinations

  ### IEx Detection

  Detect if your application is running in IEx:

      iex> TermUI.iex_mode?()
      true

      iex> TermUI.running_mode()
      :iex

  ### Configuration

  Force IEx-compatible mode via configuration:

      # config/config.exs
      config :term_ui,
        iex_compatible: true

  Or via environment variable:

      export TERM_UI_IEX_MODE=true

  ### Troubleshooting IEx Issues

  **Input not reaching the application:**
  - Ensure the application is started from IEx (not `mix run`)
  - Check that `TermUI.iex_mode?()` returns `true`
  - Try forcing IEx mode with `TERM_UI_IEX_MODE=true`

  **Terminal state not restored after exit:**
  - The Runtime should restore terminal state automatically
  - If problems persist, call `TermUI.shutdown()` manually

  **Performance issues in IEx:**
  - IEx adds some overhead due to process inspection
  - Use `backend: :raw` for better performance (when OTP 28+ is available)

  ## Usage

  ### Non-blocking start (for supervisors)

      {:ok, pid} = TermUI.App.start(MyApp.Root, backend: :auto)

  ### Blocking run (for scripts and CLI apps)

      final_state = TermUI.App.run(MyApp.Root, backend: :auto)

  ### Query backend capabilities

      :raw = TermUI.App.backend_mode()
      true = TermUI.App.supports?(:unicode)
      true = TermUI.App.supports?(:mouse)

  ### Shutdown

      :ok = TermUI.App.shutdown()

  ## Configuration Options

  - `:backend` - Backend selection: `:auto` (default), `:raw`, `:tty`
  - `:name` - GenServer name for the Runtime process
  - `:render_interval` - Milliseconds between renders (default: 16, ~60 FPS)

  ## Example

      defmodule MyApp.Counter do
        @moduledoc \"\"\"
        A simple counter application.
        \"\"\"

        @impl true
        def init(_opts) do
          {:ok, %{count: 0}}
        end

        @impl true
        def view(model) do
          [
            {:text, "Count: \" <> to_string(model.count)},
            {:text, "\\nPress + to increment, - to decrement, q to quit"}
          ]
        end

        @impl true
        def update(msg, model) do
          case msg do
            {:key, ?+} -> {:ok, %{model | count: model.count + 1}}
            {:key, ?-} -> {:ok, %{model | count: model.count - 1}}
            {:key, ?q} -> {:quit, model}
            _ -> {:ok, model}
          end
        end
      end

      # Run the application
      TermUI.App.run(MyApp.Counter, backend: :auto)

  ## Component Protocol

  Your root component must implement the following callbacks:

  - `init/1` - Initialize the model, called once at startup
  - `view/1` - Render the UI based on current model
  - `update/2` - Handle messages, return `{:ok, new_model}` or `{:quit, model}`

  See `TermUI.Component` for full protocol documentation.
  """

  alias TermUI.PersistentTerms
  alias TermUI.Runtime

  @type root_module :: module()
  @type option ::
          {:backend, :auto | :raw | :tty}
          | {:name, GenServer.name()}
          | {:render_interval, pos_integer()}
          | {:skip_terminal, boolean()}
          | {:use_input_handler, boolean() | :auto}
  @type supports_query ::
          :unicode
          | :mouse
          | :colors
          | :true_color
          | :color_256
          | :color_16
          | :monochrome

  @doc """
  Starts a TermUI application non-blocking.

  Returns `{:ok, pid}` where pid is the Runtime process.
  Use this when you want to manage the process yourself
  (e.g., in a supervisor tree).

  ## Options

  - `:backend` - Backend selection: `:auto` (default), `:raw`, `:tty`
  - `:name` - GenServer name for the Runtime process
  - `:render_interval` - Milliseconds between renders (default: 16)

  ## Examples

      {:ok, pid} = TermUI.App.start(MyApp.Root)

      {:ok, pid} = TermUI.App.start(MyApp.Root, backend: :tty)

      # With a named process
      {:ok, _pid} = TermUI.App.start(MyApp.Root, name: :my_app)

  """
  @spec start(root_module(), [option()]) :: {:ok, pid()} | {:error, term()}
  def start(root_module, opts \\ []) do
    Runtime.start_link(runtime_options(root_module, opts))
  end

  @doc false
  @spec runtime_options(root_module(), [option()]) :: keyword()
  def runtime_options(root_module, opts \\ []) do
    [
      {:root, root_module}
      | Keyword.take(opts, [:name, :backend, :render_interval, :skip_terminal, :use_input_handler])
    ]
  end

  @doc """
  Runs a TermUI application blocking until completion.

  This is the simplest way to run a TermUI application.
  It starts the runtime, waits for the application to exit,
  cleans up terminal state, and returns the final result.

  Returns `{:ok, final_model}` on successful completion or
  `{:error, reason}` if the application crashes.

  ## Options

  - `:backend` - Backend selection: `:auto` (default), `:raw`, `:tty`
  - `:render_interval` - Milliseconds between renders (default: 16)

  ## Examples

      {:ok, final_state} = TermUI.App.run(MyApp.Root)

      {:ok, final_state} = TermUI.App.run(MyApp.Root, backend: :tty)

  ## Exit Conditions

  The application exits when:
  - The root component returns `{:quit, model}` from update/2
  - The Runtime process crashes (returns error)
  - User interrupts with Ctrl+C (handled by Runtime)

  """
  @spec run(root_module(), [option()]) :: {:ok, term()} | {:error, term()}
  def run(root_module, opts \\ []) do
    # Start the runtime
    case start(root_module, opts) do
      {:ok, pid} ->
        # Monitor and wait for exit
        ref = Process.monitor(pid)

        receive do
          {:DOWN, ^ref, :process, ^pid, :normal} ->
            {:ok, :exited_normally}

          {:DOWN, ^ref, :process, ^pid, reason} ->
            # Ensure terminal cleanup even on crash
            _ = ensure_terminal_cleanup()
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns the current backend mode.

  Possible values:
  - `:raw` - Full terminal control (OTP 28+)
  - `:tty` - Line-based input (fallback)
  - `:nil` - No app running or backend not initialized

  ## Examples

      case TermUI.App.backend_mode() do
        :raw -> IO.puts("Running in raw mode - full features available")
        :tty -> IO.puts("Running in TTY mode - limited features")
        nil -> IO.puts("No app running")
      end

  """
  @spec backend_mode() :: :raw | :tty | nil
  def backend_mode, do: PersistentTerms.backend_mode()

  @doc """
  Checks if a capability is supported by the current terminal.

  Supported queries:
  - `:unicode` - Unicode character support (box drawing, etc.)
  - `:mouse` - Mouse event support
  - `:colors` - Any color support (not monochrome)
  - `:true_color` - 24-bit RGB color support
  - `:color_256` - 256-color palette support
  - `:color_16` - 16-color palette support
  - `:monochrome` - No color support

  Returns `true` if the capability is supported, `false` otherwise.
  Returns `false` if no app is running.

  ## Examples

      if TermUI.App.supports?(:unicode) do
        # Use Unicode box drawing characters
      else
        # Fall back to ASCII
      end

      if TermUI.App.supports?(:true_color) do
        # Use RGB colors for smooth gradients
      elsif TermUI.App.supports?(:color_256) do
        # Use 256-color palette
      else
        # Use basic 16 colors
      end

  """
  @spec supports?(supports_query()) :: boolean()
  def supports?(query) do
    capabilities = PersistentTerms.capabilities() || %{}
    check_capability(query, capabilities)
  end

  defp check_capability(:unicode, caps), do: Map.get(caps, :unicode, true)
  defp check_capability(:mouse, caps), do: Map.get(caps, :mouse, false)
  defp check_capability(:colors, caps), do: Map.get(caps, :colors, :true_color) != :monochrome
  defp check_capability(:true_color, caps), do: Map.get(caps, :colors, :true_color) == :true_color

  defp check_capability(:color_256, caps),
    do: Map.get(caps, :colors, :true_color) in [:color_256, :true_color]

  defp check_capability(:color_16, caps),
    do: Map.get(caps, :colors, :true_color) in [:color_16, :color_256, :true_color]

  defp check_capability(:monochrome, caps), do: Map.get(caps, :colors, :true_color) == :monochrome
  defp check_capability(_, _caps), do: false

  @doc """
  Shuts down a running TermUI application.

  If a named Runtime process was started with `name: :my_app`,
  you can shut it down by passing the name. Otherwise, this
  function attempts to find and shut down the Runtime process.

  ## Examples

      # Shutdown by finding the process
      :ok = TermUI.App.shutdown()

      # Shutdown by name
      :ok = TermUI.App.shutdown(:my_app)

  """
  @spec shutdown(GenServer.name() | pid()) :: :ok | {:error, term()}
  def shutdown(name_or_pid \\ nil)

  def shutdown(nil) do
    # Try to find a running Runtime process
    case Process.whereis(TermUI.Runtime) do
      nil -> {:error, :not_found}
      pid -> shutdown(pid)
    end
  end

  def shutdown(name) when is_atom(name) do
    case Process.whereis(name) do
      nil -> {:error, :not_found}
      pid -> Runtime.shutdown(pid)
    end
  end

  def shutdown(pid) when is_pid(pid) do
    Runtime.shutdown(pid)
  end

  # Private helper to ensure terminal cleanup on crash.
  # Uses direct /dev/tty write to bypass the Erlang IO system which may
  # be in an inconsistent state after a crash.
  defp ensure_terminal_cleanup do
    TermUI.TerminalOutput.write_to_tty(TermUI.TerminalOutput.cleanup_sequence())
    :ok
  rescue
    _ -> :error
  end
end
