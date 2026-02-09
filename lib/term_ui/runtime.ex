defmodule TermUI.Runtime do
  @moduledoc """
  The central runtime orchestrator for TermUI applications.

  The runtime implements The Elm Architecture dispatch loop:
  1. Receive event from terminal
  2. Route to appropriate component
  3. Call component's event_to_msg
  4. Call component's update with message
  5. Collect commands from update
  6. Mark component dirty
  7. On render timer, call view and render

  ## Usage

      # Start with a root component
      {:ok, runtime} = Runtime.start_link(root: MyApp.Root)

      # Send events (usually from terminal input)
      Runtime.send_event(runtime, Event.key(:enter))

      # Shutdown gracefully
      Runtime.shutdown(runtime)
  """

  use GenServer
  require Logger

  alias TermUI.Backend.Selector
  alias TermUI.Command
  alias TermUI.Command.Executor, as: CommandExecutor
  alias TermUI.Config
  alias TermUI.Elm
  alias TermUI.Event
  alias TermUI.EventQueue
  alias TermUI.Input.Selector, as: InputSelector
  alias TermUI.MessageQueue
  alias TermUI.PersistentTerms
  alias TermUI.Renderer.Buffer
  alias TermUI.Renderer.BufferManager
  alias TermUI.Renderer.Cell
  alias TermUI.Runtime.NodeRenderer
  alias TermUI.Runtime.State
  alias TermUI.Terminal
  alias TermUI.Terminal.InputReader

  @type option ::
          {:root, module()}
          | {:name, GenServer.name()}
          | {:render_interval, pos_integer()}
          | {:backend, :auto | :raw | :tty}
          | {:skip_terminal, boolean()}
          | {:use_input_handler, boolean() | :auto}

  @type use_input_handler_opt :: boolean() | :auto
  @type input_strategy :: :input_handler | :legacy_reader | :none

  # Default render interval in milliseconds (~60 FPS)
  @default_render_interval 16

  # Input polling interval (same as render interval)
  @input_poll_interval 16

  # --- Public API ---

  @doc """
  Starts the runtime with the given options.

  ## Options

  - `:root` - The root component module (required)
  - `:name` - GenServer name (optional)
  - `:render_interval` - Milliseconds between renders (default: 16)
  - `:backend` - Backend selection: `:auto` (default), `:raw`, `:tty`
  - `:skip_terminal` - Skip terminal initialization (default: false, for testing)

  ## Backend Selection

  The `:backend` option controls which terminal backend is used:

  - `:auto` (default) - Attempts raw mode first, falls back to TTY if unavailable
  - `:raw` - Forces raw mode (requires OTP 28+, errors if unavailable)
  - `:tty` - Forces TTY mode (line-based input, no raw mode attempt)

  ## Examples

      # Auto-detect backend (default behavior)
      {:ok, runtime} = Runtime.start_link(root: MyApp.Root)

      # Force TTY mode
      {:ok, runtime} = Runtime.start_link(root: MyApp.Root, backend: :tty)

      # Query backend mode at runtime
      :raw = Runtime.backend_mode()

      # Query capabilities (useful for TTY mode)
      %{colors: :true_color, unicode: true} = Runtime.capabilities()
  """
  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    if name do
      GenServer.start_link(__MODULE__, opts, name: name)
    else
      GenServer.start_link(__MODULE__, opts)
    end
  end

  @doc """
  Returns a child specification for starting the runtime in a supervisor.

  ## Options

  Same as `start_link/1`:
  - `:root` - The root component module (required)
  - `:name` - GenServer name (optional)
  - `:render_interval` - Milliseconds between renders (default: 16)
  - `:backend` - Backend selection: `:auto`, `:raw`, `:tty`
  - `:skip_terminal` - Skip terminal initialization (default: false)

  ## Examples

      children = [
        {TermUI.Runtime, root: MyApp.Root, name: :my_runtime}
      ]

      Supervisor.start_link(children, strategy: :one_for_one)
  """
  @spec child_spec([option()]) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    }
  end

  @doc """
  Sends an event to the runtime for processing.
  """
  @spec send_event(GenServer.server(), Event.t()) :: :ok
  def send_event(runtime, event) do
    GenServer.cast(runtime, {:event, event})
  end

  @doc """
  Sends a message directly to a component.
  """
  @spec send_message(GenServer.server(), term(), term()) :: :ok
  def send_message(runtime, component_id, message) do
    GenServer.cast(runtime, {:message, component_id, message})
  end

  @doc """
  Delivers a command result back to the runtime.
  """
  @spec command_result(GenServer.server(), term(), term(), term()) :: :ok
  def command_result(runtime, component_id, command_id, result) do
    GenServer.cast(runtime, {:command_result, component_id, command_id, result})
  end

  @doc """
  Initiates graceful shutdown of the runtime.
  """
  @spec shutdown(GenServer.server()) :: :ok
  def shutdown(runtime) do
    GenServer.cast(runtime, :shutdown)
  end

  @doc """
  Gets the current runtime state (for testing/debugging).
  """
  @spec get_state(GenServer.server()) :: State.t()
  def get_state(runtime) do
    GenServer.call(runtime, :get_state)
  end

  @doc """
  Synchronously waits for all pending events and messages to be processed.

  This is primarily useful for testing to avoid race conditions from
  Process.sleep. It processes all queued messages and returns when complete.

  ## Example

      Runtime.send_event(runtime, Event.key(:up))
      Runtime.send_event(runtime, Event.key(:up))
      Runtime.sync(runtime)  # Wait for both events to be processed
      state = Runtime.get_state(runtime)
      assert state.root_state.count == 2
  """
  @spec sync(GenServer.server(), timeout()) :: :ok
  def sync(runtime, timeout \\ 5000) do
    GenServer.call(runtime, :sync, timeout)
  end

  @doc """
  Gets the current backend mode.

  Returns `:raw` if raw mode is active, `:tty` if TTY mode is active,
  or `nil` if no runtime has been started.

  ## Examples

      :raw = Runtime.backend_mode()
      :tty = Runtime.backend_mode()
  """
  @spec backend_mode() :: State.backend_mode()
  def backend_mode, do: PersistentTerms.backend_mode()

  @doc """
  Gets the detected terminal capabilities.

  Returns a map with keys:
  - `:colors` - Color depth (`:true_color`, `:color_256`, `:color_16`, `:monochrome`)
  - `:unicode` - Boolean indicating Unicode support
  - `:dimensions` - `{rows, cols}` tuple or `nil`
  - `:terminal` - Boolean indicating terminal presence

  Returns `nil` if no runtime has been started.

  ## Examples

      %{colors: :true_color, unicode: true} = Runtime.capabilities()
  """
  @spec capabilities() :: State.capabilities() | nil
  def capabilities, do: PersistentTerms.capabilities()

  @doc """
  Forces an immediate render (bypassing framerate limiter).
  """
  @spec force_render(GenServer.server()) :: :ok
  def force_render(runtime) do
    GenServer.cast(runtime, :force_render)
  end

  @doc """
  Starts the runtime and blocks until it shuts down.

  This is the main entry point for running a TUI application. It starts the
  runtime, takes over the terminal, and blocks the calling process until
  the application exits (e.g., user presses quit key).

  ## Options

  Same as `start_link/1`.

  ## Example

      # In your application entry point:
      TermUI.Runtime.run(root: MyApp.Root)
      # This blocks until the app exits
  """
  @spec run([option()]) :: :ok | {:error, term()}
  def run(opts) do
    case start_link(opts) do
      {:ok, runtime} ->
        # Monitor the runtime process and block until it exits
        ref = Process.monitor(runtime)

        receive do
          {:DOWN, ^ref, :process, ^runtime, _reason} ->
            :ok
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    opts = Config.merge_options(opts)
    init_config = parse_init_options(opts)

    logger_handler_config =
      if init_config.skip_terminal, do: nil, else: suppress_logger()

    backend_result = init_backend(init_config)

    PersistentTerms.store_backend_context(
      backend_result.backend_mode,
      backend_result.capabilities
    )

    root_state = init_config.root_module.init(opts)

    input_strategy =
      resolve_input_strategy(
        init_config.use_input_handler,
        backend_result.backend_mode,
        backend_result.terminal_started
      )

    {input_handler, input_state} = init_input_handler(input_strategy, backend_result.backend_mode)
    input_reader = init_legacy_input_reader(input_strategy)

    maybe_register_resize_callback(input_strategy, backend_result.backend_mode)

    {:ok, command_executor} = CommandExecutor.start_link()

    state =
      build_init_state(
        init_config,
        backend_result,
        root_state,
        input_handler,
        input_state,
        input_reader,
        command_executor,
        logger_handler_config
      )

    log_backend_selection(backend_result.backend_mode)
    schedule_render(init_config.render_interval)
    maybe_schedule_input_poll(input_handler)

    {:ok, state}
  end

  defp parse_init_options(opts) do
    %{
      root_module: Keyword.fetch!(opts, :root),
      render_interval: Keyword.get(opts, :render_interval, @default_render_interval),
      skip_terminal: Keyword.get(opts, :skip_terminal, false),
      backend_opt: Keyword.get(opts, :backend, :auto),
      use_input_handler:
        opts
        |> Keyword.get(:use_input_handler, :auto)
        |> normalize_use_input_handler_opt()
    }
  end

  defp normalize_use_input_handler_opt(value) when value in [true, false, :auto], do: value
  defp normalize_use_input_handler_opt(_), do: :auto

  # Removes the :default Logger handler to prevent console output from corrupting
  # the TUI display. Logger messages contain \n which in raw mode (no OPOST)
  # causes staircase rendering. The handler config is saved for restoration at
  # terminate and backed up in persistent_term for crash safety.
  @doc false
  @spec suppress_logger() :: map() | nil
  def suppress_logger do
    case :logger.get_handler_config(:default) do
      {:ok, config} ->
        :persistent_term.put(:term_ui_logger_handler_config, config)
        :logger.remove_handler(:default)
        config

      {:error, _} ->
        # Handler already removed (e.g. test environment)
        nil
    end
  end

  # Restores the :default Logger handler from saved config.
  # Handles double-restore gracefully (idempotent).
  @doc false
  @spec restore_logger(map() | nil) :: :ok
  def restore_logger(nil), do: :ok

  def restore_logger(config) do
    module = Map.fetch!(config, :module)
    handler_config = Map.drop(config, [:id, :module])

    case :logger.add_handler(:default, module, handler_config) do
      :ok -> :ok
      {:error, {:already_exist, _}} -> :ok
      {:error, _reason} -> :ok
    end
  end

  defp init_backend(%{skip_terminal: true}) do
    %{
      backend_mode: :skip,
      backend: nil,
      backend_state: nil,
      capabilities: nil,
      terminal_started: false,
      buffer_manager: nil,
      dimensions: nil
    }
  end

  defp init_backend(%{backend_opt: backend_opt}) do
    {backend_mode, backend, backend_state, capabilities, terminal_started, buffer_manager,
     dimensions} = select_backend(backend_opt)

    %{
      backend_mode: backend_mode,
      backend: backend,
      backend_state: backend_state,
      capabilities: capabilities,
      terminal_started: terminal_started,
      buffer_manager: buffer_manager,
      dimensions: dimensions
    }
  end

  @doc false
  @spec resolve_input_strategy(use_input_handler_opt(), State.backend_mode(), boolean()) ::
          input_strategy()
  def resolve_input_strategy(:auto, :raw, true), do: :legacy_reader
  def resolve_input_strategy(:auto, :tty, _terminal_started), do: :input_handler

  def resolve_input_strategy(:auto, _backend_mode, _terminal_started), do: :none

  def resolve_input_strategy(true, :raw, true), do: :legacy_reader
  def resolve_input_strategy(true, :tty, _terminal_started), do: :input_handler

  def resolve_input_strategy(true, _backend_mode, terminal_started) do
    if terminal_started, do: :legacy_reader, else: :none
  end

  def resolve_input_strategy(false, _backend_mode, true), do: :legacy_reader
  def resolve_input_strategy(false, _backend_mode, _terminal_started), do: :none

  defp init_input_handler(:input_handler, backend_mode) when backend_mode in [:raw, :tty] do
    handler = InputSelector.select(backend_mode)
    {handler, handler.new()}
  end

  defp init_input_handler(_strategy, _backend_mode), do: {nil, nil}

  defp init_legacy_input_reader(:legacy_reader) do
    {:ok, reader_pid} = InputReader.start_link(target: self())

    if Process.whereis(Terminal) do
      Terminal.register_resize_callback(self())
    end

    reader_pid
  end

  defp init_legacy_input_reader(_strategy), do: nil

  defp maybe_register_resize_callback(:input_handler, backend_mode)
       when backend_mode in [:raw, :tty] do
    if Process.whereis(Terminal), do: Terminal.register_resize_callback(self())
  end

  defp maybe_register_resize_callback(_strategy, _backend_mode), do: :ok

  defp build_init_state(
         init_config,
         backend_result,
         root_state,
         input_handler,
         input_state,
         input_reader,
         command_executor,
         logger_handler_config
       ) do
    %State{
      root_module: init_config.root_module,
      root_state: root_state,
      message_queue: MessageQueue.new(),
      event_queue: EventQueue.new(),
      render_interval: init_config.render_interval,
      dirty: true,
      focused_component: :root,
      components: %{root: %{module: init_config.root_module, state: root_state}},
      command_executor: command_executor,
      pending_commands: %{},
      shutting_down: false,
      terminal_started: backend_result.terminal_started,
      buffer_manager: backend_result.buffer_manager,
      dimensions: backend_result.dimensions,
      input_reader: input_reader,
      backend_mode: backend_result.backend_mode,
      backend: backend_result.backend,
      backend_state: backend_result.backend_state,
      capabilities: backend_result.capabilities,
      input_handler: input_handler,
      input_state: input_state,
      logger_handler_config: logger_handler_config
    }
  end

  defp log_backend_selection(:skip), do: :ok

  defp log_backend_selection(backend_mode) do
    require Logger
    mode_str = if TermUI.iex_mode?(), do: "IEx", else: "standalone"
    Logger.info("TermUI.Runtime started with #{backend_mode} backend (#{mode_str} mode)")
  end

  defp maybe_schedule_input_poll(nil), do: :ok
  defp maybe_schedule_input_poll(_handler), do: schedule_input_poll()

  defp select_backend(backend_opt) do
    case Selector.select(backend_opt) do
      {:raw, raw_state} ->
        select_raw_backend_with_fallback(raw_state)

      {:tty, capabilities} ->
        init_tty_backend(capabilities)

      {:explicit, :raw, _opts} ->
        select_explicit_raw_backend()

      {:explicit, :tty, _opts} ->
        init_tty_backend(Selector.detect_capabilities())

      {:explicit, TermUI.Backend.Raw, _opts} ->
        select_explicit_raw_backend()

      {:explicit, TermUI.Backend.TTY, _opts} ->
        init_tty_backend(Selector.detect_capabilities())
    end
  end

  defp select_raw_backend_with_fallback(raw_state) do
    raw_mode_already_started = raw_mode_started_by_selector?(raw_state)

    case setup_terminal_and_buffers(raw_mode_already_started) do
      {true, buffer_manager, dimensions} ->
        init_raw_backend(buffer_manager, dimensions)

      {false, nil, nil} ->
        recover_after_raw_setup_failure(raw_mode_already_started)
        init_tty_backend(Selector.detect_capabilities())
    end
  end

  defp select_explicit_raw_backend do
    case setup_terminal_and_buffers(false) do
      {true, buffer_manager, dimensions} ->
        init_raw_backend(buffer_manager, dimensions)

      {false, nil, nil} ->
        recover_after_raw_setup_failure(true)
        raise "Raw backend requested but unavailable"
    end
  end

  defp raw_mode_started_by_selector?(%{raw_mode_started: raw_mode_started}) do
    raw_mode_started == true
  end

  defp init_raw_backend(buffer_manager, dimensions) do
    backend = TermUI.Backend.Raw

    # Enable ONLCR translation: in OTP 28 raw mode, prim_tty bypasses kernel
    # OPOST so bare \n is LF-only (no CR). This safety net translates \n → \r\n
    # at the TerminalOutput chokepoint, matching the ncurses approach.
    # Required on ALL platforms including WSL (empirically verified).
    TermUI.TerminalOutput.enable_onlcr()

    {:ok, backend_state} =
      backend.init(
        alternate_screen: true,
        hide_cursor: true,
        mouse_tracking: :all,
        size: dimensions
      )

    {:raw, backend, backend_state, nil, true, buffer_manager, dimensions}
  end

  defp init_tty_backend(capabilities) do
    backend = TermUI.Backend.TTY
    {:ok, backend_state} = backend.init(capabilities: capabilities)
    {:tty, backend, backend_state, capabilities, false, nil, nil}
  end

  defp setup_terminal_and_buffers(raw_mode_already_started) do
    # Enable raw mode first
    with {:ok, _terminal_pid} <- ensure_terminal_started(),
         :ok <- ensure_raw_mode(raw_mode_already_started, Terminal),
         {rows, cols} <- get_terminal_dimensions_safe(),
         {:ok, buffer_pid} <- BufferManager.start_link(rows: rows, cols: cols) do
      {true, buffer_pid, normalize_terminal_dimensions(rows, cols)}
    else
      {:error, {:already_started, buffer_pid}} ->
        # BufferManager already started, use it
        {rows, cols} = get_terminal_dimensions_safe()
        {true, buffer_pid, normalize_terminal_dimensions(rows, cols)}

      {:error, _reason} ->
        {false, nil, nil}

      _ ->
        {false, nil, nil}
    end
  rescue
    _ -> {false, nil, nil}
  end

  @doc false
  @spec ensure_raw_mode(boolean(), module()) :: :ok | {:error, term()}
  def ensure_raw_mode(true, terminal_module) do
    # Even though Selector already called :shell.start_interactive({:noshell, :raw}),
    # we must still call enable_raw_mode to apply stty settings (-echo, -opost, etc.)
    # that are not set by :shell.start_interactive alone.
    case terminal_module.enable_raw_mode() do
      {:ok, _state} -> :ok
      # Non-fatal: Selector already activated raw mode at the Erlang level
      {:error, _reason} -> :ok
    end
  end

  def ensure_raw_mode(false, terminal_module) do
    case terminal_module.enable_raw_mode() do
      {:ok, _state} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc false
  @spec recover_after_raw_setup_failure(boolean(), module()) :: :ok
  def recover_after_raw_setup_failure(raw_mode_attempted, terminal_module \\ Terminal)

  def recover_after_raw_setup_failure(false, _terminal_module), do: :ok

  def recover_after_raw_setup_failure(true, terminal_module) do
    _ = safe_restore_terminal(terminal_module)
    :ok
  end

  defp safe_restore_terminal(terminal_module) do
    if function_exported?(terminal_module, :restore, 0) do
      terminal_module.restore()
    else
      :ok
    end
  rescue
    _ -> :ok
  catch
    _, _ -> :ok
  end

  defp ensure_terminal_started do
    case Terminal.start_link() do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:ok, pid}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_terminal_dimensions_safe do
    case Terminal.get_terminal_size() do
      {:ok, {rows, cols}} -> {rows, cols}
      {:error, _reason} -> {24, 80}
    end
  end

  @doc false
  @spec normalize_terminal_dimensions(pos_integer(), pos_integer()) ::
          {pos_integer(), pos_integer()}
  def normalize_terminal_dimensions(rows, cols), do: {rows, cols}

  @impl true
  def handle_cast({:event, event}, state) do
    if state.shutting_down do
      {:noreply, state}
    else
      # Add to bounded event queue (may drop oldest if full)
      {result, new_queue} = EventQueue.push(state.event_queue, event)
      state = %{state | event_queue: new_queue}
      # Log if event was dropped
      case result do
        # EventQueue already logged
        {:dropped, _} -> :ok
        :ok -> :ok
      end

      # Process queued events
      state = process_event_queue(state)
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:message, component_id, message}, state) do
    if state.shutting_down do
      {:noreply, state}
    else
      state = enqueue_message(component_id, message, state)
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:command_result, component_id, command_id, result}, state) do
    state = handle_command_result(component_id, command_id, result, state)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:shutdown, state) do
    state = initiate_shutdown(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast(:force_render, state) do
    state = do_render(state)
    {:noreply, state}
  end

  @impl true
  def handle_info(:render, state) do
    state = process_render_tick(state)
    {:noreply, state}
  end

  @impl true
  def handle_info(:input_poll, state) do
    # Poll input handler for new events
    if state.shutting_down or state.input_handler == nil do
      {:noreply, state}
    else
      case state.input_handler.poll(state.input_state, @input_poll_interval) do
        {{:ok, event}, new_input_state} ->
          # Dispatch the event and continue polling
          state = %{state | input_state: new_input_state}
          state = dispatch_event(event, state)
          schedule_input_poll()
          {:noreply, state}

        {:timeout, new_input_state} ->
          # No input, but continue polling
          schedule_input_poll()
          {:noreply, %{state | input_state: new_input_state}}

        {:eof, _new_input_state} ->
          # EOF - initiate shutdown
          state = initiate_shutdown(%{state | input_state: nil})
          {:noreply, state}
      end
    end
  end

  @impl true
  def handle_info({:input, event}, state) do
    # Keyboard/mouse input from InputReader
    if state.shutting_down do
      {:noreply, state}
    else
      # Add to bounded event queue (may drop oldest if full)
      {result, new_queue} = EventQueue.push(state.event_queue, event)
      state = %{state | event_queue: new_queue}
      # Process queued events
      state = process_event_queue(state)
      # Log if event was dropped (EventQueue handles rate limiting)
      case result do
        {:dropped, _} -> :ok
        :ok -> :ok
      end

      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:terminal_resize, {rows, cols}}, state) do
    # Terminal window was resized
    if state.shutting_down do
      {:noreply, state}
    else
      state = handle_resize(rows, cols, state)
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    # Command task completed (handled via command_result)
    {:noreply, state}
  end

  @impl true
  def handle_info({:EXIT, _pid, _reason}, state) do
    # Ignore linked process exits (command executor, terminal helpers, etc.)
    {:noreply, state}
  end

  @impl true
  def handle_info(:stop_runtime, state) do
    # Stop the GenServer after shutdown cleanup
    {:stop, :normal, state}
  end

  # Catch-all for unknown messages - forward to root module's handle_info if it exists
  @impl true
  def handle_info(msg, state) do
    case maybe_forward_to_root(msg, state) do
      {:forwarded, new_state} -> {:noreply, new_state}
      :not_handled -> {:noreply, state}
    end
  end

  defp maybe_forward_to_root(msg, state) do
    if function_exported?(state.root_module, :handle_info, 2) do
      result = state.root_module.handle_info(msg, state.root_state)
      {:forwarded, apply_root_handle_info_result(result, state)}
    else
      :not_handled
    end
  end

  defp apply_root_handle_info_result({new_root_state, commands}, state) do
    state = update_root_component_state(state, new_root_state)
    tagged_commands = Enum.map(commands, fn cmd -> {:root, cmd} end)
    execute_commands(tagged_commands, state)
  end

  defp apply_root_handle_info_result(new_root_state, state) do
    update_root_component_state(state, new_root_state)
  end

  defp update_root_component_state(state, new_root_state) do
    components =
      Map.update!(state.components, :root, fn comp ->
        %{comp | state: new_root_state}
      end)

    %{state | root_state: new_root_state, components: components, dirty: true}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:sync, _from, state) do
    # Process all pending messages synchronously
    state = process_messages(state)
    {:reply, :ok, state}
  end

  @impl true
  def terminate(_reason, state) do
    safe_cleanup(fn -> terminate_logger_restore(state) end)
    safe_cleanup(fn -> terminate_input_reader(state) end)
    safe_cleanup(fn -> terminate_input_handler(state) end)
    safe_cleanup(fn -> terminate_backend(state) end)
    safe_cleanup(fn -> terminate_resize_callback(state) end)
    safe_cleanup(fn -> terminate_shutdown(state) end)
    safe_cleanup(fn -> terminate_legacy_restore(state) end)
    safe_cleanup(fn -> terminate_defensive_cleanup() end)
    safe_cleanup(fn -> terminate_persistent_terms() end)
    :ok
  end

  defp safe_cleanup(fun) do
    fun.()
  rescue
    _ -> :ok
  catch
    _, _ -> :ok
  end

  defp terminate_logger_restore(%{logger_handler_config: config}), do: restore_logger(config)
  defp terminate_logger_restore(_state), do: :ok

  defp terminate_input_reader(%{input_reader: nil}), do: :ok
  defp terminate_input_reader(%{input_reader: reader}), do: InputReader.stop(reader)

  defp terminate_input_handler(%{input_handler: nil}), do: :ok
  defp terminate_input_handler(%{input_state: nil}), do: :ok

  defp terminate_input_handler(%{input_handler: handler, input_state: input_state}),
    do: handler.stop(input_state)

  defp terminate_resize_callback(%{terminal_started: false}), do: :ok
  defp terminate_resize_callback(_state), do: Terminal.unregister_resize_callback(self())

  defp terminate_backend(%{backend: nil}), do: :ok
  defp terminate_backend(%{backend_state: nil}), do: :ok

  defp terminate_backend(%{backend: backend, backend_state: backend_state}),
    do: backend.shutdown(backend_state)

  defp terminate_shutdown(%{shutting_down: true}), do: :ok
  defp terminate_shutdown(state), do: do_shutdown(state)

  # Always restore terminal state when terminal was started, regardless of backend.
  # Use safe_restore_terminal/1 to avoid terminate-time failures if the Terminal
  # process races down between whereis and restore call.
  defp terminate_legacy_restore(%{terminal_started: true}), do: safe_restore_terminal(Terminal)

  defp terminate_legacy_restore(_state), do: :ok

  defp terminate_defensive_cleanup do
    restore_logger_from_persistent_term()
    TermUI.TerminalOutput.write_to_tty(TermUI.TerminalOutput.cleanup_sequence())
    TermUI.TerminalOutput.disable_onlcr()
    TermUI.TermUtils.safe_stty(["sane"])
  end

  defp restore_logger_from_persistent_term do
    case :persistent_term.get(:term_ui_logger_handler_config, nil) do
      nil -> :ok
      config -> restore_logger(config)
    end
  end

  defp terminate_persistent_terms do
    if PersistentTerms.owns_terms?(self()), do: PersistentTerms.cleanup()
    :persistent_term.erase(:term_ui_logger_handler_config)
  rescue
    ArgumentError -> :ok
  end

  # --- Event Dispatch ---

  # Processes events from the bounded event queue.
  #
  # Processes one event per call to prevent event loop starvation.
  # Multiple events will be processed across multiple GenServer handle_info/call cycles.
  defp process_event_queue(state) do
    case EventQueue.pop(state.event_queue) do
      {{:value, event}, new_queue} ->
        state = %{state | event_queue: new_queue}
        dispatch_event(event, state)

      {:empty, _} ->
        state
    end
  end

  defp dispatch_event(%Event.Key{} = event, state) do
    # Keyboard events go to focused component
    dispatch_to_component(state.focused_component, event, state)
  end

  defp dispatch_event(%Event.Mouse{} = event, state) do
    # Mouse events go to component at position
    # For now, just send to root (spatial index will be added later)
    dispatch_to_component(:root, event, state)
  end

  defp dispatch_event(%Event.Resize{} = event, state) do
    # Resize broadcasts to all components
    broadcast_event(event, state)
  end

  defp dispatch_event(%Event.Focus{} = event, state) do
    # Focus broadcasts to all components
    broadcast_event(event, state)
  end

  defp dispatch_event(%Event.Paste{} = event, state) do
    # Paste goes to focused component
    dispatch_to_component(state.focused_component, event, state)
  end

  defp dispatch_event(%Event.Tick{} = event, state) do
    # Tick broadcasts to all components
    broadcast_event(event, state)
  end

  defp dispatch_event(_event, state) do
    # Unknown event type, ignore
    state
  end

  defp dispatch_to_component(component_id, event, state) do
    case Map.get(state.components, component_id) do
      nil ->
        state

      %{module: module, state: component_state} ->
        # Transform event to message, with error handling
        try do
          case module.event_to_msg(event, component_state) do
            {:msg, message} ->
              enqueue_message(component_id, message, state)

            :ignore ->
              state

            :propagate ->
              # Would propagate to parent, for now just ignore
              state
          end
        rescue
          error ->
            require Logger
            Logger.error("Component #{component_id} crashed in event_to_msg: #{inspect(error)}")
            state
        end
    end
  end

  defp broadcast_event(event, state) do
    Enum.reduce(state.components, state, fn {component_id, _}, acc ->
      dispatch_to_component(component_id, event, acc)
    end)
  end

  # --- Message Processing ---

  defp enqueue_message(component_id, message, state) do
    queue = MessageQueue.enqueue(state.message_queue, {component_id, message})
    %{state | message_queue: queue}
  end

  defp process_messages(state) do
    {messages, queue} = MessageQueue.flush(state.message_queue)

    {state, commands} =
      Enum.reduce(messages, {%{state | message_queue: queue}, []}, fn {component_id, message},
                                                                      {acc_state, acc_cmds} ->
        {new_state, cmds} = process_message(component_id, message, acc_state)
        {new_state, acc_cmds ++ cmds}
      end)

    # Execute collected commands
    state = execute_commands(commands, state)

    state
  end

  defp process_message(component_id, message, state) do
    case Map.get(state.components, component_id) do
      nil ->
        {state, []}

      %{module: module, state: component_state} ->
        # Call update function with error handling
        try do
          result = module.update(message, component_state)
          {new_component_state, commands} = Elm.normalize_update_result(result, component_state)

          # Update component state
          components =
            Map.update!(state.components, component_id, fn comp ->
              %{comp | state: new_component_state}
            end)

          # Mark dirty if state changed
          dirty = state.dirty or new_component_state != component_state

          # Update root_state if this is root
          state =
            if component_id == :root do
              %{state | root_state: new_component_state, components: components, dirty: dirty}
            else
              %{state | components: components, dirty: dirty}
            end

          # Tag commands with component_id
          tagged_commands = Enum.map(commands, fn cmd -> {component_id, cmd} end)

          {state, tagged_commands}
        rescue
          error ->
            require Logger
            Logger.error("Component #{component_id} crashed in update: #{inspect(error)}")
            # Return unchanged state and no commands
            {state, []}
        end
    end
  end

  # --- Command Execution ---

  defp execute_commands([], state), do: state

  defp execute_commands(commands, state) do
    # Check for quit command first
    # Handle both Command struct and legacy atom :quit
    if Enum.any?(commands, &quit_command?/1) do
      # Quit command takes precedence - initiate shutdown
      # Stop the GenServer after cleanup
      GenServer.cast(self(), :shutdown)
      %{state | shutting_down: true}
    else
      Enum.reduce(commands, state, fn {component_id, cmd}, acc ->
        execute_command(component_id, cmd, acc)
      end)
    end
  end

  defp quit_command?({_component_id, %Command{type: :quit}}), do: true
  defp quit_command?({_component_id, :quit}), do: true
  defp quit_command?(_), do: false

  defp execute_command(_component_id, %Command{type: :none}, state), do: state
  defp execute_command(_component_id, :none, state), do: state

  defp execute_command(component_id, %Command{} = cmd, state) do
    if state.command_executor do
      case CommandExecutor.execute(state.command_executor, cmd, self(), component_id) do
        {:ok, command_id} ->
          pending =
            Map.put(state.pending_commands, command_id, %{
              component_id: component_id,
              command: cmd
            })

          %{state | pending_commands: pending}

        {:error, reason} ->
          Logger.warning("Command execution failed: #{inspect(reason)}")
          enqueue_message(component_id, {:command_error, reason}, state)
      end
    else
      Logger.warning("Command executor unavailable; dropping command: #{inspect(cmd)}")
      state
    end
  end

  defp execute_command(_component_id, {:send, target, message}, state) do
    cond do
      is_pid(target) ->
        send(target, message)
        state

      is_atom(target) and Map.has_key?(state.components, target) ->
        enqueue_message(target, message, state)

      is_atom(target) ->
        send(target, message)
        state

      true ->
        Logger.warning("Invalid :send target ignored: #{inspect(target)}")
        state
    end
  end

  defp execute_command(_component_id, {:send_to, target, message}, state) do
    if is_atom(target) and Map.has_key?(state.components, target) do
      enqueue_message(target, message, state)
    else
      state
    end
  end

  defp execute_command(_component_id, cmd, state) do
    Logger.warning("Unknown command ignored: #{inspect(cmd)}")
    state
  end

  defp handle_command_result(_component_id, command_id, {:send_to, target, message}, state) do
    pending = Map.delete(state.pending_commands, command_id)
    state = %{state | pending_commands: pending}

    if is_atom(target) and Map.has_key?(state.components, target) do
      enqueue_message(target, message, state)
    else
      state
    end
  end

  defp handle_command_result(component_id, command_id, result, state) do
    # Remove from pending
    pending = Map.delete(state.pending_commands, command_id)
    state = %{state | pending_commands: pending}

    # Send result as message to component
    enqueue_message(component_id, result, state)
  end

  # --- Rendering ---

  defp schedule_render(interval) do
    Process.send_after(self(), :render, interval)
  end

  defp schedule_input_poll do
    Process.send_after(self(), :input_poll, @input_poll_interval)
  end

  defp process_render_tick(state) do
    # Process any pending messages
    state = process_messages(state)

    # Render if dirty
    state =
      if state.dirty and not state.shutting_down do
        do_render(state)
      else
        state
      end

    # Schedule next render unless shutting down
    unless state.shutting_down do
      schedule_render(state.render_interval)
    end

    state
  end

  defp do_render(state) do
    # Render if backend is available (TTY backend works even without terminal_started)
    if state.backend do
      # Call view on root component with error handling
      %{module: module, state: component_state} = Map.get(state.components, :root)

      render_tree =
        try do
          module.view(component_state)
        rescue
          error ->
            require Logger
            Logger.error("Component :root crashed in view: #{inspect(error)}")
            # Return a simple error indicator
            {:text, "[Render Error]"}
        end

      # Different rendering paths for Raw vs TTY backends
      {cells, new_backend_state} =
        if state.buffer_manager do
          # Raw backend: use double buffering with diffing
          render_with_buffer_manager(render_tree, state)
        else
          # TTY backend: create temporary buffer, render all cells
          render_to_tty_backend(render_tree, state)
        end

      # Delegate rendering to backend
      {:ok, new_backend_state} = state.backend.draw_cells(new_backend_state, cells)

      # Flush any pending output
      {:ok, ^new_backend_state} = state.backend.flush(new_backend_state)

      %{state | dirty: false, backend_state: new_backend_state}
    else
      %{state | dirty: false}
    end
  end

  # Renders using BufferManager with double buffering and diffing (Raw backend)
  defp render_with_buffer_manager(render_tree, state) do
    # Clear current buffer
    BufferManager.clear_current(state.buffer_manager)

    # Render tree to buffer
    NodeRenderer.render_to_buffer(render_tree, state.buffer_manager)

    # Get buffers for diffing
    current = BufferManager.get_current_buffer(state.buffer_manager)
    previous = BufferManager.get_previous_buffer(state.buffer_manager)

    # Get changed cells and convert to backend format
    cells = get_changed_cells(current, previous)

    # Swap buffers
    BufferManager.swap_buffers(state.buffer_manager)

    {cells, state.backend_state}
  end

  # Renders to TTY backend without double buffering
  defp render_to_tty_backend(render_tree, state) do
    # Get terminal size from backend state or capabilities
    {rows, cols} =
      case state.backend_state do
        %{size: {r, c}} -> {r, c}
        _ -> {24, 80}
      end

    # Create temporary buffer for this frame
    case Buffer.new(rows, cols) do
      {:ok, temp_buffer} ->
        # Render tree directly to temporary buffer (bypassing BufferManager)
        NodeRenderer.render_to_buffer_direct(render_tree, temp_buffer)

        # Extract all non-empty cells for TTY backend
        cells = extract_all_cells(temp_buffer)

        # Clean up temporary buffer
        Buffer.destroy(temp_buffer)

        {cells, state.backend_state}

      {:error, _reason} ->
        # If buffer creation fails, render nothing
        {[], state.backend_state}
    end
  end

  # Extracts all non-empty cells from buffer for TTY backend
  defp extract_all_cells(buffer) do
    {rows, _cols} = Buffer.dimensions(buffer)

    for row <- 1..rows, reduce: [] do
      acc ->
        buffer_row = Buffer.get_row(buffer, row)

        cells_in_row =
          buffer_row
          |> Enum.with_index(1)
          |> Enum.filter(fn {%Cell{char: char}, _col} -> char != " " end)
          |> Enum.flat_map(fn {cell, col} -> cell_to_backend_tuple(cell, row, col) end)

        cells_in_row ++ acc
    end
  end

  # Gets changed cells by comparing current and previous buffers.
  # Returns cells in the format expected by Backend.draw_cells/2: [{position, cell_data}]
  # where position is {row, col} and cell_data is {char, fg, bg, attrs}
  defp get_changed_cells(current, previous) do
    {rows, _cols} = Buffer.dimensions(current)

    # Iterate through all cells and collect changed ones
    # For efficiency, we use the Diff module's row comparison
    for row <- 1..rows, reduce: [] do
      acc ->
        current_row = Buffer.get_row(current, row)
        previous_row = Buffer.get_row(previous, row)

        # Find changed cells in this row. We must emit changed space cells too,
        # otherwise previously rendered content is never cleared.
        changed_in_row =
          current_row
          |> Enum.with_index(1)
          |> Enum.filter(fn {cell, col} ->
            should_emit_diff_cell?(cell, Enum.at(previous_row, col - 1, Cell.empty()))
          end)
          |> Enum.flat_map(fn {cell, col} ->
            cell_to_backend_tuple(cell, row, col)
          end)

        changed_in_row ++ acc
    end
  end

  # Converts a Cell struct to the backend format: {{row, col}, {char, fg, bg, attrs}}
  # Skips wide placeholder cells (they're part of wide characters)
  # Returns [] for skipped cells to filter them out
  defp cell_to_backend_tuple(%Cell{wide_placeholder: true}, _row, _col), do: []

  defp cell_to_backend_tuple(%Cell{char: char, fg: fg, bg: bg, attrs: attrs}, row, col) do
    # Convert MapSet attrs to list for backend format
    attrs_list = MapSet.to_list(attrs)
    [{{row, col}, {char, normalize_color(fg), normalize_color(bg), attrs_list}}]
  end

  # Normalizes colors to ensure :default instead of nil
  defp normalize_color(nil), do: :default
  defp normalize_color(color), do: color

  @doc false
  @spec should_emit_diff_cell?(Cell.t(), Cell.t()) :: boolean()
  def should_emit_diff_cell?(current_cell, previous_cell) do
    not Cell.equal?(current_cell, previous_cell)
  end

  # --- Resize Handling ---

  defp handle_resize(rows, cols, state) do
    # Skip if terminal not available
    if state.terminal_started do
      # Update dimensions in state
      new_dimensions = normalize_terminal_dimensions(rows, cols)

      # Resize buffer manager
      if state.buffer_manager do
        BufferManager.resize(state.buffer_manager, rows, cols)
      end

      # Clear screen to avoid artifacts
      TermUI.TerminalOutput.write("\e[2J")

      # Create resize event and broadcast to all components
      resize_event = Event.Resize.new(cols, rows)
      state = broadcast_event(resize_event, %{state | dimensions: new_dimensions})

      # Mark dirty and force immediate render
      state = %{state | dirty: true}
      do_render(state)
    else
      state
    end
  end

  # --- Shutdown ---

  defp initiate_shutdown(state) do
    state = %{state | shutting_down: true}
    state = do_shutdown(state)

    # Schedule the GenServer to stop after returning from this callback
    # This allows terminate/2 to run and clean up properly
    Process.send_after(self(), :stop_runtime, 0)

    state
  end

  defp do_shutdown(state) do
    # Wait for pending commands to complete (with timeout)
    # Cancel any outstanding commands and stop executor
    if state.command_executor && Process.alive?(state.command_executor) do
      Enum.each(Map.keys(state.pending_commands), fn command_id ->
        _ = CommandExecutor.cancel(state.command_executor, command_id)
      end)

      GenServer.stop(state.command_executor, :normal)
    end

    state = %{state | pending_commands: %{}}

    # Terminate components (leaf to root)
    # For now, just clear components
    state = %{state | components: %{}}

    state
  end
end
